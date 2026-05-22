
// asMBpi.sv - Wishbone Classic Compliant Master BPI
// Simple single read/write transfers, no extra clock cycles
// Spec: Wishbone B4 Classic

`timescale 1ns/1ps

import as_pack::*;

//-----------------------------------------------
// Wishbone master BPI
// - Call: as_master_bpi #(64,64) myBpi ( all ports );
// - First implementation: without any sync-cells -> no delayx
//-----------------------------------------------
module as_master_bpi #( parameter addr_width = 64,
                        parameter data_width = 64)
                      ( input                         rst_i,
                        input                         clk_i,
                        // master side
                        input  logic [addr_width-1:0] addr_i,
                        input  logic [data_width-1:0] dat_from_core_i,
                        output logic [data_width-1:0] dat_to_core_o,
                        input  logic                  wr_i,
                        // wishbone side
                        output logic [addr_width-1:0] wb_m_addr_o,
                        input  logic [data_width-1:0] wb_m_dat_i,
                        output logic [data_width-1:0] wb_m_dat_o,
                        output logic                  wb_m_we_o,
                        output logic [wbdSel-1:0]     wb_m_sel_o, // which byte is valid
                        output logic                  wb_m_stb_o, // valid cycle
                        input  logic                  wb_m_ack_i, // normal transaction
                        output logic                  wb_m_cyc_o  // high for complete bus cycle
                      );

  //===========================================
  // Wishbone Classic Protocol Implementation
  //===========================================
  
  // Address and data are directly driven (combinatorial)
  assign wb_m_addr_o = addr_i;
  assign wb_m_dat_o  = dat_from_core_i;
  assign wb_m_we_o   = wr_i;
  
  // SEL: All bytes valid (full data width transfer)
  assign wb_m_sel_o = '1;
  
  // STB and CYC are always asserted (continuous operation)
  // For simple synchronous memories, this creates zero wait-state transfers
  assign wb_m_stb_o = 1'b1;
  assign wb_m_cyc_o = 1'b1;
  
  // Read data directly from slave
  assign dat_to_core_o = wb_m_dat_i;
  
  //===========================================
  // Timing Explanation
  //===========================================
  /* 
   * Wishbone Classic Single Read/Write Cycle:
   * 
   * Clock:    __|‾‾|__|‾‾|__|‾‾|__
   *           
   * CYC_O:    ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
   * STB_O:    ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
   * ADR_O:    ===< A1 >====< A2 >====
   * DAT_O:    ===< D1 >====< D2 >====  (write)
   * WE_O:     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
   * SEL_O:    ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
   * 
   * ACK_I:    ____‾‾‾‾____‾‾‾‾____   (from slave)
   * DAT_I:    ========< RD1 >< RD2 >  (read)
   * 
   * Single-cycle transfers:
   * - Master drives ADR/DAT/WE/SEL continuously
   * - Slave responds with ACK and DAT_I in same cycle
   * - New transfer can start next cycle
   */

endmodule : as_master_bpi

