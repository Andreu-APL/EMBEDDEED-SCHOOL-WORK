// Branch Comparator
// Checks whether a branch should be taken based on funct3.
// Kept separate from the ALU so comparisons don't need to go through
// the full ALU pipeline — the result feeds directly into the PC mux.
//
// Signed comparisons (blt, bge) use $signed() casts.
// Unsigned comparisons (bltu, bgeu) use the raw logic values.

module BranchComparator (
    input  logic [31:0] a, b,       // rs1, rs2 from the register file
    input  logic [2:0]  funct3,     // encodes which comparison to do
    output logic        taken       // 1 if branch should be taken
);
    always_comb
        case (funct3)
            3'b000: taken =  (a == b);                   // BEQ
            3'b001: taken =  (a != b);                   // BNE
            3'b100: taken = ($signed(a) <  $signed(b));  // BLT
            3'b101: taken = ($signed(a) >= $signed(b));  // BGE
            3'b110: taken =  (a <  b);                   // BLTU
            3'b111: taken =  (a >= b);                   // BGEU
            default: taken = 1'b0;
        endcase
endmodule
