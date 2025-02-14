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
reg [15:0] baud_counter;

//Output register to be used in always blocks before assignment to actual output signals
reg rda_ff;
reg tbr_ff;
reg txd_ff;
reg [3:0] bit_counter;
reg [3:0] bit_counter_t;
reg receiving, transmitting;
reg bit_count;

//division buffer
reg [15:0] db;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
	db <= 16'b0;
    end
    else begin
	if (ioaddr == 2'b10 && !iorw) begin
		db[7:0] = databus;
	end else if (ioaddr == 2'b11 && !iorw)begin
		db[15:8] = databus;
	end
    end
end
	



// Baud Rate Generator - need to add additional branches based on ioaddr - not exactly sure yet how specifically
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        baud_counter <= 0;
	bit_count <= 0;
    end else begin
        if (baud_counter == db || (ioaddr == 2'b00 && !iorw && iocs)) begin
            baud_counter <= 0;
	    bit_count <=1;
        end else begin
            baud_counter <= baud_counter + 1;
	    bit_count<=0;
        end
    end
end

// Receive Logic with Start and Stop Bit Handling
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        rda_ff <= 0;
        r_buffer <= 8'b0;
        bit_counter <= 0;
        receiving <= 0;
    end else if (!receiving && rxd == 0) begin // Detect start bit
        receiving <= 1;
        bit_counter <= 0;
    end else if (receiving && baud_counter == 0) begin
        if (bit_count) begin
            r_buffer <= {rxd, r_buffer[7:1]};
            bit_counter <= bit_counter + 1;
        end else if (bit_counter == 8) begin // Stop bit
            if (rxd == 1) begin
                rda_ff <= 1;
            end
            receiving <= 0;
	    bit_counter <= 0;
        end
    end
end

// Transmit Logic with Start and Stop Bit Handling
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        tbr_ff <= 0;
        txd_ff <= 1;
        bit_counter_t <= 4'h0;
        transmitting <= 0;
    end else if (!transmitting && !iorw && ioaddr == 2'b00 && iocs) begin
        t_buffer <= databus;
        tbr_ff <= 0;
        transmitting <= 1;
        bit_counter_t <= 4'h0;
        txd_ff <= 0; // Start bit
    end else if (transmitting && baud_counter == 0) begin
        if (bit_count) begin
            txd_ff <= t_buffer[0];
            t_buffer <= {1'b1, t_buffer[7:1]};
            bit_counter_t <= bit_counter_t + 1;
        end else if (bit_counter_t == 8) begin // Stop bit
            txd_ff <= 1;
            tbr_ff <= 1;
	    bit_counter <= 0;
            transmitting <= 0;
        end
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
assign databus = (iorw && iocs) ? ((ioaddr == 2'b01) ? {6'b0, rda_ff, tbr_ff} : r_buffer) : 8'bz;

//assigning internal logic to output ports
assign rda = rda_ff;
assign tbr = tbr_ff;
assign txd = txd_ff;

endmodule

