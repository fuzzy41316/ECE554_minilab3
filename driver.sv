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
            state <= IDLE;
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
                if(!rst) 
                    next_state = PROGRAMMING;
                // On a new baud rate configuration, program the baud counter
                else if (br_cfg_ff !== br_cfg) begin
                    new_br_cfg = 1;
                    next_state = PROGRAMMING;
                end
                // Depending on input from the SPART, transmitt/receive to/from the SPART
                else if (rda)
                    next_state = RECEIVING;
                else if (tbr)
                    next_state = TRANSMITTING;
            end
            PROGRAMMING: begin
                // Check for a random change in baud rate
                if (br_cfg_ff !== br_cfg) begin
                    new_br_cfg = 1;
                end
                // Otherwise continue sending the previous or new baud rate programming
                else begin
                    databus_reg = (baud_byte_cnt == 0) ? 
                        ((br_cfg == 0) ? 8'h8a :
                        (br_cfg == 1) ? 8'h45 :
                        (br_cfg == 2) ? 8'ha2 :
                        (br_cfg == 3) ? 8'h50 : 'Z) :
                        (baud_byte_cnt == 1) ? 
                        ((br_cfg == 0) ? 8'h02 :
                        (br_cfg == 1) ? 8'h01 :
                        (br_cfg == 2) ? 8'h00 :
                        (br_cfg == 3) ? 8'h00 : 'Z) :
                        'Z; // Unused

                    // Determine if we need to send the next byte or done programming
                    next_byte = 1;
                    case (baud_byte_cnt)
                        0: ioaddr = 2'b10;
                        1: ioaddr = 2'b11;
                        default: next_state = IDLE;
                    endcase
                end
            end
            RECEIVING: begin
                ioaddr = 2'b00;
                iocs = 1;
                iorw = 1;
                if (!rda)
                    next_state = IDLE;
            end
            TRANSMITTING: begin
                ioaddr = 2'b01;
                iocs = 1;
                iorw = 0;
                if (!tbr)
                    next_state = IDLE;
            end
        endcase
    end
endmodule
