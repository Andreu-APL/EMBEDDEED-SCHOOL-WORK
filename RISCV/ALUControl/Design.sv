// ALU Control
// Translates the 2-bit alu_op from the Control Unit plus the instruction's
// funct3 and funct7[5] into a 4-bit ALU operation code.
//
// alu_op encoding (set by ControlUnit):
//   00 → always ADD           (used by load/store to compute address)
//   01 → always SUB           (used by branches to compare)
//   10 → look at funct3/funct7 (used by R-type and I-type ALU instructions)
//
// funct7b5 is instr[30]; it's the only bit that distinguishes
// ADD/SUB and SRL/SRA, so we only need that one bit.

module ALUControl (
    input  logic [1:0] alu_op,
    input  logic [2:0] funct3,
    input  logic       funct7b5,    // instr[30]
    output logic [3:0] alu_ctrl
);
    always_comb
        case (alu_op)
            2'b00:   alu_ctrl = 4'd0;   // force ADD for address calculation
            2'b01:   alu_ctrl = 4'd1;   // force SUB for branch comparison
            default: case (funct3)      // decode the actual operation
                3'b000: alu_ctrl = funct7b5 ? 4'd1 : 4'd0; // SUB / ADD
                3'b001: alu_ctrl = 4'd5;    // SLL
                3'b010: alu_ctrl = 4'd2;    // SLT
                3'b100: alu_ctrl = 4'd4;    // XOR
                3'b101: alu_ctrl = funct7b5 ? 4'd7 : 4'd6; // SRA / SRL
                3'b110: alu_ctrl = 4'd3;    // OR
                3'b111: alu_ctrl = 4'd8;    // AND
                default: alu_ctrl = 4'd0;
            endcase
        endcase
endmodule
