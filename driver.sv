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
`default_nettype wire
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
    00  4800 bits/sec   => 10417    x27A3
    01  9600 bits/sec   => 5208     x1458
    10  19200 bits/sec  => 162      x0A2C
    11  38400 bits/sec  => 80       x0516
    */

    // RDA: Uart is ready to transmit to driver
    // TBR: Driver is ready to transmit to UART data transfer 

    /* Internal Wires */
    logic next_byte;
    reg baud_byte_cnt;
    reg [1:0] br_cfg_ff;
    logic new_br_cfg;


    typedef enum reg[1:0] {IDLE, PROGRAMMING, READING, WRITING} state_t;
    state_t state, next_state;

    always_ff@(posedge clk, negedge rst) begin
        if (!rst) 
            state <= PROGRAMMING;  
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
    always_ff@(posedge clk) begin
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
        databus_reg = 'Z;

        case(state)
            IDLE: begin
                iocs = 1;
                if (br_cfg_ff !== br_cfg) begin 
                    new_br_cfg = 1;
                    next_state = PROGRAMMING;
                end
                else if (rda) begin
                    iocs = 1;
                    iorw = 1;
                    next_state = READING;
                end
            end
            PROGRAMMING: begin
                iocs = 1;
                // Send programming bytes sequentially:
                if (baud_byte_cnt == 0) begin
                    // Send the low byte into the Divisor Buffer (DB Low).
                    databus_reg = (br_cfg == 2'b00) ? 8'hA3 :
                                (br_cfg == 2'b01) ? 8'h58 :
                                (br_cfg == 2'b10) ? 8'h2C :
                                (br_cfg == 2'b11) ? 8'h16 : 8'hZZ;
                    ioaddr      = 2'b10; // Address for DB Low
                    next_byte   = 1;
                end
                else if (baud_byte_cnt == 1) begin
                    // Send the high byte into the Divisor Buffer (DB High).
                    databus_reg = (br_cfg == 2'b00) ? 8'h27 :
                                (br_cfg == 2'b01) ? 8'h14 :
                                (br_cfg == 2'b10) ? 8'h0A :
                                (br_cfg == 2'b11) ? 8'h05 : 8'hZZ;
                    ioaddr      = 2'b11; // Address for DB High
                    next_state = IDLE;
                    new_br_cfg = 1;
                end
            end
            READING: begin
                // Read operation: set up for receiving data from SPART.
                ioaddr = 2'b00; // Assume this is the address for the receive register.
                // ioaddr = 2'b01; // This is the address for the status register.
                iocs   = 1;
                iorw   = 1;    // Read operation (SPART -> driver)
                databus_reg = databus;

                // Write after receiving
                if (tbr & !rda)
                    next_state = WRITING;
            end
            WRITING: begin
                // Write operation: set up for transmitting data to SPART.
                ioaddr = 2'b00; // This is the address for the transmit buffer.
                iocs   = 1;
                iorw   = 0;    // Write operation (driver -> SPART)

                if (!tbr)
                    next_state = IDLE;
            end
        endcase
    end
endmodule
