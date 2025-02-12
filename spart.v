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

// Internal Registers
reg [7:0] r_buffer;  // Receive buffer
reg [7:0] t_buffer;  // Transmit buffer
reg [15:0] baud_div; // Baud rate divisor
reg [3:0] baud_counter;

//Output register to be used in always blocks before assignment to actual output signals
reg rda_ff;
reg tbr_ff;
reg txd_ff;

// Baud Rate Generator
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        baud_counter <= 0;
    end else begin
        if (baud_counter == baud_div[3:0]) begin
            baud_counter <= 0;
        end else begin
            baud_counter <= baud_counter + 1;
        end
    end
end

// Receive Logic
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        rda_ff <= 0;
        r_buffer <= 8'b0;
    end else if (baud_counter == 0 && rxd) begin
        r_buffer <= {r_buffer[6:0], rxd};
        rda_ff <= 1;
    end
end

// Transmit Logic
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        tbr_ff <= 1;
        txd_ff <= 1;
    end else if (!iorw && ioaddr == 2'b00 && iocs) begin
        t_buffer <= databus;
        tbr_ff <= 0;
    end else if (baud_counter == 0 && !tbr_ff) begin
        txd_ff <= t_buffer[0];
        t_buffer <= {1'b1, t_buffer[7:1]};
        if (t_buffer == 8'b00000001) tbr_ff <= 1;
    end
end

// Bus Interface
//In english - (
//if (mode is driver to SPART and driver selects this chip) then
//	if(the I/O address is 2'b01/status register) then
//		set databus to 6'b000000 contatenated with rda and tbr
//	else
//		set databus to r_buffer
//else
//	set databus to 8'hz -> high impedence
assign databus = (!iorw && iocs) ? ((ioaddr == 2'b01) ? {6'b0, rda_ff, tbr_ff} : r_buffer) : 8'bz;

//assigning internal logic to output ports
assign rda = rda_ff;
assign tbr = tbr_ff;
assign txd = txd_ff;

endmodule

