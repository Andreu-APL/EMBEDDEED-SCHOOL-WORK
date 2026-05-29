// RISC-V Top-Level Testbench
//
// Runs the complete single-cycle processor and prints every signal
// of interest after each clock edge. We use hierarchical references
// (dut.signal) so we don't have to expose internals as extra ports.
//
// Program (instrMem.hex):
//   0x00 : addi x5, x0, 5      → x5  = 5
//   0x04 : addi x6, x0, 10     → x6  = 10
//   0x08 : add  x10, x5, x6    → x10 = 15

`include "RISCV.sv"

module RISCV_tb;

    // Clock & reset 
    logic clk = 0, rst;
    always #5 clk = ~clk;   // 10 ns period

    // DUT 
    RISCV dut (.clk, .rst);

    // Helpers: readable signal aliases via hierarchical refs
    // Naming follows the top-level wire names in RISCV.sv
    wire [31:0] PC         = dut.pc;
    wire [31:0] INSTR      = dut.instr;
    wire [31:0] ALU_RESULT = dut.alu_result;
    wire        REG_WRITE  = dut.reg_write;
    wire        MEM_WRITE  = dut.mem_write;
    wire        BRANCH     = dut.branch;
    wire        JUMP       = dut.jump;
    wire        TAKEN      = dut.taken;
    wire [31:0] IMM        = dut.imm;

    // Failure tally (set by check())
    int fails = 0;

    // Simulation
    initial begin
        $dumpfile("riscv_sim.vcd");
        $dumpvars(0, RISCV_tb);

        // Hold reset for one full cycle
        rst = 1; @(posedge clk); #1;
        rst = 0;

        $display("─────────────────────────────────────────────────────────────");
        $display(" Cycle │   PC   │  INSTR   │ ALUResult│ RW MW BR JMP TKN");
        $display("─────────────────────────────────────────────────────────────");

        // Run for enough cycles to execute the full program
        repeat (6) begin
            @(posedge clk); #1;
            $display("  %4d │ 0x%04h │ %08h │ %08h │  %b  %b  %b   %b   %b",
                $time/10,
                PC, INSTR, ALU_RESULT,
                REG_WRITE, MEM_WRITE, BRANCH, JUMP, TAKEN);
        end

        $display("─────────────────────────────────────────────────────────────");
        $display("");

        // Verify final register values
        check("x5  = 5",  dut.RF.regs[5],  32'd5);
        check("x6  = 10", dut.RF.regs[6],  32'd10);
        check("x10 = 15", dut.RF.regs[10], 32'd15);

        $display("");
        if (fails == 0)
            $display("All checks passed — simulation complete.");
        else
            $display("%0d check(s) FAILED — simulation complete.", fails);
        $finish;
    end

    // Check helper: prints PASS / FAIL and tallies failures
    task automatic check(input string label, input logic [31:0] got, exp);
        if (got === exp)
            $display("  PASS  %s  (got 0x%08h)", label, got);
        else begin
            $display("  FAIL  %s  — expected 0x%08h, got 0x%08h", label, exp, got);
            fails++;
        end
    endtask

endmodule
