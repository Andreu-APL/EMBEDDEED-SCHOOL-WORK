// RISC-V Single-Cycle Processor — Top Level
//
// This module just wires everything together. There is no logic here, just
// connections and more connections, and also connections btw
//
// only signal declarations and submodule instances.
//
// Supported instructions: R-type, I-type ALU, LW, SW, BEQ/BNE/BLT/BGE/BLTU/BGEU, JAL, LUI

`include "ProgramCounter/Design.sv"
`include "InstructionMemory/Design.sv"
`include "Regiter File/Design.sv"
`include "ImmediateGenerator/Design.sv"
`include "ALUControl/Design.sv"
`include "ALU/Design.sv"
`include "ControlUnit/Design.sv"
`include "DataMemory/Design.sv"
`include "Mux/Design.sv"
`include "Adder/Design.sv"
`include "BranchComparator/Design.sv"

module RISCV (
    input logic clk, rst
);

    // Instruction fields
    logic [31:0] instr;
    logic [6:0]  op;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [2:0]  funct3;
    logic        funct7b5;

    assign op        = instr[6:0];
    assign rd_addr   = instr[11:7];
    assign funct3    = instr[14:12];
    assign rs1_addr  = instr[19:15];
    assign rs2_addr  = instr[24:20];
    assign funct7b5  = instr[30];

    // Datapath signals
    logic [31:0] pc, pc_next, pc_plus4, pc_target;
    logic [31:0] rd1, rd2;        // register file read data
    logic [31:0] imm;             // sign-extended immediate
    logic [31:0] alu_b;           // second ALU operand (rs2 or imm)
    logic [31:0] alu_result;      // ALU output (also used as memory address)
    logic [31:0] mem_rd;          // data memory read data
    logic [31:0] wb_data;         // writeback after mem/ALU mux
    logic [31:0] result;          // final value written to register file

    // ── Control signals (driven by ControlUnit) ───────────────────────
    logic        reg_write, alu_src, mem_write, mem_to_reg, branch, jump;
    logic [1:0]  alu_op;
    logic [3:0]  alu_ctrl;

    // ── Branch / jump ─────────────────────────────────────────────────
    logic        zero, taken, pc_sel;

    // ─────────────────────────────────────────────────────────────────
    // Instances
    // ─────────────────────────────────────────────────────────────────

    // Fetch
    ProgramCounter   PC_reg  (.clk, .rst, .pc_next, .pc);
    InstructionMemory IM     (.addr(pc), .instr);

    // Decode
    ControlUnit      CU      (.op, .reg_write, .alu_src, .mem_write,
                               .mem_to_reg, .branch, .jump, .alu_op);
    ImmediateGenerator IG    (.instr, .imm);

    // Register file — writeback result feeds back here
    RegisterFile     RF      (.clk, .we(reg_write),
                               .rs1(rs1_addr), .rs2(rs2_addr), .rd(rd_addr),
                               .wd(result), .rd1, .rd2);

    // Execute
    Mux              MUX_ALU (.a(rd2), .b(imm), .sel(alu_src), .y(alu_b));
    ALUControl       AC      (.alu_op, .funct3, .funct7b5, .alu_ctrl);
    ALU              ALU0    (.a(rd1), .b(alu_b), .ctrl(alu_ctrl),
                               .result(alu_result), .zero);

    // Memory
    DataMemory       DM      (.clk, .we(mem_write),
                               .addr(alu_result), .wd(rd2), .rd(mem_rd));

    // Writeback mux:  ALU result  vs  memory data
    Mux              MUX_MEM (.a(alu_result), .b(mem_rd), .sel(mem_to_reg), .y(wb_data));

    // JAL mux: normal result  vs  PC+4  (return address written to rd on jumps)
    Mux              MUX_JAL (.a(wb_data), .b(pc_plus4), .sel(jump), .y(result));

    // Branch comparator — handles all six branch conditions from funct3
    BranchComparator BC      (.a(rd1), .b(rd2), .funct3, .taken);

    // PC+4: next sequential instruction
    Adder            ADD_PC4 (.a(pc), .b(32'd4), .y(pc_plus4));

    // PC+imm: branch and jump target
    Adder            ADD_TGT (.a(pc), .b(imm),   .y(pc_target));

    // Choose next PC:
    //   pc_sel=0 → sequential (PC+4)
    //   pc_sel=1 → branch target or jump target (both are PC+imm)
    assign pc_sel = (branch & taken) | jump;
    Mux              MUX_PC  (.a(pc_plus4), .b(pc_target), .sel(pc_sel), .y(pc_next));

endmodule
