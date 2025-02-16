//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:   
// Design Name: 
// Module Name:    spart 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module spart(
    input clk,      
    input rst,              // Active low reset
    input iocs,             // I/O chip select 
    input iorw,             // High: SPART -> Driver, Low: Driver -> SPART
    output logic rda,       // Recieve Data Available for driver to process
    output logic tbr,       // Transmit Buffer Ready for driver to send data (t_buffer empty)
    input [1:0] ioaddr,     // 00 Transmit Buffer, 01 Status Register, 10 DB(Low), 11 DB(High)
    inout [7:0] databus,    // Asynchronous bidirectional data bus between SPART and Driver
    output logic txd,       // Data bit going out
    input logic rxd         // Data bit coming in
    );

    // Internal signals
    logic [15:0] division_buffer;
    logic [15:0] baud_counter;
    logic shift, start, ready, receiving, transmitting;
    logic [7:0] receive_buffer, status_register;
    logic [8:0] transmit_shift_reg, receive_shift_reg;
    logic [3:0] bit_counter;

    // Division buffer for baud rate generator
    always_ff @(posedge clk, negedge rst) begin
        if (!rst)
            division_buffer <= 16'h0145;            // Default 9600 baud rate
        else if (iocs) begin                        // Enable for the SPART
            if (iorw & (ioaddr == 2'b10))           // Low byte from driver 
                division_buffer[7:0] <= databus;
            else if (iorw & (ioaddr == 2'b11))      // High byte from driver
                division_buffer[15:8] <= databus;
        end
    end

    // Baud rate generator
    always_ff @(posedge clk, negedge rst) begin
        if (!rst) 
            baud_counter <= '0;
        // Reset baud_counter when shifting another bit in or starting receiving/transmitting
        else if (start | shift) 
            baud_counter <= '0;
        // Start baud_counter when receiving or transmitting
        else if (receiving | transmitting) 
            baud_counter <= baud_counter + 1;
    end

    // Control signals and DATABUS behavior
    assign shift =              (baud_counter == division_buffer) ? 1 : 0;
    assign status_register =    {6'b0, tbr, rda};
    assign databus =            (ioaddr == 2'b01 & iorw) ? status_register :
                                (ioaddr == 2'b00 & iorw & iocs) ? receive_buffer :
                                'Z;

    // Receive shift register
    logic RX1;
    always_ff@(posedge clk, negedge rst) begin
        // Rx line is high when idle, pulled low to initialize receiving
        if(!rst) 
            RX1 <= 1'b1;
        else 
            RX1 <= rxd;
    end

    // Receive shift register
    always_ff @(posedge clk, negedge rst) begin
        if (!rst) begin
            receive_shift_reg <= '0;
            receive_buffer <= '0;
            transmit_shift_reg <= 9'b1;
            txd <= '1;
        end
        else begin
            // When shift is high, shift in the data from the RX line to the receive shift register
            if (receiving) begin
                if (shift)
                    receive_shift_reg <= {RX1, receive_shift_reg[8:1]};
                receive_buffer <= receive_shift_reg[7:0];
            end
            else if (transmitting) begin
                if (start)
                    transmit_shift_reg <= {databus, 1'b0};
                else if (shift)
                    transmit_shift_reg <= {1'b1, transmit_shift_reg[8:1]};
                txd <= transmit_shift_reg[0];
            end
        end
    end

    // Bit Counter
    always_ff @(posedge clk, negedge rst) begin
        if (!rst) 
            bit_counter <= 4'b0;
        else if (start)
            bit_counter <= 4'b0;
        else if (shift)
            bit_counter <= bit_counter + 1;
    end

    // Flop RDA and TBR signals
    always_ff @(posedge clk, negedge rst) begin
        if (!rst) 
            rda <= 1'b0;
        else 
            rda <= ready;
    end

    // State machine
    typedef enum logic [1:0] {IDLE, RECEIVING, TRANSMITTING} state_t;
    state_t state, next_state;

    always_ff@(posedge clk, negedge rst) begin
        if (!rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        ready = 0;        // Receive data available
        next_state = state;
        start = 0;
        receiving = 0;
        transmitting = 0;
        tbr = 1;

        case(state)
            RECEIVING: begin
                tbr = 0;
                receiving = 1;
                if (bit_counter == 10) begin
                    // Check for stop bit
                    if (RX1 == 1) begin
                        ready = 1;
                        next_state = IDLE;
                    end
                    // Start bit not detected, receive more data
                    else begin
                        start = 1;
                        next_state = RECEIVING;
                    end
                end
            end
            TRANSMITTING: begin
                tbr = 0;
                transmitting = 1;
                if (bit_counter == 10) 
                    next_state = IDLE;
            end
            // default is IDLE state
            default: begin
                // Data line pulled down to start receiving
                if ((RX1 == 0) & iocs) begin
                    start = 1;
                    next_state = RECEIVING;
                end
                // Driver gave data to transmit buffer
                else if (tbr & iocs) begin
                    start = 1;
                    next_state = TRANSMITTING;
                end
            end
        endcase
    end
endmodule