module tb_InstructionMemory;
    logic [31:0] addr, instr;

    InstructionMemory dut (.addr, .instr);

    initial begin
        // Force memory contents directly (no .hex file needed)
        dut.mem[0] = 32'hDEADBEEF;
        dut.mem[1] = 32'hCAFEBABE;
        dut.mem[2] = 32'h12345678;

        addr = 32'h00; #1; assert (instr == 32'hDEADBEEF) else $error("mem[0] fail");
        addr = 32'h04; #1; assert (instr == 32'hCAFEBABE) else $error("mem[1] fail");
        addr = 32'h08; #1; assert (instr == 32'h12345678) else $error("mem[2] fail");

        $display("PASS: InstructionMemory");
        $finish;
    end
endmodule
