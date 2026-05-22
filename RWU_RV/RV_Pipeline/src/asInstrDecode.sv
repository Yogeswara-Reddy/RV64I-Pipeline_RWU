
// asInstrDecode.sv
`timescale 1ns/1ps

import as_pack::*;

module as_instr_decode (input logic [opcode_width-1:0]    instr_opcode_i,       // opcode field
                        input logic [func3_width-1:0]     instr_func3_i,        // func3 field
                        input logic                       instr_func7b5_i,      // bit 5 of func7 field
                        input logic                       take_i,               // branch taken
                        output result_src_t               mux_resultSrc_o,      // Mux behind DMem
                        output logic                      en_dMemWr_o,          // D-Mem write enable
                        output logic                      en_dMemRd_o,          // D-Mem read enable; almost not needed anymore
                        output logic                      mux_aluSrcB_o,        // Mux in front of ALU
                        output mux_a_t                    mux_aluSrcA_o,        // Mux in front of ALU
                        output logic                      en_regWr_o,           // Register file write enable
                        output logic                      mux_jump_o,           // Src for branch target mux: register or PC as input for branch target adder
                        output imm_src_t                  sel_immSrc_o,         // Selects, how the immediate value will be generated
                        output alu_op_t                   alu_op_o,             // Selects the operation in algorithmic ALU
                        output br_op_t                    br_op_o,              // Selects the operation in branch ALU
                        output logic                      trap_illegal_instr_o
                     );

  always_comb 
  begin
    // ---------- defaults ----------
    alu_op_o        = ALU_ADD;
    br_op_o         = BR_NONE;

    en_regWr_o      = 1'b0;
    en_dMemWr_o     = 1'b0;
    en_dMemRd_o     = 1'b0;

    mux_aluSrcA_o   = SRC_REGA;
    mux_aluSrcB_o   = 1'b0;
    mux_jump_o      = 1'b0;
    sel_immSrc_o    = IMM_NONE;
    mux_resultSrc_o = RES_ALU;

    trap_illegal_instr_o = 1'b0;

    case (instr_opcode_i)
      // ---------------- I-TYPE ----------------
      OP_LOAD: begin
                 en_regWr_o      = 1'b1;
                 en_dMemRd_o     = 1'b1;
                 mux_aluSrcB_o   = 1'b1;
                 sel_immSrc_o    = IMM_I;
                 mux_resultSrc_o = RES_MEM;
                 alu_op_o        = ALU_ADD; // Adresse = rs1 + imm
               end

      // ---------------- I-TYPE ----------------
      OP_OP_IMM: begin
                   en_regWr_o    = 1'b1;
                   mux_aluSrcB_o = 1'b1;
                   sel_immSrc_o  = IMM_I;
                   case (instr_func3_i)
                     3'b000: alu_op_o = ALU_ADD;
                     3'b111: alu_op_o = ALU_AND;
                     3'b110: alu_op_o = ALU_OR;
                     3'b100: alu_op_o = ALU_XOR;
                     3'b010: alu_op_o = ALU_SLT;
                     3'b011: alu_op_o = ALU_SLTU;
                     3'b001: alu_op_o = ALU_SLL;
                     3'b101: alu_op_o = instr_func7b5_i ? ALU_SRA : ALU_SRL;
                     default: trap_illegal_instr_o = 1'b1;
                   endcase
                 end

      // ---------------- U-TYPE ----------------
      OP_AUIPC: begin
                  en_regWr_o      = 1'b1;
                  sel_immSrc_o    = IMM_U;
                  mux_aluSrcA_o   = SRC_PC;  // PC
                  mux_aluSrcB_o   = 1'b1;  // imm
                  alu_op_o        = ALU_ADD;
                end

      // ---------------- I-TYPE ----------------
      OP_OP_IMMW: begin
                    en_regWr_o    = 1'b1;
                    mux_aluSrcB_o = 1'b1;
                    sel_immSrc_o  = IMM_I;
                    case (instr_func3_i)
                      3'b000: alu_op_o = ALU_ADDW;
                      3'b001: alu_op_o = ALU_SLLW;
                      3'b101: alu_op_o = instr_func7b5_i ? ALU_SRAW : ALU_SRLW;
                      default: trap_illegal_instr_o = 1'b1;
                    endcase
                  end

      // ---------------- S-TYPE ----------------
      OP_STORE: begin
                  en_dMemWr_o   = 1'b1;
                  mux_aluSrcB_o = 1'b1;
                  sel_immSrc_o  = IMM_S;
                  alu_op_o      = ALU_ADD;
                end
      
      // ---------------- R-TYPE ----------------
      OP_OP : begin
                en_regWr_o    = 1'b1;
                mux_aluSrcA_o = SRC_REGA;
                mux_aluSrcB_o = 1'b0;
                case (instr_func3_i)
                  3'b000: alu_op_o = instr_func7b5_i ? ALU_SUB : ALU_ADD;
                  3'b111: alu_op_o = ALU_AND;
                  3'b110: alu_op_o = ALU_OR;
                  3'b100: alu_op_o = ALU_XOR;
                  3'b010: alu_op_o = ALU_SLT;
                  3'b011: alu_op_o = ALU_SLTU;
                  3'b001: alu_op_o = ALU_SLL;
                  3'b101: alu_op_o = instr_func7b5_i ? ALU_SRA : ALU_SRL;
                  default: trap_illegal_instr_o = 1'b1;
                endcase
              end

      // ---------------- U-TYPE ----------------
      OP_LUI: begin
                en_regWr_o      = 1'b1;
                sel_immSrc_o    = IMM_U;
                mux_resultSrc_o = RES_ALU;
                alu_op_o        = ALU_ADD;   // ALU: 0 + imm
                mux_aluSrcB_o   = 1'b1;
                mux_aluSrcA_o   = SRC_ZERO; // reg = 0 + imm
              end

      // ---------------- R-TYPE W ----------------
      OP_OPW: begin
                en_regWr_o = 1'b1;
                case (instr_func3_i)
                  3'b000: alu_op_o = instr_func7b5_i ? ALU_SUBW : ALU_ADDW;
                  3'b001: alu_op_o = ALU_SLLW;
                  3'b101: alu_op_o = instr_func7b5_i ? ALU_SRAW : ALU_SRLW;
                  default: trap_illegal_instr_o = 1'b1;
                endcase
              end

      // ---------------- BRANCH ----------------
      OP_BRANCH: begin
                   sel_immSrc_o = IMM_B;
                   case (instr_func3_i)
                     3'b000: br_op_o = BR_EQ;
                     3'b001: br_op_o = BR_NE;
                     3'b100: br_op_o = BR_LT;
                     3'b101: br_op_o = BR_GE;
                     3'b110: br_op_o = BR_LTU;
                     3'b111: br_op_o = BR_GEU;
                     default: trap_illegal_instr_o = 1'b1;
                   endcase
                 end

      // ---------------- JALR ----------------
      OP_JALR: begin
                 en_regWr_o      = 1'b1;
                 sel_immSrc_o    = IMM_I;
                 mux_jump_o      = 1'b1;
                 mux_resultSrc_o = RES_PC4;
               end

      // ---------------- JAL ----------------
      OP_JAL: begin
                en_regWr_o      = 1'b1;
                sel_immSrc_o    = IMM_J;
                mux_resultSrc_o = RES_PC4;
              end

      // ---------------- SYSTEM ----------------
      OP_SYSTEM: begin
                   mux_resultSrc_o = RES_CSR;
                 end

      default: begin
                 // illegal instruction
                 trap_illegal_instr_o = 1'b1;
               end

    endcase
  end

endmodule : as_instr_decode

