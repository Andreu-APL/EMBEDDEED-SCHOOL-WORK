// Immediate Generator
// Each RISC-V instruction format scatters the immediate bits differently
// across the 32-bit word. This module reassembles them and sign-extends
// to 32 bits based on the opcode (bits [6:0]).
//
// Formats handled:
//   I  — addi, lw, jalr          bits [31:20]
//   S  — sw                       bits [31:25] + [11:7]
//   B  — beq, bne, blt…           bits [31],[7],[30:25],[11:8], implicit LSB=0
//   J  — jal                      bits [31],[19:12],[20],[30:21], implicit LSB=0
//   U  — lui, auipc               bits [31:12] shifted to upper 20 bits

module ImmediateGenerator (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    logic [6:0] op;
    assign op = instr[6:0];

    always_comb
        case (op)
            7'b0010011,             // I-type ALU  (addi, ori, …)
            7'b0000011,             // I-type Load (lw, lh, lb, …)
            7'b1100111: imm = {{20{instr[31]}}, instr[31:20]};

            7'b0100011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            7'b1100011: imm = {{19{instr[31]}}, instr[31], instr[7],
                                instr[30:25], instr[11:8], 1'b0};

            7'b1101111: imm = {{11{instr[31]}}, instr[31], instr[19:12],
                                instr[20], instr[30:21], 1'b0};

            7'b0110111,             // lui
            7'b0010111: imm = {instr[31:12], 12'b0};   // auipc

            default:    imm = 32'b0;
        endcase
endmodule
