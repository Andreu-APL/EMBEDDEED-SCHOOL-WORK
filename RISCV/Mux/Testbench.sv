module tb_Mux;
    logic [31:0] a, b, y;
    logic        sel;

    Mux dut (.a, .b, .sel, .y);

    initial begin
        a = 32'hAAAA; b = 32'hBBBB;

        sel = 0; #1;
        assert (y == a) else $error("sel=0 fail");

        sel = 1; #1;
        assert (y == b) else $error("sel=1 fail");

        $display("PASS: Mux");
        $finish;
    end
endmodule
