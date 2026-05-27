module tb_ALUControl;
    logic [1:0] alu_op;
    logic [2:0] funct3;
    logic       funct7b5;
    logic [3:0] alu_ctrl;

    ALUControl dut (.alu_op, .funct3, .funct7b5, .alu_ctrl);

    initial begin
        // Load/Store → add
        alu_op = 2'b00; funct3 = 0; funct7b5 = 0; #1;
        assert (alu_ctrl == 4'd0) else $error("load/store fail");

        // Branch → sub
        alu_op = 2'b01; #1;
        assert (alu_ctrl == 4'd1) else $error("branch fail");

        // R-type add (funct7b5=0, funct3=000)
        alu_op = 2'b10; funct3 = 3'b000; funct7b5 = 0; #1;
        assert (alu_ctrl == 4'd0) else $error("add fail");

        // R-type sub (funct7b5=1, funct3=000)
        funct7b5 = 1; #1;
        assert (alu_ctrl == 4'd1) else $error("sub fail");

        // AND (funct3=111)
        funct3 = 3'b111; funct7b5 = 0; #1;
        assert (alu_ctrl == 4'd8) else $error("and fail");

        // OR (funct3=110)
        funct3 = 3'b110; #1;
        assert (alu_ctrl == 4'd3) else $error("or fail");

        $display("PASS: ALUControl");
        $finish;
    end
endmodule
