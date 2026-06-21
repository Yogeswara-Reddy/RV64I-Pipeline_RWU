# RV64I 5-Stage Pipelined CPU

A 5-stage pipelined RISC-V RV64I CPU implemented in SystemVerilog, based on the RWU RV64I single-cycle design by [asiggel](https://github.com/asiggel). The pipeline was added by [Yogeswara-Reddy](https://github.com/Yogeswara-Reddy).

---

## Overview

This project converts the original single-cycle RV64I CPU into a classic 5-stage pipeline. The pipeline follows the standard RISC-V textbook design with:

- 5 pipeline stages: **IF → ID → EX → MEM → WB**
- 4 inter-stage pipeline registers: `if_id_r`, `id_ex_r`, `ex_mem_r`, `mem_wb_r`
- **Stall-only** hazard handling (no data forwarding network)
- **Write-first bypass** in the register file for WB→ID same-cycle forwarding
- Branch resolution in the **EX stage** with a 2-cycle flush penalty
- All pipeline register structs defined in `as_pack.sv`

---

## Pipeline Stages

| Stage | Name | Description | Pipeline Register |
|-------|------|-------------|-------------------|
| 1 | IF  | Instruction Fetch — reads instruction from memory using PC | `if_id_r` |
| 2 | ID  | Instruction Decode + Register Read | `id_ex_r` |
| 3 | EX  | Execute — ALU operations + Branch resolution | `ex_mem_r` |
| 4 | MEM | Memory Access — Load/Store operations | `mem_wb_r` |
| 5 | WB  | Write Back — result written to register file | — |

---

## Stage Details

### Stage 1 — IF: Instruction Fetch

**Source:** `asCPUx.sv`

The IF stage holds a 64-bit program counter (`pc_r`) and drives the instruction bus address (`iBusAddr_o`). On every cycle it computes `pc + 4`. The next-PC mux has three cases:

| Condition | Next PC |
|-----------|---------|
| Branch taken (`take_s` from EX) | `pc_branch_ex_s` (branch/jump target) |
| Stall (`stall_if_s` from hazard unit) | `pc_r` (hold current PC) |
| Normal | `pc_r + 4` |

The **IF/ID pipeline register** (`if_id_r`) latches `{pc, instr, valid}` on each rising clock edge. It is reset to a NOP (`32'h00000013`) on reset or branch flush.

---

### Stage 2 — ID: Instruction Decode & Register Read

**Source:** `asCPUx.sv`, `asInstrDecode.sv`, `asRegFile.sv`

The ID stage decodes the instruction from `if_id_r.instr` and reads operands from the 32×64-bit register file in the same cycle.

Sub-modules instantiated here:

- `as_regfile` — reads `rs1` (bits [19:15]) and `rs2` (bits [24:20]) from the register file
- `as_instr_decode` — generates all control signals from the 7-bit opcode, `func3`, and `func7[5]`
- `as_hazard` — detects load-use hazards and drives stall/flush signals

**Control signals produced:**

| Signal | Type | Description |
|--------|------|-------------|
| `alu_op_s` | `alu_op_t` | ALU operation (ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA, and W-variants) |
| `br_op_s` | `br_op_t` | Branch comparator operation (EQ, NE, LT, GE, LTU, GEU, NONE) |
| `alu_src_a_s` | `mux_a_t` | ALU operand A source: register / PC / zero |
| `alu_src_b_s` | `logic` | ALU operand B source: 0 = rs2, 1 = immediate |
| `imm_src_s` | `imm_src_t` | Immediate format: I / S / B / U / J / NONE |
| `result_src_s` | `result_src_t` | WB result source: ALU / MEM / PC+4 |
| `reg_wr_s` | `logic` | Register file write enable |
| `mem_wr_s` | `logic` | Data memory write enable |
| `mem_rd_s` | `logic` | Data memory read enable |
| `jump_s` | `logic` | High for JAL/JALR — selects rs1 as branch base |
| `trap_illegal_s` | `logic` | Asserted on unrecognized opcode/func3 |

The **ID/EX pipeline register** (`id_ex_r`) is flushed to zero on reset or when the hazard unit asserts `flush_ex_s`.

---

### Stage 3 — EX: Execute

**Source:** `asCPUx.sv`, `asAlu.sv`, `asAluBr.sv`

The EX stage performs ALU computation, branch/jump resolution, and constructs the branch target address.

**ALU operand A mux** (`alu_src_a_mux_s`):

| `id_ex_r.alu_src_a` | Selects |
|----------------------|---------|
| `SRC_REGA` | `id_ex_r.rs1_data` |
| `SRC_PC` | `id_ex_r.pc` (for AUIPC) |
| `SRC_ZERO` | `64'b0` (for LUI) |

**ALU operand B mux** (`alu_src_b_mux_s`):

| `id_ex_r.alu_src_b` | Selects |
|----------------------|---------|
| `0` | `id_ex_r.rs2_data` |
| `1` | `id_ex_r.imm` |

Sub-modules:

- `as_alu` — 64-bit integer ALU with 15 operations including 32-bit word variants (ADDW, SUBW, SLLW, SRLW, SRAW) sign-extended to 64 bits
- `as_alu_branch` — branch comparator that evaluates BEQ, BNE, BLT, BGE, BLTU, BGEU and outputs `take_s`

**Branch/Jump target computation:**

```
pc_or_rs1_s    = jump ? id_ex_r.rs1_data : id_ex_r.pc
pc_branch_ex_s = pc_or_rs1_s + id_ex_r.imm
```

When `take_s` is asserted, `branch_flush_s` goes high — this redirects the PC to the branch target and flushes IF/ID and ID/EX with NOP bubbles (2-cycle branch penalty).

The **EX/MEM pipeline register** (`ex_mem_r`) latches: `{alu_result, rs2_data, pc_plus4, rd_addr, result_src, reg_wr, mem_wr, mem_rd, valid}`.

---

### Stage 4 — MEM: Memory Access

**Source:** `asCPUx.sv`

The MEM stage drives the external data bus for loads and stores.

| Signal | Direction | Value |
|--------|-----------|-------|
| `dBusAddr_o` | Output | `ex_mem_r.alu_result` (effective address) |
| `dBusDataWr_o` | Output | `ex_mem_r.rs2_data` (store data) |
| `dBusWe_o` | Output | `ex_mem_r.mem_wr & ex_mem_r.valid` |
| `dBusDataRd_i` | Input | Read data from external data memory |

The **MEM/WB pipeline register** (`mem_wb_r`) latches: `{alu_result, mem_data, pc_plus4, rd_addr, result_src, reg_wr, valid}`.

---

### Stage 5 — WB: Write Back

**Source:** `asCPUx.sv`

The WB stage selects the result to write back to the register file:

| `result_src` | `wb_result_s` | Used by |
|---|---|---|
| `RES_ALU` | `mem_wb_r.alu_result` | R-type, I-type ALU, AUIPC, LUI |
| `RES_MEM` | `mem_wb_r.mem_data` | Load instructions |
| `RES_PC4` | `mem_wb_r.pc_plus4` | JAL, JALR (return address) |

The write is enabled by `wb_reg_wr_s = mem_wb_r.reg_wr & mem_wb_r.valid`. Register `x0` is hardwired to zero.

---

## Pipeline Registers

All four inter-stage registers are defined as packed structs in `as_pack.sv`:

| Register | Type | Key Fields |
|----------|------|------------|
| `if_id_r` | `if_id_reg_t` | `pc[63:0]`, `instr[31:0]`, `valid` |
| `id_ex_r` | `id_ex_reg_t` | `pc`, `rs1_data`, `rs2_data`, `imm`, `rs1_addr[4:0]`, `rs2_addr[4:0]`, `rd_addr[4:0]`, `result_src`, `alu_op`, `br_op`, `alu_src_a`, `alu_src_b`, `reg_wr`, `mem_wr`, `mem_rd`, `jump`, `imm_src`, `valid` |
| `ex_mem_r` | `ex_mem_reg_t` | `alu_result[63:0]`, `rs2_data[63:0]`, `pc_plus4[63:0]`, `rd_addr[4:0]`, `result_src`, `reg_wr`, `mem_wr`, `mem_rd`, `valid` |
| `mem_wb_r` | `mem_wb_reg_t` | `alu_result[63:0]`, `mem_data[63:0]`, `pc_plus4[63:0]`, `rd_addr[4:0]`, `result_src`, `reg_wr`, `valid` |

---

## Hazard Handling

**Source:** `asHazard.sv`

### Data Hazards — Load-Use Stall

The hazard detection unit (`as_hazard`) monitors two pipeline stages for load-use conflicts:

**Case 1 — Load in EX stage:** A load is in EX while the next instruction (in ID) needs its result.

```
load_use_ex = id_ex_r.mem_rd
           && (id_ex_r.rs1_addr != 0)
           && (id_ex_r.rs1_addr == if_id_r.rs1 || id_ex_r.rs1_addr == if_id_r.rs2)
```

**Case 2 — Load in MEM stage:** Required for synchronous data memory that takes an extra cycle.

```
load_use_mem = ex_mem_r.mem_rd
            && (ex_mem_r.rd_addr != 0)
            && (ex_mem_r.rd_addr == if_id_r.rs1 || ex_mem_r.rd_addr == if_id_r.rs2)
```

When either case fires, the hazard unit asserts:

- `stall_if_o` — freezes the PC
- `stall_id_o` — freezes the IF/ID register
- `flush_ex_o` — clears the ID/EX register (inserts a NOP bubble into EX)

### Control Hazards — Branch Flush

Branch resolution happens in the EX stage. When `take_s` is asserted (branch taken, JAL, JALR), the pipeline redirects the PC to `pc_branch_ex_s` and flushes `if_id_r` and `id_ex_r` with NOP bubbles — a 2-cycle branch penalty.

### WB→ID Same-Cycle Forwarding

The register file implements write-first (bypass) logic: if WB is writing to the same address being read by ID in the same cycle, the new write data is forwarded directly to the read port, avoiding a one-cycle stall:

```
rdata01_o = (rs1 == 0)           ? 0
          : (we && waddr == rs1) ? wdata   // WB→ID bypass
          : regfile[rs1]
```

---

## Module Reference

| Module | File | Description |
|--------|------|-------------|
| `as_cpux` | `src/asCPUx.sv` | Top-level CPU — 5-stage pipeline datapath |
| `as_hazard` | `src/asHazard.sv` | Hazard detection (load-use stall + branch flush) |
| `as_regfile` | `src/asRegFile.sv` | 32×64-bit register file with write-first bypass |
| `as_instr_decode` | `src/asInstrDecode.sv` | Control signal generator (opcode → all control lines) |
| `as_alu` | `src/asAlu.sv` | 64-bit ALU (15 operations incl. RV64I W-variants) |
| `as_alu_branch` | `src/asAluBr.sv` | Branch comparator (BEQ/BNE/BLT/BGE/BLTU/BGEU) |
| `as_decode` | `src/asDecode.sv` | Address decoder — chip-select for memory-mapped I/O |
| `as_pack` | `src/as_pack.sv` | Package — types, enums, pipeline register structs, constants |
| `as_imem` | `src/asIMem.sv` | Instruction memory (scan-chain loadable BRAM) |
| `as_top_mem` | `src/asTopMem.sv` | Data memory top-level wrapper |
| `as_mbpi` | `src/asMBpi.sv` | Memory bus byte/half/word packing for loads |
| `as_sbpi` | `src/asSBpi.sv` | Memory bus byte/half/word packing for stores |
| `as_control_all` | `src/asControlAll.sv` | System-level control (CGU, GPIO, QSPI) |

---

## Supported Instructions

The ISA decoder (`asInstrDecode.sv`) handles the full RV64I base integer instruction set:

| Format | Instructions |
|--------|-------------|
| R-type | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU, ADDW, SUBW, SLLW, SRLW, SRAW |
| I-type | ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU, ADDIW, SLLIW, SRLIW, SRAIW, LB, LH, LW, LD, LBU, LHU, LWU, JALR |
| S-type | SB, SH, SW, SD |
| B-type | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| U-type | LUI, AUIPC |
| J-type | JAL |
| System | CSR instructions, ECALL, MRET (via `OP_SYSTEM` opcode) |

---

## Project Structure

```
RWU_RV/RV_Pipeline/
├── src/
│   ├── as_pack.sv          # Package: types, enums, pipeline register structs  [MODIFIED]
│   ├── asCPUx.sv           # 5-stage pipeline CPU top-level                    [MODIFIED]
│   ├── asHazard.sv         # Hazard detection unit                             [NEW]
│   ├── asRegFile.sv        # Register file with write-first bypass             [MODIFIED]
│   ├── asInstrDecode.sv    # Instruction decoder / control unit
│   ├── asAlu.sv            # 64-bit integer ALU
│   ├── asAluBr.sv          # Branch comparator
│   ├── asIMem.sv           # Instruction memory
│   ├── asDecode.sv         # Address/chip-select decoder
│   ├── asTopMem.sv         # Data memory top wrapper
│   ├── asMBpi.sv           # Load data alignment
│   ├── asSBpi.sv           # Store data alignment
│   └── asControlAll.sv     # System control
├── tb/
│   ├── tb_pipeline.sv      # Pipeline testbench — 8 PASS/FAIL checks           [NEW]
│   └── tb_rv64i*.sv        # Original single-cycle testbenches
├── syn/
│   └── Zybo-Master.xdc     # Vivado constraints for Zybo Z7-10
├── vivado/                 # Vivado project files
└── rv64Sim/                # Simulation support files
```

---

## Simulation & Testing

The pipeline testbench (`tb/tb_pipeline.sv`) runs 8 instructions through the full pipeline and checks register and memory results with PASS/FAIL assertions.

**Test program:**

```asm
addi x1, x0, 5      # x1 = 5
addi x2, x0, 3      # x2 = 3
add  x3, x1, x2     # x3 = 8   (RAW hazard — stall inserted)
addi x4, x3, 1      # x4 = 9   (RAW hazard — stall inserted)
sw   x3, 0(x0)      # mem[0] = 8
lw   x5, 0(x0)      # x5 = 8   (load-use hazard — stall inserted)
addi x6, x5, 2      # x6 = 10
addi x7, x6, 5      # x7 = 15
```

**Simulation results:**

```
=== 5-Stage Pipeline RV64I Testbench ===
Testing: IF -> ID -> EX -> MEM -> WB
Hazard handling: Stall-only
PASS: x1 (addi x1,x0,5)    =  5  expected  5
PASS: x2 (addi x2,x0,3)    =  3  expected  3
PASS: x3 (add x3,x1,x2)    =  8  expected  8
PASS: x4 (addi x4,x3,1)    =  9  expected  9
PASS: x5 (lw x5,0(x0))     =  8  expected  8
PASS: x6 (addi x6,x5,2)    = 10  expected 10
PASS: x7 (addi x7,x6,5)    = 15  expected 15
PASS: mem[0] (sw x3,0(x0)) =  8  expected  8
PASSED: 8 / 8    FAILED: 0 / 8
ALL TESTS PASSED - PIPELINE WORKING CORRECTLY
```


---

## Tools & Target

| Item | Detail |
|------|--------|
| Language | SystemVerilog |
| Simulator | Vivado XSim |
| Synthesis | Vivado 2024.2 |
| Implementation | Vivado 2024.2 |
| Target Board | Zybo Z7-10 (xc7z010clg400-1) |
| Base Clock | 125 MHz (Zybo) |
| Core Clock Divider | 80 (approx. 1.5 MHz operating frequency) |
