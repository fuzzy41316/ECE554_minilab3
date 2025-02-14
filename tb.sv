`timescale 1ns / 1ps
module tb;

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
    wire rst = KEY[0];

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
    
    // Testbench Procedure
    initial begin
        CLOCK_50 = 0;
        KEY = 4'b1111; // Default no reset
        SW = 10'b0000000000;
        rxd = 1;

        // Apply Reset
        @(negedge CLOCK_50) KEY[0] = 0;
        @(negedge CLOCK_50) KEY[0] = 1;

        // Start transmitting data to SPART
        @(negedge CLOCK_50) begin
            SW[9:8] = 2'b00;
            rxd = 0; // Start bit
        end
        $display("Sending data to SPART...");
        input_byte = 8'hA6; // Data byte to be sent
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge (spart0.bit_counter == i+1)) 
                rxd = input_byte[i]; // Data bits
            $display("Sending bit %d: %b", i, input_byte[i]);    
        end

        @(negedge CLOCK_50)
            rxd = 1; // Stop bit
        $display("Sending stop bit");

        wait(rda); // Wait for received data to be available
        $display("Data received by SPART: %b", spart0.r_buffer);
        $display("Data expected by SPART: %b", input_byte);
        if (spart0.r_buffer == input_byte) begin
            $display("Data received successfully!");
        end 
        else begin
            $display("Data mismatch! at time %t", $time);
            $stop();
        end

        $display("Sending data from driver to SPART...");


        $stop();
    end

    always #5 CLOCK_50 = ~CLOCK_50; // Clock
endmodule

