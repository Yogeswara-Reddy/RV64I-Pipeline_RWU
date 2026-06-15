
// ir_cell.sv
`timescale 1ns/1ps

import as_pack::*;

module ir_cell #(parameter bit IR_RST_VAL = 1'b0)  // reset value of this IR bit (must be constant)
               ( input logic  tck_i,      // Base clock
                 input logic  trst_i,     // TAPC reset
                 input logic  ir_shift_i, // For Mux: either shift tdi/tdo or capture data; Monitor only
                 input logic  ir_clock_i, // Clock the IR shift register (Latch?); Monitor only
                 input logic  ir_upd_i,   // Clock (activate) the IR hold register; Monitor only
                 input logic  data_i,     // Parallel data in
                 input logic  ser_i,      // Serial data in
                 output logic data_o,     // Parallel data out
                 output logic ser_o       // Serial data out
              );

  logic	inter_s;
  logic	data_out_s;
  logic	trst_s;
  
  // make reset invertible if needed (active high <-> active low)
  assign trst_s = trst_i;

  // Master FF
  always_ff @(posedge tck_i, posedge trst_s)
  begin
    if(trst_s == 1)
      inter_s <= 0;
    else 
      if(ir_clock_i == 1)
        if(ir_shift_i == 0)
          inter_s <= data_i; // parallel load
        else
          inter_s <= ser_i; // serial load
  end // always_ff @ (posedge tck_i, posedge trst_s)

  // Slave FF — async reset/preset to IR_RST_VAL (parameter constant → clean FDCE or FDPE, no set+reset conflict)
  always_ff @(posedge tck_i, posedge trst_s)
  begin
    if(trst_s == 1)
      data_out_s <= IR_RST_VAL;
    else
      if(ir_upd_i == 1)
        data_out_s <= inter_s;
  end // always_ff @ (posedge tck_i, posedge trst_s)

  // Assign outputs
  assign ser_o  = inter_s;
  assign data_o = data_out_s;

endmodule : ir_cell

