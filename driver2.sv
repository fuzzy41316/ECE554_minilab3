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

    // Baud rate divisor values:
// For 4800 bps: 650  = 0x028A (Low: 8Ah, High: 02h)
// For 9600 bps: 325  = 0x0145 (Low: 45h, High: 01h)
// For 19200 bps: 162 = 0x00A2 (Low: A2h, High: 00h)
// For 38400 bps: 80  = 0x0050 (Low: 50h, High: 00h)

// Internal signals
logic next_byte;
// Corrected: use a 2-bit counter to count programming bytes (0 and 1)
reg [1:0] baud_byte_cnt;
// Previous baud rate configuration needs to be stored as 2 bits as well.
reg [1:0] br_cfg_ff;
logic new_br_cfg;

typedef enum logic [1:0] {IDLE, PROGRAMMING, RECEIVING, TRANSMITTING} state_t;
state_t state, next_state;

// State update (synchronous with asynchronous reset)
always_ff @(posedge clk or negedge rst) begin
    if (!rst)
        state <= IDLE;
    else
        state <= next_state;
end

// Update the baud rate programming byte counter.
always_ff @(posedge clk or negedge rst) begin
    if (!rst)
        baud_byte_cnt <= 0;
    else if (new_br_cfg)
        baud_byte_cnt <= 0;
    else if (next_byte)
        baud_byte_cnt <= baud_byte_cnt + 1;
end

// Store previous baud rate configuration for detecting changes.
always_ff @(posedge clk or negedge rst) begin
    if (!rst)
        br_cfg_ff <= br_cfg;
    else
        br_cfg_ff <= br_cfg;
end

// Drive the databus only when writing (iorw == 0)
logic [7:0] databus_reg;
assign databus = (!iorw) ? databus_reg : 'Z;

// Combinational state machine for driver control
always_comb begin
    // Default assignments
    next_state   = state;
    iocs         = 0;
    iorw         = 0;
    ioaddr       = 2'b00;
    next_byte    = 0;
    new_br_cfg   = 0;
    databus_reg  = 8'hZZ; // High impedance by default

    case (state)
        IDLE: begin
            // On reset or on a new baud rate configuration, initiate programming.
            if (!rst)
                next_state = PROGRAMMING;
            else if (br_cfg_ff !== br_cfg) begin
                new_br_cfg = 1;
                next_state = PROGRAMMING;
            end
            // Otherwise, check for SPART signals to determine direction.
            else if (rda)
                next_state = RECEIVING;
            else if (tbr)
                next_state = TRANSMITTING;
        end

        PROGRAMMING: begin
            // If baud rate configuration has changed mid-program, reinitialize.
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
                    next_byte   = 1;
                end
                else begin
                    // After both bytes are sent, return to the IDLE state.
                    next_state = IDLE;
                end
            end
        end

        RECEIVING: begin
            // Read operation: set up for receiving data from SPART.
            ioaddr = 2'b00; // Assume this is the address for the receive register.
            iocs   = 1;
            iorw   = 1;    // Read operation (SPART -> driver)
            if (!rda)
                next_state = IDLE;
        end

        TRANSMITTING: begin
            // Write operation: set up for transmitting data to SPART.
            ioaddr = 2'b01; // Assume this is the address for the transmit buffer.
            iocs   = 1;
            iorw   = 0;    // Write operation (driver -> SPART)
            if (!tbr)
                next_state = IDLE;
        end

        default: next_state = IDLE;
    endcase
end

endmodule
