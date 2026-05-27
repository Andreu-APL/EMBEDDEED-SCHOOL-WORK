module tb_ALU;
    logic [31:0] a, b, result;
    logic [3:0]  ctrl;
    logic        zero;

    ALU dut (.a, .b, .ctrl, .result, .zero);

    initial begin
        // ADD
        a = 10; b = 5; ctrl = 4'd0; #1;
        assert (result == 15)  else $error("add fail");

        // SUB
        ctrl = 4'd1; #1;
        assert (result == 5)   else $error("sub fail");

        // SUB → zero flag
        b = 10; #1;
        assert (zero == 1)     else $error("zero flag fail");

        // SLT: 3 < 10 → 1
        a = 3; b = 10; ctrl = 4'd2; #1;
        assert (result == 1)   else $error("slt fail");

        // OR
        a = 8'hF0; b = 8'h0F; ctrl = 4'd3; #1;
        assert (result == 8'hFF) else $error("or fail");

        // XOR
        ctrl = 4'd4; #1;
        assert (result == 8'hFF) else $error("xor fail");

        // AND
        a = 8'hFF; b = 8'h0F; ctrl = 4'd8; #1;
        assert (result == 8'h0F) else $error("and fail");

        // SLL: 1 << 3 = 8
        a = 1; b = 3; ctrl = 4'd5; #1;
        assert (result == 8)   else $error("sll fail");

        // SRL: 8 >> 1 = 4
        a = 8; b = 1; ctrl = 4'd6; #1;
        assert (result == 4)   else $error("srl fail");

        // SRA: -8 >>> 1 = -4
        a = 32'hFFFFFFF8; b = 1; ctrl = 4'd7; #1;
        assert (result == 32'hFFFFFFFC) else $error("sra fail");

        $display("PASS: ALU");
        $finish;
    end
endmodule
