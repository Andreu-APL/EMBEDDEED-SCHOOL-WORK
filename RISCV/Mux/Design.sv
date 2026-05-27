// 2-to-1 Multiplexer
// Generic width via parameter W (defaults to 32).
// sel=0 picks input a, sel=1 picks input b.
// Used in several places: ALU source, writeback data, next PC selection.

module Mux #(parameter W = 32) (
    input  logic [W-1:0] a, b,
    input  logic         sel,
    output logic [W-1:0] y
);
    assign y = sel ? b : a;
endmodule
