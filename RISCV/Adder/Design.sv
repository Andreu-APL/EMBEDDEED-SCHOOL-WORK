// Adder
// Simple 32-bit adder, no carry out needed.
// Used twice in the datapath: once to compute PC+4 (sequential fetch),
// and once to compute PC+imm (branch and jump target address).

module Adder (
    input  logic [31:0] a, b,
    output logic [31:0] y
);
    assign y = a + b;
endmodule
