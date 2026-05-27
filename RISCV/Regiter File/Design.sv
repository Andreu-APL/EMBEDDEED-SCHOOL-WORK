// Register File
// 32 general-purpose 32-bit registers (x0–x31).
// Two combinational read ports (rs1, rs2) and one synchronous write port (rd).
// x0 is hardwired to 0 — writes to it are silently ignored, reads always return 0.

module RegisterFile (
    input  logic        clk,
    input  logic        we,         // write enable
    input  logic [4:0]  rs1, rs2,  // source register addresses
    input  logic [4:0]  rd,         // destination register address
    input  logic [31:0] wd,         // write data
    output logic [31:0] rd1, rd2   // read data outputs
);
    logic [31:0] regs [31:0];

    // Write on rising edge; skip if destination is x0
    always_ff @(posedge clk)
        if (we && rd != 5'd0) regs[rd] <= wd;

    // Read is combinational; x0 always reads as zero
    assign rd1 = (rs1 != 5'd0) ? regs[rs1] : 32'b0;
    assign rd2 = (rs2 != 5'd0) ? regs[rs2] : 32'b0;
endmodule
