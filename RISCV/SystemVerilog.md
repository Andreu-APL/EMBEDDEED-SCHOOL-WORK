# SystemVerilog

*From first principles to a working RISC-V processor.*

---

> "The only way to learn a new programming language is by writing programs in it."
> — Brian W. Kernighan & Dennis M. Ritchie

Hardware description languages are not programming languages. You are not telling a processor what to do step by step. You are *describing* what hardware to build — wires, gates, and registers — and the tools synthesize that description into real silicon or an FPGA configuration. Keep this distinction in mind at every step.

---

## Table of Contents

1. [A First Look](#1-a-first-look)
2. [Types and Values](#2-types-and-values)
3. [Combinational Logic](#3-combinational-logic)
4. [Sequential Logic](#4-sequential-logic)
5. [Operators](#5-operators)
6. [Parameters and Reuse](#6-parameters-and-reuse)
7. [Arrays and Memories](#7-arrays-and-memories)
8. [Functions and Tasks](#8-functions-and-tasks)
9. [Interfaces](#9-interfaces)
10. [RISC-V: The Architecture](#10-risc-v-the-architecture)
11. [RISC-V: Building the Datapath](#11-risc-v-building-the-datapath)
12. [RISC-V: The Control Unit](#12-risc-v-the-control-unit)
13. [RISC-V: Putting It Together](#13-risc-v-putting-it-together)
14. [Testbenches](#14-testbenches)

---

## 1. A First Look

The fundamental unit in SystemVerilog is the **module** — a black box with inputs and outputs. Here is the simplest useful one:

```systemverilog
module and_gate (
    input  logic a,
    input  logic b,
    output logic y
);
    assign y = a & b;
endmodule
```

Run it through your head. Two wires go in, one wire comes out. `assign` describes a permanent connection — whenever `a` or `b` change, `y` updates instantly. There is no clock, no sequence of operations. This is **combinational logic**.

Contrast it with C, where `y = a & b` executes once when the CPU reaches that line. Here it holds forever as long as the circuit is powered.

### 1.1 Ports

Every signal crossing a module boundary is a port. Direction is mandatory:

```systemverilog
input  logic       // signal enters this module
output logic       // signal leaves this module
inout  logic       // bidirectional (rare, mostly for buses)
```

Ports without a direction default to `inout` in Verilog. In SystemVerilog, always declare direction explicitly.

### 1.2 The Module Hierarchy

Real designs are built by connecting modules together. A module that contains other modules is called a **structural** description:

```systemverilog
module nand_gate (
    input  logic a, b,
    output logic y
);
    logic and_out;

    and_gate u_and (.a(a), .b(b), .y(and_out));  // instance of and_gate
    not_gate u_not (.a(and_out),  .y(y));          // instance of not_gate
endmodule
```

`.port_name(signal_name)` is the connection syntax. The left side is the port on the child module; the right side is the wire in the parent. Never use positional connections — they break silently when port order changes.

---

## 2. Types and Values

### 2.1 logic

Forget Verilog's `wire` and `reg`. SystemVerilog gives you one universal type:

```systemverilog
logic       // a single bit
logic [7:0] // an 8-bit bus (bit 7 is the MSB)
```

`logic` can hold four values:

| Value | Meaning |
|---|---|
| `0` | Logic zero |
| `1` | Logic one |
| `x` | Unknown (uninitialized or conflicting drivers) |
| `z` | High impedance (disconnected) |

`x` is your friend in simulation. An uninitialized register contains `x`, making bugs visible immediately. In real silicon there is no `x` — every bit is either 0 or 1, and uninitialized means unpredictable.

### 2.2 Bit Widths

```systemverilog
logic [31:0] word;    // 32 bits, word[31] is MSB, word[0] is LSB
logic [0:31] word_r;  // 32 bits, reversed — avoid this convention
```

Always use `[N-1:0]` — big-endian bit numbering is the universal convention.

**Slicing:**

```systemverilog
word[7:0]      // lower byte
word[31:24]    // upper byte
word[15:8]     // second byte
```

### 2.3 Literals

```systemverilog
8'b1010_0011   // binary,  8 bits, underscores allowed for readability
8'hA3          // hex,     8 bits (same value as above)
8'd163         // decimal, 8 bits (same value)
'0             // all zeros, width inferred from context
'1             // all ones,  width inferred
1'b0           // explicit single-bit zero
32'hDEAD_BEEF  // 32-bit hex
```

Width mismatches are silently truncated or zero-extended. Always specify widths for constants in expressions.

### 2.4 Other Types

```systemverilog
// Use in testbenches and behavioral models, NOT in synthesizable RTL:
integer i;          // 32-bit signed, for loop counters
int     count;      // same, SystemVerilog shorthand
real    voltage;    // floating point

// Synthesizable, useful in RTL:
typedef logic [31:0] word_t;    // type alias

typedef enum logic [1:0] {      // enumerated type
    IDLE  = 2'b00,
    FETCH = 2'b01,
    EXEC  = 2'b10,
    DONE  = 2'b11
} state_t;

typedef struct packed {         // packed struct
    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [2:0]  funct3;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [6:0]  funct7;
} r_type_t;
```

`struct packed` is laid out contiguously in bits — the first field is the MSB. This lets you cast a 32-bit instruction word directly to a struct:

```systemverilog
r_type_t instr;
assign instr = r_type_t'(instruction_bus);  // cast
```

---

## 3. Combinational Logic

Combinational logic has no memory. The outputs depend only on the current inputs. There are two ways to describe it.

### 3.1 Continuous Assignment

For simple expressions, `assign` is the right tool:

```systemverilog
assign y   = a & b;           // AND
assign y   = a | b;           // OR
assign y   = ~a;              // NOT
assign y   = a ^ b;           // XOR
assign sum = a + b;           // addition (creates an adder)
assign y   = sel ? a : b;     // 2:1 multiplexer
```

Each `assign` statement is an independent concurrent statement. Order does not matter. Writing two `assign` statements that drive the same signal creates a short circuit — both drivers fight, and the result is `x`.

### 3.2 always_comb

For more complex logic, use an `always_comb` block:

```systemverilog
always_comb begin
    case (sel)
        2'b00: y = a;
        2'b01: y = b;
        2'b10: y = c;
        2'b11: y = d;
    endcase
end
```

`always_comb` runs whenever any of its inputs change. The compiler verifies that the sensitivity list is complete — a guarantee Verilog's `always @(*)` could not make.

**The cardinal rule:** Every output must be assigned in every possible path through the block. If `sel` could take a value not covered by `case`, `y` would latch its previous value, inferring unwanted memory. Avoid this with a default:

```systemverilog
always_comb begin
    y = '0;              // default assignment at the top
    case (sel)
        2'b00: y = a;
        2'b01: y = b;
        // 2'b10, 2'b11 now safely default to '0
    endcase
end
```

### 3.3 A 4-bit Adder

```systemverilog
module adder #(parameter N = 4) (
    input  logic [N-1:0] a, b,
    input  logic         cin,
    output logic [N-1:0] sum,
    output logic         cout
);
    assign {cout, sum} = a + b + cin;
endmodule
```

`{cout, sum}` is **concatenation** — the carry out and sum are packed into a single `N+1`-bit result. The synthesizer infers a ripple-carry or carry-lookahead adder depending on the target and timing constraints.

### 3.4 Priority Encoder

```systemverilog
module priority_enc (
    input  logic [3:0] req,
    output logic [1:0] grant,
    output logic       valid
);
    always_comb begin
        valid = 1'b1;
        if      (req[3]) grant = 2'd3;
        else if (req[2]) grant = 2'd2;
        else if (req[1]) grant = 2'd1;
        else if (req[0]) grant = 2'd0;
        else begin
            grant = 2'd0;
            valid = 1'b0;
        end
    end
endmodule
```

`if-else if` chains imply priority — `req[3]` wins over all others. This maps to a cascade of multiplexers.

---

## 4. Sequential Logic

Sequential logic has memory. The output depends on current inputs **and past history**. All memory in synchronous digital design is implemented with **flip-flops** — elements that sample their input on the rising edge of a clock and hold the value until the next edge.

### 4.1 The D Flip-Flop

```systemverilog
module dff (
    input  logic clk, d,
    output logic q
);
    always_ff @(posedge clk)
        q <= d;
endmodule
```

`always_ff` tells the compiler this block must infer flip-flops. It runs only on the rising clock edge (`posedge clk`). `<=` is the **non-blocking assignment** — all right-hand sides are evaluated first, then all left-hand sides are updated simultaneously. This models the physical behavior of flip-flops correctly.

**Never use `=` (blocking assignment) in `always_ff`.** Never use `<=` (non-blocking) in `always_comb`. This rule prevents the most common class of simulation/synthesis mismatch.

### 4.2 Reset

Flip-flops in real designs need a reset to establish a known initial state:

```systemverilog
// Synchronous reset — resets on the clock edge
always_ff @(posedge clk)
    if (rst) q <= '0;
    else     q <= d;

// Asynchronous reset — resets immediately, regardless of clock
always_ff @(posedge clk or posedge rst)
    if (rst) q <= '0;
    else     q <= d;
```

Synchronous reset is preferred in most FPGA and ASIC flows. Asynchronous reset creates timing paths from `rst` to every register, complicating analysis.

### 4.3 Register

A register is just a multi-bit flip-flop:

```systemverilog
module register #(parameter N = 8) (
    input  logic         clk, rst, en,
    input  logic [N-1:0] d,
    output logic [N-1:0] q
);
    always_ff @(posedge clk)
        if      (rst) q <= '0;
        else if (en)  q <= d;
endmodule
```

The enable input `en` lets you hold the current value — when `en` is low, the register ignores `d`. The synthesizer implements this efficiently.

### 4.4 Counter

```systemverilog
module counter #(parameter N = 8) (
    input  logic         clk, rst,
    output logic [N-1:0] count
);
    always_ff @(posedge clk)
        if (rst) count <= '0;
        else     count <= count + 1'b1;
endmodule
```

### 4.5 Shift Register

```systemverilog
module shift_reg #(parameter N = 8) (
    input  logic clk, rst, sin,    // serial in
    output logic sout               // serial out
);
    logic [N-1:0] shreg;

    always_ff @(posedge clk)
        if (rst) shreg <= '0;
        else     shreg <= {shreg[N-2:0], sin};  // shift left, insert sin at LSB

    assign sout = shreg[N-1];
endmodule
```

`{shreg[N-2:0], sin}` concatenates bits 6..0 of `shreg` with `sin` to form a new 8-bit value — a left shift.

### 4.6 Finite State Machine

FSMs are the backbone of control logic. SystemVerilog's `enum` makes them readable:

```systemverilog
module traffic_light (
    input  logic clk, rst,
    output logic red, yellow, green
);
    typedef enum logic [1:0] {
        S_RED    = 2'b00,
        S_GREEN  = 2'b01,
        S_YELLOW = 2'b10
    } state_t;

    state_t state, next_state;
    logic [3:0] count;

    // State register
    always_ff @(posedge clk)
        if (rst) begin
            state <= S_RED;
            count <= '0;
        end else begin
            state <= next_state;
            count <= count + 1'b1;
        end

    // Next-state logic
    always_comb begin
        next_state = state;
        case (state)
            S_RED:    if (count == 4'd9)  next_state = S_GREEN;
            S_GREEN:  if (count == 4'd9)  next_state = S_YELLOW;
            S_YELLOW: if (count == 4'd2)  next_state = S_RED;
        endcase
    end

    // Output logic (Moore: depends only on state)
    assign red    = (state == S_RED);
    assign green  = (state == S_GREEN);
    assign yellow = (state == S_YELLOW);
endmodule
```

Three always blocks, each with one job: state register, next-state logic, output logic. Keep them separate. Merging them produces code that is harder to verify and synthesize correctly.

---

## 5. Operators

### 5.1 Bitwise

```systemverilog
a & b    // AND  (bit by bit)
a | b    // OR
a ^ b    // XOR
~a       // NOT
a ~^ b   // XNOR
```

### 5.2 Reduction

Reduce all bits of a single vector to one bit:

```systemverilog
&a       // AND  all bits: 1 only if every bit is 1
|a       // OR   all bits: 1 if any bit is 1
^a       // XOR  all bits: parity (1 if odd number of 1s)
~&a      // NAND
~|a      // NOR
```

### 5.3 Logical

```systemverilog
a && b   // logical AND (result is 1 bit: 0 or 1)
a || b   // logical OR
!a       // logical NOT
```

Use logical operators in `if` conditions. Use bitwise operators for signal manipulation.

### 5.4 Shift

```systemverilog
a >> 1   // logical right shift  (fills with 0)
a << 1   // logical left shift   (fills with 0)
a >>> 1  // arithmetic right shift (fills with sign bit)
a <<< 1  // arithmetic left shift (same as <<)
```

### 5.5 Concatenation and Replication

```systemverilog
{a, b, c}     // concatenate
{4{a}}        // replicate: a, a, a, a
{8{1'b0}}     // eight zeros — same as 8'b0
```

### 5.6 Comparison

```systemverilog
a == b    // equal (x or z in either operand → result is x)
a != b    // not equal
a === b   // case equality (x matches x, z matches z) — simulation only
a !== b   // case inequality — simulation only
a < b     // less than (unsigned)
a > b     // greater than
$signed(a) < $signed(b)  // signed comparison
```

---

## 6. Parameters and Reuse

A module without parameters is a fixed-size component. Parameters make modules reusable:

```systemverilog
module mux2 #(parameter N = 32) (
    input  logic [N-1:0] a, b,
    input  logic         sel,
    output logic [N-1:0] y
);
    assign y = sel ? b : a;
endmodule
```

Instantiate with different widths:

```systemverilog
mux2 #(.N(8))  byte_mux  (.a(a8),  .b(b8),  .sel(s), .y(y8));
mux2 #(.N(32)) word_mux  (.a(a32), .b(b32), .sel(s), .y(y32));
mux2           default_mx (.a(a32), .b(b32), .sel(s), .y(y32)); // N=32
```

### 6.1 Generate

`generate` instantiates modules or logic in a loop — the loop runs at elaboration time, not at simulation time:

```systemverilog
module ripple_adder #(parameter N = 4) (
    input  logic [N-1:0] a, b,
    input  logic         cin,
    output logic [N-1:0] sum,
    output logic         cout
);
    logic [N:0] carry;
    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : gen_fa
            full_adder fa (
                .a    (a[i]),
                .b    (b[i]),
                .cin  (carry[i]),
                .sum  (sum[i]),
                .cout (carry[i+1])
            );
        end
    endgenerate

    assign cout = carry[N];
endmodule
```

The `begin : gen_fa` label is required to give each instance a unique hierarchical name (`gen_fa[0].fa`, `gen_fa[1].fa`, etc.).

---

## 7. Arrays and Memories

### 7.1 Packed vs Unpacked

```systemverilog
logic [31:0] packed_vec;          // 32-bit packed vector — one element
logic [31:0] mem [0:255];         // unpacked array: 256 elements, each 32 bits
logic [31:0] mem2 [256];          // same, shorthand
logic [7:0]  matrix [4][8];       // 4 rows, 8 columns, each 8 bits
```

Packed dimensions are to the left of the name. Unpacked dimensions are to the right. You can only do arithmetic and bitwise operations on packed vectors. Arrays are indexed with `[]`.

### 7.2 Memory Read and Write

```systemverilog
module ram #(
    parameter DEPTH = 256,
    parameter WIDTH = 32
) (
    input  logic                      clk, we,
    input  logic [$clog2(DEPTH)-1:0]  addr,
    input  logic [WIDTH-1:0]          wdata,
    output logic [WIDTH-1:0]          rdata
);
    logic [WIDTH-1:0] mem [DEPTH];

    always_ff @(posedge clk)
        if (we) mem[addr] <= wdata;

    assign rdata = mem[addr];    // asynchronous read
endmodule
```

`$clog2(N)` is a system function that returns ⌈log₂(N)⌉ — the minimum number of bits needed to address N locations. A 256-entry memory needs 8-bit addresses: `$clog2(256) = 8`.

### 7.3 ROM via Initial Block

```systemverilog
logic [31:0] rom [256];

initial $readmemh("program.hex", rom);   // load hex file at simulation start
```

`$readmemh` reads a text file of hex values into the array. This is how you load a RISC-V program into instruction memory for simulation.

---

## 8. Functions and Tasks

Functions and tasks let you reuse behavioral code without instantiating modules.

### 8.1 Functions

A function returns a value and is used in expressions. It executes in zero simulation time:

```systemverilog
function automatic logic [31:0] sign_extend (
    input logic [11:0] imm
);
    return {{20{imm[11]}}, imm};    // replicate sign bit 20 times
endfunction
```

Usage:

```systemverilog
assign imm_ext = sign_extend(instr[31:20]);
```

`automatic` means local variables are allocated on each call — required for recursive functions and for functions called from multiple places in simulation.

### 8.2 Tasks

Tasks can consume simulation time and have no return value:

```systemverilog
task automatic write_reg (
    input logic [4:0]  addr,
    input logic [31:0] data
);
    @(posedge clk);           // wait for clock edge
    we   = 1'b1;
    waddr = addr;
    wdata = data;
    @(posedge clk);
    we   = 1'b0;
endtask
```

Tasks live in testbenches. Keep them out of synthesizable RTL.

---

## 9. Interfaces

An interface bundles related signals into a named group, eliminating long port lists:

```systemverilog
interface mem_if (input logic clk);
    logic        we;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    modport master (output we, addr, wdata, input rdata);
    modport slave  (input  we, addr, wdata, output rdata);
endinterface
```

A `modport` defines the directional view of the interface from a specific module's perspective:

```systemverilog
module cpu (mem_if.master mem, input logic clk, rst);
    // mem.we, mem.addr, etc. are available
endmodule

module memory (mem_if.slave mem);
    // ...
endmodule
```

At the top level:

```systemverilog
module top;
    logic clk;
    mem_if bus (.clk(clk));
    cpu  u_cpu  (.mem(bus), .clk(clk), .rst(rst));
    memory u_mem (.mem(bus));
endmodule
```

---

## 10. RISC-V: The Architecture

RISC-V is an open ISA. We implement RV32I — the 32-bit base integer instruction set. It has:

- 32 general-purpose registers, x0–x31, each 32 bits wide
- x0 is hardwired to zero
- 32-bit instructions, word-aligned
- Load/store architecture — arithmetic happens only in registers

### 10.1 Instruction Formats

All instructions are 32 bits. The format determines how the bits are interpreted:

```
R-type: [funct7|rs2|rs1|funct3|rd|opcode]  — register-register ops
         31:25  24:20 19:15 14:12 11:7 6:0

I-type: [imm[11:0]|rs1|funct3|rd|opcode]   — immediate, loads
         31:20    19:15 14:12 11:7 6:0

S-type: [imm[11:5]|rs2|rs1|funct3|imm[4:0]|opcode]  — stores
         31:25    24:20 19:15 14:12 11:7      6:0

B-type: [imm[12|10:5]|rs2|rs1|funct3|imm[4:1|11]|opcode]  — branches
         31:25        24:20 19:15 14:12 11:7          6:0

U-type: [imm[31:12]|rd|opcode]  — LUI, AUIPC
         31:12      11:7 6:0

J-type: [imm[20|10:1|11|19:12]|rd|opcode]  — JAL
         31:12                  11:7 6:0
```

The opcode always occupies bits [6:0]. Source and destination register addresses always occupy the same fields when present. The immediate encoding is scrambled to keep the opcode, rd, rs1, rs2 fields in constant positions.

### 10.2 Opcodes We Will Implement

| Instruction | opcode | Type |
|---|---|---|
| ADD, SUB, AND, OR, XOR, SLT | 7'b0110011 | R |
| ADDI, ANDI, ORI, XORI, SLTI | 7'b0010011 | I |
| LW | 7'b0000011 | I |
| SW | 7'b0100011 | S |
| BEQ, BNE, BLT, BGE | 7'b1100011 | B |
| JAL | 7'b1101111 | J |
| LUI | 7'b0110111 | U |

### 10.3 Single-Cycle Execution

In a single-cycle processor, every instruction completes in exactly one clock cycle:

1. **Fetch** — read the instruction from memory at address PC
2. **Decode** — extract fields, read registers, compute immediate
3. **Execute** — ALU computes result or address
4. **Memory** — read or write data memory
5. **Writeback** — write result to destination register
6. **PC update** — advance PC to next instruction or branch target

All five stages happen combinationally; only the PC register and the data memory are clocked. This is simple but slow — the clock period must be long enough for the slowest instruction (typically a load).

---

## 11. RISC-V: Building the Datapath

### 11.1 Immediate Generator

The immediate must be reconstructed from the scrambled instruction bits and sign-extended to 32 bits:

```systemverilog
module imm_gen (
    input  logic [31:0] instr,
    output logic [31:0] imm_I,
    output logic [31:0] imm_S,
    output logic [31:0] imm_B,
    output logic [31:0] imm_U,
    output logic [31:0] imm_J
);
    always_comb begin
        // I-type: instr[31:20]
        imm_I = {{20{instr[31]}}, instr[31:20]};

        // S-type: instr[31:25], instr[11:7]
        imm_S = {{20{instr[31]}}, instr[31:25], instr[11:7]};

        // B-type: instr[31], instr[7], instr[30:25], instr[11:8], 0
        imm_B = {{19{instr[31]}}, instr[31], instr[7],
                  instr[30:25], instr[11:8], 1'b0};

        // U-type: instr[31:12], 12'b0
        imm_U = {instr[31:12], 12'b0};

        // J-type: instr[31], instr[19:12], instr[20], instr[30:21], 0
        imm_J = {{11{instr[31]}}, instr[31], instr[19:12],
                  instr[20], instr[30:21], 1'b0};
    end
endmodule
```

### 11.2 Register File

```systemverilog
module reg_file (
    input  logic        clk,
    input  logic        we,
    input  logic [4:0]  rs1, rs2, rd,
    input  logic [31:0] wd,
    output logic [31:0] rd1, rd2
);
    logic [31:0] regs [31:0];

    always_ff @(posedge clk)
        if (we && rd != '0)
            regs[rd] <= wd;

    assign rd1 = (rs1 != '0) ? regs[rs1] : '0;
    assign rd2 = (rs2 != '0) ? regs[rs2] : '0;
endmodule
```

The guard `rd != '0` enforces x0 = 0 on writes. The guard on reads returns zero without looking up the array.

### 11.3 ALU

The ALU performs the computation specified by the control unit:

```systemverilog
// ALU operation codes
typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_AND  = 4'b0010,
    ALU_OR   = 4'b0011,
    ALU_XOR  = 4'b0100,
    ALU_SLT  = 4'b0101,   // signed less than
    ALU_SLTU = 4'b0110,   // unsigned less than
    ALU_SLL  = 4'b0111,   // shift left logical
    ALU_SRL  = 4'b1000,   // shift right logical
    ALU_SRA  = 4'b1001,   // shift right arithmetic
    ALU_LUI  = 4'b1010    // pass through operand B
} alu_op_t;

module alu (
    input  logic [31:0] a, b,
    input  alu_op_t     op,
    output logic [31:0] result,
    output logic        zero
);
    always_comb begin
        case (op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLT:  result = {31'b0, $signed(a) < $signed(b)};
            ALU_SLTU: result = {31'b0, a < b};
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            ALU_LUI:  result = b;
            default:  result = '0;
        endcase
    end

    assign zero = (result == '0);
endmodule
```

`$signed(a)` casts the value to a signed interpretation for arithmetic right shift and signed comparisons. No hardware changes — only the interpretation of the MSB changes.

`zero` is used by the branch unit: BEQ branches when `zero` is 1, BNE when `zero` is 0.

### 11.4 Instruction Memory

```systemverilog
module instr_mem #(
    parameter DEPTH = 256    // 256 words = 1KB
) (
    input  logic [31:0] addr,
    output logic [31:0] instr
);
    logic [31:0] mem [DEPTH];

    initial $readmemh("program.hex", mem);

    assign instr = mem[addr[31:2]];    // word-addressed: drop 2 LSBs
endmodule
```

`addr[31:2]` strips the two LSBs because RISC-V instructions are 4-byte aligned — the byte address divided by 4 gives the word index.

### 11.5 Data Memory

```systemverilog
module data_mem #(
    parameter DEPTH = 256
) (
    input  logic        clk, we,
    input  logic [31:0] addr, wdata,
    output logic [31:0] rdata
);
    logic [31:0] mem [DEPTH];

    always_ff @(posedge clk)
        if (we) mem[addr[31:2]] <= wdata;

    assign rdata = mem[addr[31:2]];
endmodule
```

### 11.6 Program Counter

```systemverilog
module pc_reg (
    input  logic        clk, rst,
    input  logic [31:0] pc_next,
    output logic [31:0] pc
);
    always_ff @(posedge clk)
        if (rst) pc <= '0;
        else     pc <= pc_next;
endmodule
```

`pc_next` is computed by the datapath: either `pc + 4` (sequential) or a branch/jump target.

---

## 12. RISC-V: The Control Unit

The control unit decodes the instruction and produces control signals that configure the datapath. It is purely combinational — a function from opcode and funct fields to control bits.

### 12.1 Control Signals

```systemverilog
typedef struct packed {
    logic        reg_write;    // write result to register file
    logic        alu_src;      // 0=rs2, 1=immediate
    logic        mem_write;    // write data memory
    logic        mem_read;     // read data memory
    logic        mem_to_reg;   // 0=ALU result, 1=memory data
    logic        branch;       // is this a branch instruction?
    logic        jump;         // is this a jump instruction?
    logic        lui;          // is this LUI?
    alu_op_t     alu_op;       // ALU operation
    logic [2:0]  funct3;       // passed through for branch type
} ctrl_t;
```

### 12.2 Main Decoder

```systemverilog
module control_unit (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    output ctrl_t      ctrl
);
    always_comb begin
        // Safe defaults — prevents latches
        ctrl = '0;

        case (opcode)
            7'b0110011: begin   // R-type
                ctrl.reg_write = 1'b1;
                ctrl.alu_src   = 1'b0;
                case ({funct7, funct3})
                    10'b0000000_000: ctrl.alu_op = ALU_ADD;
                    10'b0100000_000: ctrl.alu_op = ALU_SUB;
                    10'b0000000_111: ctrl.alu_op = ALU_AND;
                    10'b0000000_110: ctrl.alu_op = ALU_OR;
                    10'b0000000_100: ctrl.alu_op = ALU_XOR;
                    10'b0000000_010: ctrl.alu_op = ALU_SLT;
                    10'b0000000_011: ctrl.alu_op = ALU_SLTU;
                    10'b0000000_001: ctrl.alu_op = ALU_SLL;
                    10'b0000000_101: ctrl.alu_op = ALU_SRL;
                    10'b0100000_101: ctrl.alu_op = ALU_SRA;
                    default:         ctrl.alu_op = ALU_ADD;
                endcase
            end

            7'b0010011: begin   // I-type ALU
                ctrl.reg_write = 1'b1;
                ctrl.alu_src   = 1'b1;
                case (funct3)
                    3'b000: ctrl.alu_op = ALU_ADD;
                    3'b111: ctrl.alu_op = ALU_AND;
                    3'b110: ctrl.alu_op = ALU_OR;
                    3'b100: ctrl.alu_op = ALU_XOR;
                    3'b010: ctrl.alu_op = ALU_SLT;
                    3'b011: ctrl.alu_op = ALU_SLTU;
                    3'b001: ctrl.alu_op = ALU_SLL;
                    3'b101: ctrl.alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    default: ctrl.alu_op = ALU_ADD;
                endcase
            end

            7'b0000011: begin   // LW
                ctrl.reg_write  = 1'b1;
                ctrl.alu_src    = 1'b1;
                ctrl.mem_read   = 1'b1;
                ctrl.mem_to_reg = 1'b1;
                ctrl.alu_op     = ALU_ADD;
            end

            7'b0100011: begin   // SW
                ctrl.alu_src   = 1'b1;
                ctrl.mem_write = 1'b1;
                ctrl.alu_op    = ALU_ADD;
            end

            7'b1100011: begin   // Branch (BEQ, BNE, BLT, BGE)
                ctrl.branch  = 1'b1;
                ctrl.alu_op  = ALU_SUB;   // subtract to compare
                ctrl.funct3  = funct3;
            end

            7'b1101111: begin   // JAL
                ctrl.reg_write = 1'b1;
                ctrl.jump      = 1'b1;
            end

            7'b0110111: begin   // LUI
                ctrl.reg_write = 1'b1;
                ctrl.lui       = 1'b1;
                ctrl.alu_op    = ALU_LUI;
            end
        endcase
    end
endmodule
```

### 12.3 Branch Condition

Different branch instructions test different conditions:

```systemverilog
module branch_unit (
    input  logic [2:0]  funct3,
    input  logic        zero,
    input  logic [31:0] rs1, rs2,
    output logic        branch_taken
);
    always_comb begin
        case (funct3)
            3'b000: branch_taken = zero;                             // BEQ
            3'b001: branch_taken = ~zero;                            // BNE
            3'b100: branch_taken = $signed(rs1) < $signed(rs2);     // BLT
            3'b101: branch_taken = $signed(rs1) >= $signed(rs2);    // BGE
            3'b110: branch_taken = rs1 < rs2;                       // BLTU
            3'b111: branch_taken = rs1 >= rs2;                      // BGEU
            default: branch_taken = 1'b0;
        endcase
    end
endmodule
```

---

## 13. RISC-V: Putting It Together

### 13.1 The Top-Level Datapath

```systemverilog
module riscv_single_cycle (
    input logic clk, rst
);
    // ── Wire declarations ──────────────────────────────────────────
    logic [31:0] pc, pc_next, pc_plus4, pc_branch, pc_jump;
    logic [31:0] instr;
    logic [31:0] rd1, rd2;
    logic [31:0] imm_I, imm_S, imm_B, imm_U, imm_J;
    logic [31:0] alu_a, alu_b, alu_result;
    logic [31:0] mem_rdata, wb_data;
    logic        zero, branch_taken;
    ctrl_t       ctrl;

    // ── PC ────────────────────────────────────────────────────────
    pc_reg u_pc (
        .clk     (clk),
        .rst     (rst),
        .pc_next (pc_next),
        .pc      (pc)
    );

    assign pc_plus4  = pc + 32'd4;
    assign pc_branch = pc + imm_B;
    assign pc_jump   = pc + imm_J;

    always_comb begin
        if      (ctrl.jump)                       pc_next = pc_jump;
        else if (ctrl.branch && branch_taken)     pc_next = pc_branch;
        else                                      pc_next = pc_plus4;
    end

    // ── Instruction Fetch ─────────────────────────────────────────
    instr_mem u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // ── Decode ────────────────────────────────────────────────────
    control_unit u_ctrl (
        .opcode (instr[6:0]),
        .funct3 (instr[14:12]),
        .funct7 (instr[31:25]),
        .ctrl   (ctrl)
    );

    imm_gen u_imm (
        .instr (instr),
        .imm_I (imm_I),
        .imm_S (imm_S),
        .imm_B (imm_B),
        .imm_U (imm_U),
        .imm_J (imm_J)
    );

    reg_file u_rf (
        .clk  (clk),
        .we   (ctrl.reg_write),
        .rs1  (instr[19:15]),
        .rs2  (instr[24:20]),
        .rd   (instr[11:7]),
        .wd   (wb_data),
        .rd1  (rd1),
        .rd2  (rd2)
    );

    // ── Execute ───────────────────────────────────────────────────
    assign alu_a = rd1;
    assign alu_b = ctrl.alu_src ? imm_I : rd2;   // SW uses imm_S — see below

    // For SW, the ALU computes addr from rs1 + imm_S
    // Override alu_b for store instructions
    logic [31:0] alu_b_final;
    always_comb begin
        if (instr[6:0] == 7'b0100011)     // SW
            alu_b_final = imm_S;
        else
            alu_b_final = alu_b;
    end

    alu u_alu (
        .a      (alu_a),
        .b      (alu_b_final),
        .op     (ctrl.alu_op),
        .result (alu_result),
        .zero   (zero)
    );

    branch_unit u_br (
        .funct3       (instr[14:12]),
        .zero         (zero),
        .rs1          (rd1),
        .rs2          (rd2),
        .branch_taken (branch_taken)
    );

    // ── Memory ────────────────────────────────────────────────────
    data_mem u_dmem (
        .clk   (clk),
        .we    (ctrl.mem_write),
        .addr  (alu_result),
        .wdata (rd2),
        .rdata (mem_rdata)
    );

    // ── Writeback ─────────────────────────────────────────────────
    always_comb begin
        if      (ctrl.lui)        wb_data = imm_U;
        else if (ctrl.jump)       wb_data = pc_plus4;   // JAL saves return addr
        else if (ctrl.mem_to_reg) wb_data = mem_rdata;
        else                      wb_data = alu_result;
    end

endmodule
```

### 13.2 Tracing the Execution of ADD x3, x1, x2

Walk one instruction through the datapath:

1. **Fetch:** `instr_mem` reads the 32-bit word at `pc`. The instruction is `32'h00208133` (ADD x3, x1, x2).
2. **Decode:** opcode=`0110011` (R-type). `ctrl.reg_write=1`, `ctrl.alu_src=0`, `ctrl.alu_op=ALU_ADD`. `rs1=1`, `rs2=2`, `rd=3`.
3. **Register read:** `rd1 = regs[1]`, `rd2 = regs[2]`.
4. **Execute:** `alu_b_final = rd2` (since `alu_src=0`). `alu_result = rd1 + rd2`.
5. **Memory:** skipped — `mem_write=0`, `mem_read=0`.
6. **Writeback:** `wb_data = alu_result`. On the next rising clock edge, `regs[3] <= wb_data`.
7. **PC:** `pc_next = pc + 4`.

### 13.3 Tracing LW x5, 8(x2)

1. **Fetch:** opcode=`0000011`. `rs1=2`, `rd=5`, `imm_I=8`.
2. **Decode:** `ctrl.reg_write=1`, `ctrl.alu_src=1`, `ctrl.mem_read=1`, `ctrl.mem_to_reg=1`, `ctrl.alu_op=ALU_ADD`.
3. **Register read:** `rd1 = regs[2]`.
4. **Execute:** `alu_b_final = imm_I = 8`. `alu_result = regs[2] + 8` (the memory address).
5. **Memory:** `mem_rdata = data_mem[alu_result >> 2]`.
6. **Writeback:** `wb_data = mem_rdata`. `regs[5] <= wb_data`.

---

## 14. Testbenches

A testbench is a SystemVerilog module with no ports that drives the design and checks results. It is not synthesizable.

### 14.1 Basic Structure

```systemverilog
module riscv_tb;
    // DUT signals
    logic clk, rst;

    // Instantiate the device under test
    riscv_single_cycle dut (
        .clk (clk),
        .rst (rst)
    );

    // Clock generation — 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Stimulus
    initial begin
        rst = 1;
        repeat(2) @(posedge clk);
        rst = 0;

        // Let the program run for 100 cycles
        repeat(100) @(posedge clk);

        $display("Simulation complete.");
        $finish;
    end
endmodule
```

`#5` delays 5 time units. `always #5 clk = ~clk` toggles the clock forever. `repeat(N) @(posedge clk)` waits N rising edges.

### 14.2 Self-Checking Testbench

Manual inspection of waveforms does not scale. Check results automatically:

```systemverilog
module alu_tb;
    logic [31:0] a, b, result;
    alu_op_t     op;
    logic        zero;

    alu dut (.a(a), .b(b), .op(op), .result(result), .zero(zero));

    task automatic check (
        input logic [31:0] a_in, b_in, expected,
        input alu_op_t     op_in,
        input string       name
    );
        a = a_in;
        b = b_in;
        op = op_in;
        #1;    // let combinational settle
        if (result !== expected)
            $error("%s: got %0h, expected %0h", name, result, expected);
        else
            $display("%s: PASS", name);
    endtask

    initial begin
        check(32'd10, 32'd3,  32'd13, ALU_ADD, "ADD");
        check(32'd10, 32'd3,  32'd7,  ALU_SUB, "SUB");
        check(32'hFF, 32'h0F, 32'h0F, ALU_AND, "AND");
        check(32'd5,  32'd7,  32'd0,  ALU_SLT, "SLT 5<7? no wait, 5<7=1");
        $finish;
    end
endmodule
```

`$error` prints a red error message and increments the error count. `$display` prints to the console. Use `%0h` for hex, `%0d` for decimal, `%0b` for binary.

### 14.3 Dumping Waveforms

```systemverilog
initial begin
    $dumpfile("waves.vcd");    // VCD format — open with GTKWave
    $dumpvars(0, riscv_tb);   // dump all signals in riscv_tb and below
end
```

Open `waves.vcd` in GTKWave to see every signal over time. This is your oscilloscope.

### 14.4 Running a Program

Write a small RV32I assembly program, assemble it to a hex file, and load it:

```asm
# test.s — compute 5 + 3, store to memory
addi x1, x0, 5       # x1 = 5
addi x2, x0, 3       # x2 = 3
add  x3, x1, x2      # x3 = 8
sw   x3, 0(x0)       # mem[0] = 8
```

Assemble with `riscv32-unknown-elf-as` and convert to hex with `riscv32-unknown-elf-objcopy -O verilog`. Then in the testbench, check `data_mem.mem[0]` equals 32'd8.

---

## Appendix: Common Pitfalls

**Inferring latches.** In `always_comb`, if any output is not assigned in every branch, the synthesizer infers a latch. Latch inference is almost always a mistake. Fix it by assigning defaults at the top of the block.

**Blocking in always_ff.** Using `=` instead of `<=` in clocked blocks causes simulation/synthesis mismatch — simulation updates the variable immediately and subsequent reads in the same block see the new value, but real flip-flops do not. Always use `<=` in `always_ff`.

**Missing reset.** Flip-flops without reset contain `x` at simulation start. The FSM will take unpredictable paths. Add synchronous reset to every state register.

**Width mismatches.** Mixing widths silently truncates or zero-extends. Be explicit with widths in literals and use `$signed()` when you need signed arithmetic.

**x0 hazard.** In the register file, always guard writes to x0. A write to x0 must be silently discarded. Without the guard, x0 would contain whatever was last written, and reads of x0 would return non-zero values.

**PC alignment.** RISC-V instructions are 4-byte aligned. When indexing instruction memory with a byte address, always right-shift by 2 or drop the two LSBs.

---

*The design presented here implements the RV32I base integer ISA as a single-cycle processor. From here, the natural extensions are: pipelining (five stages, forwarding, hazard detection), a cache hierarchy, and the M extension (multiply/divide). Each step introduces a different class of problem — timing, data hazards, and complex state machines respectively.*

*The best way to learn is to build. Start with the ALU, verify it exhaustively, then add the register file, then instruction memory, and assemble the full datapath last. Test each module in isolation before connecting it.*
