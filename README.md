UART (Universal Asynchronous Receiver-Transmitter)
A robust RTL implementation of a Universal Asynchronous Receiver-Transmitter (UART) designed for serial communication, complete with simulation testbenches.

Features
Configurable Baud Rate Generator: Easily adjustable clock divider to match standard baud rates.

Transmitter (Tx) Module: Serializes parallel data into a framing format with start, data, optional parity, and stop bits.

Receiver (Oversampling/Rx) Module: Recovers serial streams, handles framing checks, and converts data back to parallel format.

Testbenches: Comprehensive simulation testbenches for verifying functionality under various scenarios.

Project Structure
Plaintext
UART/
│
├── rtl/                  # Verilog/SystemVerilog RTL source files
│   ├── uart_top.v        # Top-level module
│   ├── uart_tx.v         # Transmitter module
│   └── uart_rx.v         # Receiver module
│
├── sim/                  # Testbenches and simulation files
│   └── uart_tb.v         # Testbench for verification
│
└── README.md             # Project documentation

EDA Playground Links
You can test and run the modules directly online:

UART TX: https://edaplayground.com/x/hB3H

UART RX: https://edaplayground.com/x/cnkd

Simulation & Verification
This project can be simulated using tools like ModelSim, Xilinx Vivado, or online platforms like EDA Playground.

Clone the repository:

Bash
git clone https://github.com/Mustafa-A-Nasr/UART.git
Open your preferred simulator (e.g., ModelSim or EDA Playground).

Compile all files inside the rtl/ and sim/ directories.

Run the simulation targeting uart_tb to observe wave forms and transaction logs.

License
This project is open-source and available under the terms of the MIT License.
