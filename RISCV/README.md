# RISC-V Single-Cycle Processor

A single-cycle implementation of a RISC-V (RV32I subset) processor written in
SystemVerilog. Every instruction completes in one clock cycle: fetch, decode,
execute, memory access, and write-back all happen between two rising edges.

## Supported Instructions

| Format    | Instructions                                                 |
|-----------|--------------------------------------------------------------|
| R-type    | `add`, `sub`, `sll`, `slt`, `xor`, `srl`, `sra`, `or`, `and` |
| I-type    | ALU immediates (`addi`, `ori`, …), `lw`                      |
| S-type    | `sw`                                                         |
| B-type    | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`                   |
| J-type    | `jal`                                                        |
| U-type    | `lui`                                                        |

## Architecture

The top module `RISCV.sv` is pure structural wiring — it instantiates each
building block and connects the datapath. The classic single-cycle stages map
onto the modules as follows:

```
  Fetch        Decode            Execute         Memory        Write-back
 ┌───────┐   ┌────────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
 │  PC   │   │ ControlUnit│   │   ALU    │   │DataMemory│   │  Muxes   │
 │  IMem │ → │ ImmGen     │ → │ ALUCtrl  │ → │          │ → │ (wb/jal) │
 └───────┘   │ RegFile    │   │ BranchCmp│   └──────────┘   └──────────┘
             └────────────┘   └──────────┘
```

### Modules

Each subdirectory holds a `Design.sv` (the module) and a `Testbench.sv`
(a standalone unit test).

| Module               | Role                                                             |
|----------------------|------------------------------------------------------------------|
| `ProgramCounter`     | Holds the PC; updates to `pc_next` on each clock edge.           |
| `InstructionMemory`  | Word-addressed ROM; loads the program from `instrMem.hex`.       |
| `ControlUnit`        | Decodes the opcode into datapath control signals.                |
| `ImmediateGenerator` | Reassembles + sign-extends immediates per instruction format.    |
| `RegisterFile`       | 32×32-bit registers, `x0` hardwired to 0; 2 read / 1 write port. |
| `ALUControl`         | Maps `alu_op` + `funct3`/`funct7[5]` to a 4-bit ALU op code.     |
| `ALU`                | Performs the arithmetic/logic operation; emits a `zero` flag.    |
| `BranchComparator`   | Evaluates all six branch conditions from `funct3`.               |
| `DataMemory`         | Synchronous-write / async-read RAM for `lw` / `sw`.              |
| `Adder`              | Used for `PC+4` and `PC+immediate` (branch/jump targets).        |
| `Mux`                | Generic 2-to-1 32-bit multiplexer (reused across the datapath).  |

### Control Signals

| Signal       | Meaning                                                       |
|--------------|---------------------------------------------------------------|
| `reg_write`  | Write the result back to the register file.                   |
| `alu_src`    | 0 → ALU operand B is `rs2`; 1 → it's the immediate.           |
| `mem_write`  | Write to data memory (stores).                                |
| `mem_to_reg` | 0 → write ALU result to `rd`; 1 → write memory data.          |
| `branch`     | Instruction may branch (BranchComparator decides if taken).   |
| `jump`       | Unconditional `jal`; also writes `PC+4` into `rd`.            |
| `alu_op`     | `00` ADD, `01` SUB, `10` decode from `funct3`/`funct7`.       |

## Running the Simulation

The project is developed with [Icarus Verilog](http://iverilog.icarus.com/).

### Full processor

The top-level testbench `RISCV_tb.sv` runs a sample program, prints a per-cycle
trace, and checks the final register/memory state. The program is loaded from
`instrMem.hex` (hex, one 32-bit word per line) in the working directory.

```sh
iverilog -g2012 -o riscv_sim RISCV_tb.sv
vvp riscv_sim
```

A waveform is written to `riscv_sim.vcd` (view with GTKWave).

### A single module

Each module can be tested in isolation, e.g. the ALU:

```sh
iverilog -g2012 -o alu_test ALU/Design.sv ALU/Testbench.sv
vvp alu_test
```

## Sample Program (`instrMem.hex`)

The current program is a minimal add demo:

| Addr  | Hex        | Assembly            | Effect      |
|-------|------------|---------------------|-------------|
| 0x00  | `00500293` | `addi x5, x0, 5`    | `x5 = 5`    |
| 0x04  | `00a00313` | `addi x6, x0, 10`   | `x6 = 10`   |
| 0x08  | `00628533` | `add  x10, x5, x6`  | `x10 = 15`  |

Edit `instrMem.hex` (one 32-bit instruction word per line, hex) to run a
different program.

## Notes

- `InstructionMemory` is word-indexed: it drops `addr[1:0]` and uses
  `addr[9:2]` to index 256 words (1 KB of program space).
- `BranchComparator` is kept separate from the ALU so branch decisions feed
  the PC mux directly without going through the full ALU path.
- `SystemVerilog.md` contains supporting notes on the SystemVerilog used here.
