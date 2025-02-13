`timescale 1ns / 1ps

module spart_tb;

    // Testbench Signals
    reg CLOCK_50;
    reg [3:0] KEY;
    reg [9:0] SW;
    wire [9:0] LEDR;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire [35:0] GPIO;
    
    reg txd, rxd, rda, tbr;
    wire iocs, iorw;
    wire [1:0] ioaddr, br_cfg;
    wire [7:0] databus;
    reg [7:0] input_byte;
    integer i;

    // press button[0] to generate a low active reset signal
    wire rst = ~KEY[0];

    // Assign switches for baud rate configuration
    assign br_cfg = SW[9:8];

    // Instantiate SPART module
    spart spart0 (
        .clk(CLOCK_50),
        .rst(rst),
        .iocs(iocs),
        .iorw(iorw),
        .rda(rda),
        .tbr(tbr),
        .ioaddr(ioaddr),
        .databus(databus),
        .txd(txd),
        .rxd(rxd)
    );

    // Instantiate Driver module
    driver driver0 (
        .clk(CLOCK_50),
        .rst(rst),
        .br_cfg(br_cfg),
        .iocs(iocs),
        .iorw(iorw),
        .rda(rda),
        .tbr(tbr),
        .ioaddr(ioaddr),
        .databus(databus)
    );
    
    // Clock Generation
    always #5 CLOCK_50 = ~CLOCK_50;
    
    // Testbench Procedure
    initial begin
        CLOCK_50 = 0;
        // Apply Reset
        @(negedge CLOCK_50) KEY[0] = 0;
        @(negedge CLOCK_50) KEY[0] = 1;

        KEY = 4'b1111; // Default no reset
        SW = 10'b0000000000;
        rxd = 1;


	rxd = 0;
	SW[9:8] = 2'b00;       
        // Send a byte to SPART one bit at a time
        input_byte = 8'b10100110;
        for (i = 0; i < 8; i = i + 1) begin
            #10 rxd = input_byte[i];
        end
        #10 rxd = 1; // Stop bit
        
        // Wait for received data to be available
        wait(rda);

        // Wait for transmit buffer to be ready
        wait(tbr);

        rxd = 0;
        SW[9:8] = 2'b01;       
            // Send a byte to SPART one bit at a time
            input_byte = 8'b01011001;
            for (i = 0; i < 8; i = i + 1) begin
                #10 rxd = input_byte[i];
            end
            #10 rxd = 1; // Stop bit
            
            // Wait for received data to be available
            wait(rda);

            // Wait for transmit buffer to be ready
            wait(tbr);

        rxd = 0;
        SW[9:8] = 2'b10;       
            // Send a byte to SPART one bit at a time
            input_byte = 8'b01011001;
            for (i = 0; i < 8; i = i + 1) begin
                #10 rxd = input_byte[i];
            end
            #10 rxd = 1; // Stop bit
            
            // Wait for received data to be available
            wait(rda);

            // Wait for transmit buffer to be ready
            wait(tbr);

        rxd = 0;
        SW[9:8] = 2'b10;       
            // Send a byte to SPART one bit at a time
            input_byte = 8'b01011001;
            for (i = 0; i < 8; i = i + 1) begin
                #10 rxd = input_byte[i];
            end
            #10 rxd = 1; // Stop bit
            
            // Wait for received data to be available
            wait(rda);

            // Wait for transmit buffer to be ready
            wait(tbr);
            
            // End simulation
            #50 $finish;
        end

    // Monitor signals
    initial begin
        $monitor("Time=%0t CLK=%b rst=%b iocs=%b iorw=%b ioaddr=%b databus=%h rda=%b tbr=%b txd=%b rxd=%b", $time, CLOCK_50, rst, iocs, iorw, ioaddr, databus, rda, tbr, txd, rxd);
    end

endmodule

