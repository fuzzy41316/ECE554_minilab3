## Project Overview
This project involves designing a Special Purpose Asynchronous Receiver/Transmitter (SPART) and its testbench in Verilog. The SPART is a basic I/O interface that facilitates serial communication between a processor and an external device. The project includes simulating the design, downloading it to an FPGA, and demonstrating its functionality. The goal is to gain familiarity with the lab environment, practice using HDL, and understand basic I/O interfacing.

## Skills Highlighted
- **Verilog HDL**: Designed and implemented a SPART module and its testbench in Verilog.
- **Digital Design**: Developed a UART-based serial communication system with configurable baud rates.
- **Hardware Interfacing**: Interfaced the SPART with a processor and external devices using handshaking signals.
- **Simulation and Testing**: Created a testbench to simulate and verify the functionality of the SPART module.
- **FPGA Implementation**: Synthesized and downloaded the design to an FPGA for real-world testing.
- **Problem Solving**: Addressed challenges related to baud rate configuration, data transmission, and reception.

## Project Components
1. **Verilog Code**:
   - Designed the SPART module, including the baud rate generator, transmit control, and receive control.
   - Implemented a testbench to simulate the SPART's functionality, including data transmission and reception.

2. **Baud Rate Configuration**:
   - Configured the baud rate using division buffers (DBH and DBL) to support multiple baud rates (4800, 9600, 19200, 38400 bps).
   - Implemented a down-counter and decoder to generate the sampling rate (16x the baud rate).

3. **Testbench**:
   - Simulated a mock processor to send and receive data through the SPART.
   - Implemented a simplified `printf` function to print character strings for debugging and demonstration purposes.

4. **Demonstration**:
   - Demonstrated the ability to transmit and receive characters at different baud rates using the FPGA board.
   - Used HyperTerminal to interact with the SPART and verify correct functionality.

## How to Run the Project
1. **Setup**:
   - Ensure you have the necessary tools installed (Quartus Prime, Modelsim, etc.).
   - Download the starter kit `Lab1-SPART.zip` from Canvas.

2. **Simulation**:
   - Open the Verilog files in Modelsim.
   - Run the testbench to simulate the SPART's functionality and verify correct data transmission and reception.

3. **FPGA Implementation**:
   - Synthesize the design using Quartus Prime.
   - Download the design to the FPGA board.
   - Connect the FPGA to a host PC using a USB-to-UART cable.
   - Use HyperTerminal to send and receive data, demonstrating the SPART's functionality at different baud rates.
