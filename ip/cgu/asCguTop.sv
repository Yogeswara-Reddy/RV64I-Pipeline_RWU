
// asCguTop.sv
`timescale 1ns/1ps

import as_pack::*;

module as_cgu_top #(parameter cguaddr_width = 64)
              (input  logic clk_i, // external clock (Zybo: 125 MHz)
               input  logic rst_i,
               // wishbone side
               input  logic [cguaddr_width-1:0] wbdAddr_i, // 4 Bit (=> 16 register)
               input  logic [reg_width-1:0]   wbdDat_i,  // 64 Bit
               output logic [reg_width-1:0]   wbdDat_o,  // internal register
               input  logic                   wbdWe_i,   // write enable
               input  logic [wbdSel-1:0]      wbdSel_i,  // which byte is valid
               input  logic                   wbdStb_i,  // valid cycle
               output logic                   wbdAck_o,  // normal transaction
               input  logic                   wbdCyc_i,  // high for complete bus cycle
	       // I/O
	       output logic clk_bus1_o,
               output logic clk_bus2_o,
               output logic clk_qspi_o,
               output logic clk_core_o);

  // registers
  logic [reg_width-1:0]      id_reg_s;      // CGU peripheral ID-register;                    address=00

  logic                      en_s;
  logic [cguaddr_width-1:0]  addr_s;
  logic [reg_width-1:0]      data_s;    // data from bus/BPI to kernel
  logic [reg_width-1:0]      dataob_s;  // data from BPI to bus
  
  //--------------------------------------------
  // Slave BPI for the CGU
  //--------------------------------------------
  as_slave_bpi #(cguaddr_width, reg_width) 
                            sGpioBpi(.rst_i(rst_i),               // general reset
                                     .clk_i(clk_i),               // bus clock
                                     .addr_o(addr_s),             // address to CGU kernel
                                     .dat_from_core_i(dataob_s),  // data from CGU kernel
                                     .dat_to_core_o(data_s),      // data to CGU kernel
                                     .wr_o(en_s),                 // we to CGU kernel
                                     .rd_o(),                     // read enable not used in this context
                                     .wb_s_addr_i(wbdAddr_i),     // WB
                                     .wb_s_dat_i(wbdDat_i),       // WB
                                     .wb_s_dat_o(wbdDat_o),       // WB
                                     .wb_s_we_i(wbdWe_i),         // WB
                                     .wb_s_sel_i(wbdSel_i),       // WB
                                     .wb_s_stb_i(wbdStb_i),       // WB
                                     .wb_s_ack_o(wbdAck_o),       // WB
                                     .wb_s_cyc_i(wbdCyc_i)        // WB
                                    );

  
  //--------------------------------------------
  // CGU
  //--------------------------------------------
  as_cgucore CGUCore (.clk_i(clk_i),
                      .rst_i(rst_i),
                      .clk_bus1_o(clk_bus1_o),
                      .clk_bus2_o(clk_bus2_o),
                      .clk_qspi_o(clk_qspi_o),
                      .clk_core_o(clk_core_o)
                     );

  //--------------------------------------------
  // SFR: all other registers
  //--------------------------------------------
  // Peripheral ID: 64 bit, rw
  always_ff @(posedge clk_i, posedge rst_i)
  begin
    if(rst_i == 1)
      id_reg_s        <= cgu_id_reg_addr_rst_c;
    else
      if ( (en_s == 1) & (addr_s == cgu_id_reg_addr_offs_c[cguaddr_width-1:0]) )
        id_reg_s      <= data_s;
  end

  // read internal (BPI) register or data from core
  always_comb
  begin
    case(addr_s)
      cgu_id_reg_addr_offs_c[cguaddr_width-1:0]         : dataob_s = id_reg_s;
      default                                           : dataob_s = 0; // should not happen
    endcase
  end
  
endmodule : as_cgu_top


