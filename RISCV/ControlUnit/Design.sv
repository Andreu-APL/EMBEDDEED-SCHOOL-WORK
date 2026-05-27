// Control Unit
// Looks at the opcode (bits [6:0]) and drives every control signal in the
// datapath. Everything defaults to 0 at the top of the always block, so
// only the signals that need to be 1 are explicitly set per instruction type.
//
// Signal meanings:
//   reg_write  — write result back to the register file
//   alu_src    — 0: second ALU input is rs2 | 1: it's the sign-extended immediate
//   mem_write  — write to data memory (store instructions)
//   mem_to_reg — 0: write ALU result to rd | 1: write memory read data to rd
//   branch     — this instruction might branch (BranchComparator decides if taken)
//   jump       — unconditional jump (JAL); also writes PC+4 into rd
//   alu_op     — hint to ALUControl: 00=add, 01=sub, 10=decode funct3/7

module ControlUnit (
    input  logic [6:0] op,
    output logic       reg_write, alu_src, mem_write, mem_to_reg, branch, jump,
    output logic [1:0] alu_op
);
    always_comb begin
        // safe default: all signals off
        {reg_write, alu_src, mem_write, mem_to_reg, branch, jump, alu_op} = 8'b0;

        case (op)
            7'b0110011: {reg_write, alu_op}              = {1'b1, 2'b10}; // R-type
            7'b0010011: {reg_write, alu_src, alu_op}     = {1'b1, 1'b1, 2'b10}; // I-ALU
            7'b0000011: {reg_write, alu_src, mem_to_reg} = 3'b111;        // load
            7'b0100011: {alu_src, mem_write}             = 2'b11;         // store
            7'b1100011: {branch, alu_op}                 = {1'b1, 2'b01}; // branch
            7'b1101111: {reg_write, jump}                = 2'b11;         // JAL
            7'b0110111: {reg_write, alu_src}             = 2'b11;         // LUI
            default:;
        endcase
    end
endmodule
