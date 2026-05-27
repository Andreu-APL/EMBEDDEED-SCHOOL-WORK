module tb_ImmediateGenerator;
    logic [31:0] instr, imm;

    ImmediateGenerator dut (.instr, .imm);

    initial begin
        // I-type: addi x1, x0, -1  → imm = 0xFFFFF (sign-extended -1)
        instr = 32'hFFF00093; #1;
        assert (imm == 32'hFFFFFFFF) else $error("I-type fail: %0h", imm);

        // S-type: sw x1, 8(x2)  → imm = 8
        instr = 32'h00112423; #1;
        assert (imm == 32'd8) else $error("S-type fail: %0h", imm);

        // B-type: beq x0, x0, +4  → imm = 4
        instr = 32'h00000263; #1;
        assert (imm == 32'd4) else $error("B-type fail: %0h", imm);

        // U-type: lui x1, 1  → imm = 0x1000
        instr = 32'h000010B7; #1;
        assert (imm == 32'h00001000) else $error("U-type fail: %0h", imm);

        $display("PASS: ImmediateGenerator");
        $finish;
    end
endmodule
