# RV64I 5-Stage Pipelined CPU

A 5-stage pipelined RISC-V RV64I CPU implementation in SystemVerilog, based on the RWU RV64I single-cycle design by asiggel.

## Pipeline Stages

| Stage | Name | Description | Pipeline Register |
|---|---|---|---|
| 1 | IF | Instruction Fetch — reads instruction from memory using PC | `if_id_r` |
| 2 | ID | Instruction Decode + Register Read | `id_ex_r` |
| 3 | EX | Execute — ALU operations + Branch resolution | `ex_mem_r` |
| 4 | MEM | Memory Access — Load/Store operations | `mem_wb_r` |
| 5 | WB | Write Back — result written to register file | — |

## Hazard Handling

Stall-only approach (no forwarding unit):
- Detects load-use data hazards
- Freezes IF and ID pipeline stages
- Inserts NOP bubble into EX stage
- Handles branch flushes

## New Files Added

| File | Description |
|---|---|
| `src/asHazard.sv` | Hazard detection unit |
| `tb/tb_pipeline.sv` | Pipeline testbench with 8 test cases |

## Modified Files

| File | Changes |
|---|---|
| `src/as_pack.sv` | Added pipeline register structs: if_id_reg_t, id_ex_reg_t, ex_mem_reg_t, mem_wb_reg_t |
| `src/asCPUx.sv` | Completely rewritten with 5 pipeline stages + hazard unit instantiation |
| `src/asRegFile.sv` | Added write-first bypass logic for WB-to-ID forwarding |

## Simulation Results

=== 5-Stage Pipeline RV64I Testbench ===
Testing: IF -> ID -> EX -> MEM -> WB
Hazard handling: Stall-only
PASS: x1 (addi x1,x0,5)   = 5   expected 5
PASS: x2 (addi x2,x0,3)   = 3   expected 3
PASS: x3 (add  x3,x1,x2)  = 8   expected 8
PASS: x4 (addi x4,x3,1)   = 9   expected 9
PASS: x5 (lw   x5,0(x0))  = 8   expected 8
PASS: x6 (addi x6,x5,2)   = 10  expected 10
PASS: x7 (addi x7,x6,5)   = 15  expected 15
PASS: mem[0] (sw x3,0(x0)) = 8  expected 8
PASSED: 8 / 8
FAILED: 0 / 8
ALL TESTS PASSED - PIPELINE WORKING CORRECTLY

## Synthesis and Implementation Results (Zybo Z7-10)

| Resource | Used | Available | Utilization |
|---|---|---|---|
| Slice LUTs | 4050 | 17600 | 23% |
| Slice Registers | 3526 | 35200 | 10% |
| Block RAM Tiles | 10 | 60 | 17% |
| Bonded IOB | 16 | 100 | 16% |

### Pipeline CPU (as_cpux) Resource Usage

| Resource | Count |
|---|---|
| Slice LUTs | 3725 |
| Slice Registers | 2894 |
| F7 Muxes | 516 |
| F8 Muxes | 256 |

## Tools

| Tool | Version |
|---|---|
| Language | SystemVerilog |
| Simulator | Vivado XSim |
| Synthesis | Vivado 2024.2 |
| Implementation | Vivado 2024.2 |
| Target Board | Zybo Z7-10 (xc7z010clg400-1) |

## Project Structure

RWU_RV/RV_Pipeline/
├── src/
│   ├── as_pack.sv         Modified - pipeline register structs added
│   ├── asCPUx.sv          Modified - 5-stage pipeline implementation
│   ├── asHazard.sv        NEW - hazard detection unit
│   ├── asRegFile.sv       Modified - write-first bypass logic
│   ├── asAlu.sv           Unchanged
│   ├── asAluBr.sv         Unchanged
│   ├── asInstrDecode.sv   Unchanged
│   └── asIMem.sv          Unchanged
├── tb/
│   └── tb_pipeline.sv     NEW - pipeline testbench
└── syn/
└── Zybo-Master.xdc    Constraints file



