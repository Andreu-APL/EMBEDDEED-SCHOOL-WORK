module tb_BranchComparator;
    logic [31:0] a, b;
    logic [2:0]  funct3;
    logic        taken;

    BranchComparator dut (.a, .b, .funct3, .taken);

    initial begin
        // BEQ: a == b
        a = 5; b = 5; funct3 = 3'b000; #1;
        assert (taken == 1) else $error("beq eq fail");
        b = 6; #1;
        assert (taken == 0) else $error("beq neq fail");

        // BNE: a != b
        funct3 = 3'b001; #1;
        assert (taken == 1) else $error("bne fail");

        // BLT: signed -1 < 1
        a = 32'hFFFFFFFF; b = 1; funct3 = 3'b100; #1;
        assert (taken == 1) else $error("blt fail");

        // BGE: signed 1 >= -1
        a = 1; b = 32'hFFFFFFFF; funct3 = 3'b101; #1;
        assert (taken == 1) else $error("bge fail");

        // BLTU: unsigned 1 < 0xFFFFFFFF
        a = 1; b = 32'hFFFFFFFF; funct3 = 3'b110; #1;
        assert (taken == 1) else $error("bltu fail");

        // BGEU: unsigned 0xFFFFFFFF >= 1
        a = 32'hFFFFFFFF; b = 1; funct3 = 3'b111; #1;
        assert (taken == 1) else $error("bgeu fail");

        $display("PASS: BranchComparator");
        $finish;
    end
endmodule
