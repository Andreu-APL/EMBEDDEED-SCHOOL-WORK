// Data Memory (RAM)
// Used by load (lw) and store (sw) instructions.
// Writes are synchronous (happen on the clock edge when we=1).
// Reads are combinational — the data shows up the same cycle the address is set.
// addr[9:2] converts the byte address to a word index (256 words = 1 KB).

module DataMemory (
    input  logic        clk,
    input  logic        we,         // write enable (set by store instructions)
    input  logic [31:0] addr,       // byte address from the ALU result
    input  logic [31:0] wd,         // data to write (rs2)
    output logic [31:0] rd          // data read (goes to register file on loads)
);
    logic [31:0] mem [0:255];

    always_ff @(posedge clk)
        if (we) mem[addr[9:2]] <= wd;

    assign rd = mem[addr[9:2]];
endmodule
