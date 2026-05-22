
// asAluBr.sv
`timescale 1ns/1ps

import as_pack::*;

module as_alu_branch (input  logic [63:0] data01_i,
                      input  logic [63:0] data02_i,
                      input  br_op_t      br_op_i,
                      output logic        take_o
                     );

  always_comb begin
    unique case (br_op_i)
      BR_EQ  : take_o = (data01_i == data02_i);
      BR_NE  : take_o = (data01_i != data02_i);
      BR_LT  : take_o = ($signed(data01_i) <  $signed(data02_i));
      BR_GE  : take_o = ($signed(data01_i) >= $signed(data02_i));
      BR_LTU : take_o = (data01_i <  data02_i);
      BR_GEU : take_o = (data01_i >= data02_i);
      default: take_o = 1'b0;
    endcase
  end

endmodule : as_alu_branch

