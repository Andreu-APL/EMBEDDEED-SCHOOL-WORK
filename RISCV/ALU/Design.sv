// ALU (Arithmetic Logic Unit)
// Executes one operation per cycle based on the 4-bit ctrl signal.
// The ctrl codes match what ALUControl outputs:
//   0=ADD  1=SUB  2=SLT  3=OR  4=XOR  5=SLL  6=SRL  7=SRA  8=AND
//
// The zero flag goes high when result == 0.
// It's used by the branch logic (BranchComparator handles the full
// set of conditions, but some designs use zero directly for BEQ).

module ALU (
    input  logic [31:0] a, b,
    input  logic [3:0]  ctrl,
    output logic [31:0] result,
    output logic        zero
);
    always_comb
        case (ctrl)
            4'd0: result = a + b;
            4'd1: result = a - b;
            4'd2: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT
            4'd3: result = a | b;
            4'd4: result = a ^ b;
            4'd5: result = a << b[4:0];              // SLL — only lower 5 bits matter
            4'd6: result = a >> b[4:0];              // SRL — logical, fills with 0s
            4'd7: result = $signed(a) >>> b[4:0];    // SRA — arithmetic, fills with sign
            4'd8: result = a & b;
            default: result = 32'b0;
        endcase

    assign zero = (result == 32'b0);
endmodule
