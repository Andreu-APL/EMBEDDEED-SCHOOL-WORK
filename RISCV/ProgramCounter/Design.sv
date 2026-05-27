// Program Counter
// Just a register that holds the address of the current instruction.
// Every cycle it loads pc_next, which comes from the datapath (PC+4,
// branch target, or jump target). On reset it goes back to address 0.

module ProgramCounter (
    input  logic        clk, rst,
    input  logic [31:0] pc_next,  // next address chosen by the datapath
    output logic [31:0] pc        // current instruction address
);
    always_ff @(posedge clk)
        pc <= rst ? 32'b0 : pc_next;
endmodule
