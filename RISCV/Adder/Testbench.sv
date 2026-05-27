module tb_Adder;
    logic [31:0] a, b, y;

    Adder dut (.a, .b, .y);

    initial begin
        a = 32'h4; b = 32'h4;   #1; assert (y == 32'h8)          else $error("4+4 fail");
        a = 32'h0; b = 32'h0;   #1; assert (y == 32'h0)          else $error("0+0 fail");
        a = 32'hFFFFFFFF; b = 1; #1; assert (y == 32'h0)         else $error("overflow fail");
        a = 32'hC; b = 32'h10;  #1; assert (y == 32'h1C)         else $error("12+16 fail");

        $display("PASS: Adder");
        $finish;
    end
endmodule
