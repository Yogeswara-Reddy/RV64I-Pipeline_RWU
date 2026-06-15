
//asDMemTop.sv
`timescale 1ns/1ps

import as_pack::*;

module as_dmem_top #(parameter dmemaddr_width = 64)
              (input  logic clk_i,
               input  logic rst_i,
               // wishbone side
               input  logic [dmemaddr_width-1:0] wbdAddr_i,
               input  logic [reg_width-1:0]      wbdDat_i,  // 64 Bit
               output logic [reg_width-1:0]      wbdDat_o,  // internal register
               input  logic                      wbdWe_i,   // write enable
               input  logic [wbdSel-1:0]         wbdSel_i,  // which byte is valid
               input  logic                      wbdStb_i,  // valid cycle
               output logic                      wbdAck_o,  // normal transaction
               input  logic                      wbdCyc_i,  // high for complete bus cycle
	       // logic
	       input  logic [6:0] opcode_i,
	       input  logic [2:0] func3_i
	      );
  
  //logic	wbdstDMem_s;
  logic	wdbAckDmem_s;
  logic [dmemaddr_width-1:0]  adr_bpi_2_dmem_s;
  logic [reg_width-1:0]       dat_dmem_2_bpi_s;
  logic [reg_width-1:0]       dat_bpi_2_dmem_s;
  logic	wr_bpi_2_dmem_s;

  logic rd_dmem_s, rd_s;
  
  assign rd_dmem_s = ~wbdWe_i;
  
  as_slave_bpi #(dmemaddr_width, reg_width ) 
                            sDmemBpi(.rst_i(rst_i),
                                     .clk_i(clk_i),
                                     .addr_o(adr_bpi_2_dmem_s),
                                     .dat_from_core_i(dat_dmem_2_bpi_s),
                                     .dat_to_core_o(dat_bpi_2_dmem_s),
                                     .wr_o(wr_bpi_2_dmem_s),
                                     .rd_o(rd_s),
                                     .wb_s_addr_i(wbdAddr_i),
                                     .wb_s_dat_i(wbdDat_i),
                                     .wb_s_dat_o(wbdDat_o),
                                     .wb_s_we_i(wbdWe_i),
                                     .wb_s_sel_i(wbdSel_i),
                                     .wb_s_stb_i(wbdStb_i),
                                     .wb_s_ack_o(wbdAck_o),
                                     .wb_s_cyc_i(wbdCyc_i)
                                    );
  
  as_dmem dmem (.clk_i(clk_i),
                .addr_i(adr_bpi_2_dmem_s),     // from BPI
                .wrEn_i(wr_bpi_2_dmem_s),      // from BPI
                .rdEn_i(rd_dmem_s),            // from master
                .opcode_i(opcode_i),           // from master
                .func3_i(func3_i),             // from master
                .data_i(dat_bpi_2_dmem_s),     // from BPI
                .data_o(dat_dmem_2_bpi_s)      // to BPI
               );

  
endmodule : as_dmem_top


