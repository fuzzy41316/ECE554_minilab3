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
    input clk, //CLK signal - nothing crazy - INPUT
    input rst, //Despite there not being a _n, this is active low - INPUT
    input iocs, //I/O chip select - not sure what that means - INPUT
    input iorw, //Determines direction of transfer 1 for SPART to driver, and 0 for driver to SPART - INPUT
    output rda, //Recieve Data Available - byte of data is here ready to go to driver to process - OUTPUT
    output tbr, //Transmit Buffer Ready - SPART is ready to accept a new byte from driver- OUTPUT
    input [1:0] ioaddr, //00 Transmit Buffer, 01 Status Register, 10 DB(Low) Division Buffer, DB (High) Division Buffer
    inout [7:0] databus, //8-bit 2-directional bus to transfer data and control information between Processor and SPART
    output txd, //Data bit coming in
    input rxd //Data bit going out
    );
//-------------------------------------------------------------------------
// Baud Rate Generator
// The baud counter counts from 0 up to the programmed divisor (db) value.
// When the counter resets (i.e. baud_enable pulse), the transmitter and 
// receiver sample their signals.
//-------------------------------------------------------------------------
reg [15:0] baud_counter;
wire        baud_enable;
reg rda_reg, tbr_reg;

// Divisor Buffer (loaded via bus write operations)
reg [15:0] db;

always @(posedge clk or negedge rst) begin
    if (!rst)
        baud_counter <= 16'd0;
    else if (baud_counter >= db)
        baud_counter <= 16'd0;
    else
        baud_counter <= baud_counter + 16'd1;
end
assign baud_enable = (baud_counter == 16'd0);

//-------------------------------------------------------------------------
// Divisor Buffer Loading
// When the processor writes to addresses 10 (low byte) or 11 (high byte)
// the divisor is updated. (Nonblocking assignments are used.)
//-------------------------------------------------------------------------
always @(posedge clk or negedge rst) begin
    if (!rst)
        db <= 16'd0;
    else if (iocs && !iorw) begin
        if (ioaddr == 2'b10)
            db[7:0] <= databus;
        else if (ioaddr == 2'b11)
            db[15:8] <= databus;
    end
end

//-------------------------------------------------------------------------
// Receive Logic
// A simple state machine for receiving a serial byte:
//  - Detect a start bit (rxd goes low)
//  - Sample 8 data bits (LSB first) on baud_enable pulses
//  - Check the stop bit (should be high) and then set rda flag.
//-------------------------------------------------------------------------
reg        receiving;
reg [3:0]  r_bit_counter;
reg [7:0]  r_buffer;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        receiving     <= 1'b0;
        r_bit_counter <= 4'd0;
        r_buffer      <= 8'd0;
        rda_reg           <= 1'b0;
    end else begin
        // If not already receiving, look for start bit (rxd==0)
        if (!receiving && (rxd == 1'b0)) begin
            receiving     <= 1'b1;
            r_bit_counter <= 4'd0;
        end else if (receiving && baud_enable) begin
            if (r_bit_counter < 4'd8) begin
                // Shift in data bits; sample at each baud_enable pulse.
                r_buffer      <= {rxd, r_buffer[7:1]};
                r_bit_counter <= r_bit_counter + 4'd1;
            end else begin
                // Stop bit expected; if rxd is high then valid.
                if (rxd == 1'b1)
                    rda_reg <= 1'b1;
                receiving <= 1'b0;
            end
        end

        // Clear rda when the processor reads the receive buffer.
        if (iocs && iorw && ioaddr == 2'b00)
            rda_reg <= 1'b0;
    end
end

//-------------------------------------------------------------------------
// Transmit Logic
// On a write operation to address 00 (transmit buffer), load the transmit
// register and begin shifting out bits (LSB first). A start bit (0) is 
// transmitted first, followed by the data bits and a stop bit (1).
//-------------------------------------------------------------------------
reg        transmitting;
reg [3:0]  t_bit_counter;
reg [7:0]  t_buffer;
reg        txd_reg;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        transmitting   <= 1'b0;
        t_bit_counter  <= 4'd0;
        t_buffer       <= 8'd0;
        tbr_reg        <= 1'b1;    // Transmit Buffer Ready initially.
        txd_reg        <= 1'b1;    // Idle state for TxD is high.
    end else begin
        // Detect write operation to transmit buffer (address 00)
        if (!transmitting && iocs && !iorw && (ioaddr == 2'b00)) begin
            t_buffer      <= databus;
            transmitting  <= 1'b1;
            t_bit_counter <= 4'd0;
            tbr_reg       <= 1'b0;    // Buffer now busy.
            txd_reg       <= 1'b0;    // Start bit.
        end else if (transmitting && baud_enable) begin
            if (t_bit_counter < 4'd8) begin
                // Transmit data bits LSB first.
                txd_reg       <= t_buffer[0];
                t_buffer      <= {1'b1, t_buffer[7:1]}; // Shift right, filling with 1.
                t_bit_counter <= t_bit_counter + 4'd1;
            end else begin
                // Transmit stop bit.
                txd_reg      <= 1'b1;
                transmitting <= 1'b0;
                tbr_reg          <= 1'b1; // Transmission complete.
            end
        end
    end
end
assign txd = txd_reg;
assign rda = rda_reg;
assign tbr = tbr_reg;

//-------------------------------------------------------------------------
// Bus Interface
// The SPART drives the databus only during read operations (when iorw is 1)
// and iocs is asserted. Two read addresses are supported:
//  - 00: Receive Buffer (r_buffer)
//  - 01: Status Register: {6'b0, rda, tbr}
// Other addresses result in high impedance.
//-------------------------------------------------------------------------
assign databus = (iocs && iorw) ? 
                 ((ioaddr == 2'b01) ? {6'b0, rda, tbr} :
                  (ioaddr == 2'b00) ? r_buffer : 8'bz)
                 : 8'bz;

endmodule