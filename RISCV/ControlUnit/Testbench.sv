module tb_ControlUnit;
    logic [6:0] op;
    logic       reg_write, alu_src, mem_write, mem_to_reg, branch, jump;
    logic [1:0] alu_op;

    ControlUnit dut (.op, .reg_write, .alu_src, .mem_write,
                     .mem_to_reg, .branch, .jump, .alu_op);

    initial begin
        // R-type
        op = 7'b0110011; #1;
        assert (reg_write && !alu_src && !mem_write && alu_op == 2'b10)
            else $error("R-type fail");

        // I-type ALU
        op = 7'b0010011; #1;
        assert (reg_write && alu_src && alu_op == 2'b10)
            else $error("I-ALU fail");

        // Load
        op = 7'b0000011; #1;
        assert (reg_write && alu_src && mem_to_reg && !mem_write)
            else $error("load fail");

        // Store
        op = 7'b0100011; #1;
        assert (!reg_write && alu_src && mem_write)
            else $error("store fail");

        // Branch
        op = 7'b1100011; #1;
        assert (!reg_write && branch && alu_op == 2'b01)
            else $error("branch fail");

        // JAL
        op = 7'b1101111; #1;
        assert (reg_write && jump)
            else $error("jal fail");

        $display("PASS: ControlUnit");
        $finish;
    end
endmodule
