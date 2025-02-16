//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    
// Design Name: 
// Module Name:    driver 
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
module driver(
    input clk,
    input rst,
    input [1:0] br_cfg,             // Receive baud rate from switch to program UART
    output logic iocs,              // IO Chip select
    output logic iorw,              // Direction of data transfer (1: SPART->driver 0: driver->SPART)
    input rda,                      // receive data available
    input tbr,                      // transmit data available
    output logic [1:0] ioaddr,      // Input/output address provided by driver
    inout logic [7:0] databus
    );

    /* br_cfg
    00  4800 bits/sec   => 650  x028a
    01  9600 bits/sec   => 325  x0145
    10  19200 bits/sec  => 162  x00A2
    11  38400 bits/sec  => 80   x0050
    */

    // RDA: Uart is ready to transmit to driver
    // TBR: Driver is ready to transmit to UART data transfer 

    /* Internal Wires */
    logic next_byte;
    reg baud_byte_cnt;
    reg br_cfg_ff;
    logic new_br_cfg;


    typedef enum reg[1:0] {IDLE, PROGRAMMING, RECEIVING, TRANSMITTING} state_t;
    state_t state, next_state;

    always_ff@(posedge clk, negedge rst) begin
        if (!rst) 
            state <= PROGRAMMING;   // On reset, program the baud counter
        else
            state <= next_state;
    end

    // Counter for the number of bytes sent to the SPART (for programming the baud rate)
    always_ff@(posedge clk, negedge rst) begin
        if (!rst) 
            baud_byte_cnt <= 0;
        else if (new_br_cfg)
            baud_byte_cnt <= 0;
        else if (next_byte)
            baud_byte_cnt <= baud_byte_cnt + 1;
    end

    // Controller to check for new baud rate configuration
    always_ff@(posedge clk, negedge rst) begin
        if (!rst)
            br_cfg_ff <= br_cfg;
        else
            br_cfg_ff <= br_cfg;
    end

    // Controller for Databus
    logic [7:0] databus_reg;
    assign databus = (!iorw) ? databus_reg : 'Z;

    always_comb begin
        // Defaults
        next_state = state;
        iocs = 0;
        iorw = 0;
        ioaddr = '0;
        next_byte = 0;
        new_br_cfg = 0;

        case(state)
            IDLE: begin
                // On reset, program the baud counter
                if (!rst) begin
                    next_state = PROGRAMMING;
                end
                else if (br_cfg_ff !== br_cfg) begin 
                    new_br_cfg = 1;
                    next_state = PROGRAMMING;
                end
                else if (rda) begin
                    iocs = 1;
                    iorw = 1;
                    next_state = RECEIVING;
                end
                else if (tbr) begin
                    iocs = 1;
                    next_state = TRANSMITTING;
                end
            end
            PROGRAMMING: begin
                if (br_cfg_ff !== br_cfg) 
                    new_br_cfg = 1;
                else begin
                    // Send programming bytes sequentially:
                    if (baud_byte_cnt == 0) begin
                        // Send the low byte into the Divisor Buffer (DB Low).
                        databus_reg = (br_cfg == 2'b00) ? 8'h8A :
                                    (br_cfg == 2'b01) ? 8'h45 :
                                    (br_cfg == 2'b10) ? 8'hA2 :
                                    (br_cfg == 2'b11) ? 8'h50 : 8'hZZ;
                        ioaddr      = 2'b10; // Address for DB Low
                        next_byte   = 1;
                    end
                    else if (baud_byte_cnt == 1) begin
                        // Send the high byte into the Divisor Buffer (DB High).
                        databus_reg = (br_cfg == 2'b00) ? 8'h02 :
                                    (br_cfg == 2'b01) ? 8'h01 :
                                    (br_cfg == 2'b10) ? 8'h00 :
                                    (br_cfg == 2'b11) ? 8'h00 : 8'hZZ;
                        ioaddr      = 2'b11; // Address for DB High
                        next_state = IDLE;
                        new_br_cfg = 1;
                    end
                end
            end
            RECEIVING: begin
                // Read operation: set up for receiving data from SPART.
                ioaddr = 2'b00; // Assume this is the address for the receive register.
                // ioaddr = 2'b01; // This is the address for the status register.
                iocs   = 1;
                iorw   = 1;    // Read operation (SPART -> driver)
                if (!rda)
                    next_state = IDLE;
            end
            TRANSMITTING: begin
                // Write operation: set up for transmitting data to SPART.
                ioaddr = 2'b01; // This is the address for the transmit buffer.
                iocs   = 1;
                iorw   = 0;    // Write operation (driver -> SPART)
                if (!tbr)
                    next_state = IDLE;
            end
        endcase
    end
endmodule
