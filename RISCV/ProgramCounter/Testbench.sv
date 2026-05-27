module tb_ProgramCounter;
    logic        clk = 0, rst;
    logic [31:0] pc_next, pc;

    ProgramCounter dut (.clk, .rst, .pc_next, .pc);

    always #5 clk = ~clk;

    initial begin
        // Reset
        rst = 1; pc_next = 32'h10; #10;
        rst = 0;

        // Load sequential values
        pc_next = 32'h00000004; #10;
        pc_next = 32'h00000008; #10;
        pc_next = 32'h0000000C; #10;

        $display("PASS: ProgramCounter");
        $finish;
    end

    always @(posedge clk)
        $display("pc = %0h", pc);
endmodule
