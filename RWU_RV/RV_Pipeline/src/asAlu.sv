
// asAlu.sv
`timescale 1ns/1ps

import as_pack::*;

module as_alu (input  logic [reg_width-1:0]      data01_i,
               input  logic [reg_width-1:0]      data02_i,
               input  alu_op_t                   alu_op_i,
               output logic [reg_width-1:0]      aluResult_o
              );

  logic [5:0] shamt64;
  logic [4:0] shamt32;
  logic [31:0] tmp_addw_s, tmp_subw_s, tmp_sllw_s, tmp_sraw_s;
  logic	       tmp_sign_addw_s, tmp_sign_subw_s, tmp_sign_sllw_s, tmp_sign_sraw_s;

  assign tmp_addw_s = data01_i[31:0] + data02_i[31:0];
  assign tmp_sign_addw_s = tmp_addw_s[31];
  assign tmp_subw_s = data01_i[31:0] - data02_i[31:0];
  assign tmp_sign_subw_s = tmp_subw_s[31];

  assign shamt64 = data02_i[5:0];
  assign shamt32 = data02_i[4:0];
  
  assign tmp_sllw_s = data01_i[31:0] << shamt32;
  assign tmp_sign_sllw_s = tmp_sllw_s[31];
  assign tmp_sraw_s = $signed(data01_i[31:0] >>> shamt32);
  assign tmp_sign_sraw_s = tmp_sraw_s[31];
  
  always_comb
  begin
    unique case (alu_op_i)
      ALU_ADD  : aluResult_o = data01_i + data02_i;
      ALU_SUB  : aluResult_o = data01_i - data02_i;

      ALU_AND  : aluResult_o = data01_i & data02_i;
      ALU_OR   : aluResult_o = data01_i | data02_i;
      ALU_XOR  : aluResult_o = data01_i ^ data02_i;

      ALU_SLT  : aluResult_o = {{(reg_width-1){1'b0}}, ($signed(data01_i) < $signed(data02_i))};
      ALU_SLTU : aluResult_o = {{(reg_width-1){1'b0}}, (data01_i < data02_i)};

      ALU_SLL  : aluResult_o = data01_i << shamt64;
      ALU_SRL  : aluResult_o = data01_i >> shamt64;
      ALU_SRA  : aluResult_o = $signed(data01_i) >>> shamt64;

      //ALU_ADDW : aluResult_o = {{32{(data01_i[31:0] + data02_i[31:0])[31]}}, (data01_i[31:0] + data02_i[31:0])};
      ALU_ADDW : aluResult_o = {{32{tmp_sign_addw_s}}, (data01_i[31:0] + data02_i[31:0])};
      //ALU_SUBW : aluResult_o = {{32{(data01_i[31:0] - data02_i[31:0])[31]}}, (data01_i[31:0] - data02_i[31:0])};
      ALU_SUBW : aluResult_o = {{32{tmp_sign_subw_s}}, (data01_i[31:0] - data02_i[31:0])};

      ALU_SLLW : aluResult_o = {{32{tmp_sign_sllw_s}}, (data01_i[31:0] << shamt32)};
      ALU_SRLW : aluResult_o = {{32{1'b0}}, (data01_i[31:0] >> shamt32)};
      //ALU_SRAW : aluResult_o = {{32{($signed(data01_i[31:0]) >>> shamt32)[31]}}, ($signed(data01_i[31:0]) >>> shamt32)};
      ALU_SRAW : aluResult_o = {{32{tmp_sign_sraw_s}}, ($signed(data01_i[31:0]) >>> shamt32)};
	
      default  : aluResult_o = {reg_width{1'b0}};
    endcase
  end

endmodule : as_alu

