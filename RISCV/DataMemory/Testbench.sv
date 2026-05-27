module tb_DataMemory;
    logic        clk = 0, we;
    logic [31:0] addr, wd, rd;

    DataMemory dut (.clk, .we, .addr, .wd, .rd);

    always #5 clk = ~clk;

    initial begin
        // Write 0xABCD to address 0x00
        we = 1; addr = 32'h00; wd = 32'hABCD; #10;
        we = 0; #1;
        assert (rd == 32'hABCD) else $error("write/read fail: %0h", rd);

        // Write 0x1234 to address 0x04
        we = 1; addr = 32'h04; wd = 32'h1234; #10;
        we = 0; #1;
        assert (rd == 32'h1234) else $error("addr 4 fail: %0h", rd);

        // Old address still intact
        addr = 32'h00; #1;
        assert (rd == 32'hABCD) else $error("retention fail: %0h", rd);

        $display("PASS: DataMemory");
        $finish;
    end
endmodule
