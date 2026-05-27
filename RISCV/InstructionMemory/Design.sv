// Instruction Memory (ROM)
// Stores the program as 32-bit words. The address comes straight from
// the PC, which is always byte-aligned, so we drop bits [1:0] and use
// bits [9:2] to index 256 words (1 KB of program space).
// The file "program.hex" is loaded at simulation start.

module InstructionMemory (
    input  logic [31:0] addr,
    output logic [31:0] instr
);
    logic [31:0] mem [0:255];
    initial $readmemh("program.hex", mem);

    assign instr = mem[addr[9:2]];  // byte addr → word index
endmodule
