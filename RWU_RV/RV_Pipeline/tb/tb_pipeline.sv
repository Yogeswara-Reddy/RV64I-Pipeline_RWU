// tb_pipeline.sv - 5-stage pipeline testbench with PASS/FAIL checks
`timescale 1ns/1ps

import as_pack::*;

module tb_pipeline;

  logic clk, rst;
  logic [63:0] iBusAddr;
  logic [31:0] iBusDataRd;
  logic [63:0] dBusAddr;
  logic [63:0] dBusDataWr;
  logic [63:0] dBusDataRd;
  logic        dBusWe;
  logic [31:0] ir_o;
  logic        dr_cap;
  logic        sc01_tdo, sc01_tdi, sc01_shift, sc01_clock;
  logic [7:0]  irq_ext;

  as_icache_if icpu_if(.clk_i(clk), .rst_i(rst));
  as_dcache_if dcpu_if(.clk_i(clk), .rst_i(rst));

  as_cpux dut (
    .clk_i(clk), .rst_i(rst), .tck_i(1'b0),
    .ir_o(ir_o), .dr_cap_i(dr_cap),
    .sc01_tdo_o(sc01_tdo), .sc01_tdi_i(sc01_tdi),
    .sc01_shift_i(sc01_shift), .sc01_clock_i(sc01_clock),
    .iBusAddr_o(iBusAddr), .iBusDataRd_i(iBusDataRd),
    .dBusAddr_o(dBusAddr), .dBusDataWr_o(dBusDataWr),
    .dBusDataRd_i(dBusDataRd), .dBusWe_o(dBusWe),
    .icpu_if(icpu_if), .dcpu_if(dcpu_if),
    .irq_ext_i(irq_ext)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  // Instruction memory
  // Test program:
  // addi x1, x0, 5    -> x1 = 5
  // addi x2, x0, 3    -> x2 = 3
  // add  x3, x1, x2   -> x3 = 8
  // addi x4, x3, 1    -> x4 = 9
  // sw   x3, 0(x0)    -> mem[0] = 8
  // lw   x5, 0(x0)    -> x5 = 8
  // addi x6, x5, 2    -> x6 = 10
  // addi x7, x6, 5    -> x7 = 15
  logic [31:0] imem [0:15];
  initial begin
    imem[0]  = 32'h00500093; // addi x1, x0, 5
    imem[1]  = 32'h00300113; // addi x2, x0, 3
    imem[2]  = 32'h002081B3; // add  x3, x1, x2
    imem[3]  = 32'h00118213; // addi x4, x3, 1
    imem[4]  = 32'h00302023; // sw   x3, 0(x0)
    imem[5]  = 32'h00002283; // lw   x5, 0(x0)
    imem[6]  = 32'h00228313; // addi x6, x5, 2
    imem[7]  = 32'h00530393; // addi x7, x6, 5
    imem[8]  = 32'h00000013; // nop
    imem[9]  = 32'h00000013; // nop
    imem[10] = 32'h00000013; // nop
    imem[11] = 32'h00000013; // nop
    imem[12] = 32'h00000013; // nop
    imem[13] = 32'h00000013; // nop
    imem[14] = 32'h00000013; // nop
    imem[15] = 32'h00000013; // nop
  end

  always_comb iBusDataRd = imem[iBusAddr[5:2]];

  // Data memory
  logic [63:0] dmem [0:15];
  initial foreach(dmem[i]) dmem[i] = '0;
  always_ff @(posedge clk)
    if (dBusWe) dmem[dBusAddr[6:3]] <= dBusDataWr;
  assign dBusDataRd = dmem[dBusAddr[6:3]];

  assign dr_cap     = 1'b0;
  assign sc01_tdi   = 1'b0;
  assign sc01_shift = 1'b0;
  assign sc01_clock = 1'b0;
  assign irq_ext    = 8'b0;

  // Pass/Fail tracking
  int pass_count = 0;
  int fail_count = 0;

  task check(input string name, input logic [63:0] got, input logic [63:0] expected);
    if (got == expected) begin
      $display("PASS: %s = %0d (expected %0d)", name, got, expected);
      pass_count++;
    end else begin
      $display("FAIL: %s = %0d (expected %0d) *** MISMATCH ***", name, got, expected);
      fail_count++;
    end
  endtask

  initial begin
    $display("=== 5-Stage Pipeline RV64I Testbench ===");
    $display("Testing: IF -> ID -> EX -> MEM -> WB");
    $display("Hazard handling: Stall-only");
    $display("=========================================");
    
    rst = 1;
    repeat(4) @(posedge clk);
    rst = 0;
    $display("Reset released at time %0t ns", $time/1000);
    $display("-----------------------------------------");

    // Run enough cycles for all 8 instructions + pipeline drain
    repeat(100) @(posedge clk);

    $display("-----------------------------------------");
    $display("=== Checking Register Results ===");
    
    // Check register file values via DUT
    check("x1 (addi x1,x0,5)",   dut.regfile.regfile_s[1],  64'd5);
    check("x2 (addi x2,x0,3)",   dut.regfile.regfile_s[2],  64'd3);
    check("x3 (add  x3,x1,x2)",  dut.regfile.regfile_s[3],  64'd8);
    check("x4 (addi x4,x3,1)",   dut.regfile.regfile_s[4],  64'd9);
    check("x5 (lw   x5,0(x0))",  dut.regfile.regfile_s[5],  64'd8);
    check("x6 (addi x6,x5,2)",   dut.regfile.regfile_s[6],  64'd10);
    check("x7 (addi x7,x6,5)",   dut.regfile.regfile_s[7],  64'd15);

    $display("-----------------------------------------");
    $display("=== Checking Memory Results ===");
    check("mem[0] (sw x3,0(x0))", dmem[0], 64'd8);

    $display("-----------------------------------------");
    $display("=== SUMMARY ===");
    $display("PASSED: %0d / %0d", pass_count, pass_count+fail_count);
    $display("FAILED: %0d / %0d", fail_count, pass_count+fail_count);
    
    if (fail_count == 0)
      $display("*** ALL TESTS PASSED - PIPELINE WORKING CORRECTLY ***");
    else
      $display("*** SOME TESTS FAILED - CHECK PIPELINE LOGIC ***");
    
    $display("=========================================");
    #100;
    $finish;
  end

endmodule : tb_pipeline