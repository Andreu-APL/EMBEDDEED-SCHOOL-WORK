module tb_RegisterFile;
    logic        clk = 0, we;
    logic [4:0]  rs1, rs2, rd;
    logic [31:0] wd, rd1, rd2;

    RegisterFile dut (.clk, .we, .rs1, .rs2, .rd, .wd, .rd1, .rd2);

    always #5 clk = ~clk;

    initial begin
        // Write 99 to x1
        we = 1; rd = 5'd1; wd = 32'd99; rs1 = 5'd1; rs2 = 5'd0; #10;
        assert (rd1 == 32'd99) else $error("x1 read fail");

        // x0 must always be 0 (write ignored)
        rd = 5'd0; wd = 32'hFFFFFFFF; #10;
        rs1 = 5'd0;
        assert (rd1 == 32'd0) else $error("x0 not zero");

        // Write x3 = 42, read via rs2
        rd = 5'd3; wd = 32'd42; rs2 = 5'd3; #10;
        assert (rd2 == 32'd42) else $error("x3 read fail");

        $display("PASS: RegisterFile");
        $finish;
    end
endmodule
