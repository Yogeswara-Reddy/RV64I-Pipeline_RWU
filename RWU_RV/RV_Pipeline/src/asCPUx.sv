// asCPUx.sv - 5-Stage Pipelined RV64I
`timescale 1ns/1ps

import as_pack::*;

module as_cpux (
  input  logic                          clk_i,
  input  logic                          rst_i,
  input  logic                          tck_i,
  output logic [instr_width-1:0]        ir_o,
  input  logic                          dr_cap_i,
  output logic                          sc01_tdo_o,
  input  logic                          sc01_tdi_i,
  input  logic                          sc01_shift_i,
  input  logic                          sc01_clock_i,
  // Instruction bus
  output logic [iaddr_width-1:0]        iBusAddr_o,
  input  logic [instr_width-1:0]        iBusDataRd_i,
  // Data bus
  output logic [daddr_width-1:0]        dBusAddr_o,
  output logic [reg_width-1:0]          dBusDataWr_o,
  input  logic [reg_width-1:0]          dBusDataRd_i,
  output logic                          dBusWe_o,
  // Cache interfaces
  as_icache_if.cpu                      icpu_if,
  as_dcache_if.cpu                      dcpu_if,
  // IRQ
  input logic [irq_total_num_ext_c-1:0] irq_ext_i
);

  localparam int XLEN = reg_width;

  //------------------------------------------
  // Pipeline Registers
  //------------------------------------------
  if_id_reg_t  if_id_r,  if_id_next_s;
  id_ex_reg_t  id_ex_r,  id_ex_next_s;
  ex_mem_reg_t ex_mem_r, ex_mem_next_s;
  mem_wb_reg_t mem_wb_r, mem_wb_next_s;

  //------------------------------------------
  // Hazard signals
  //------------------------------------------
  logic stall_if_s, stall_id_s, flush_ex_s;

  //------------------------------------------
  // IF Stage signals
  //------------------------------------------
  logic [iaddr_width-1:0] pc_r;
  logic [iaddr_width-1:0] pc_next_s;
  logic [iaddr_width-1:0] pc_plus4_s;
  logic [iaddr_width-1:0] pc_branch_s;
  logic                   take_s;
  logic                   branch_flush_s;

  //------------------------------------------
  // ID Stage signals
  //------------------------------------------
  logic [reg_width-1:0]  rs1_data_s, rs2_data_s;
  logic [reg_width-1:0]  imm_s;
  result_src_t           result_src_s;
  alu_op_t               alu_op_s;
  br_op_t                br_op_s;
  mux_a_t                alu_src_a_s;
  logic                  alu_src_b_s;
  logic                  reg_wr_s;
  logic                  mem_wr_s;
  logic                  mem_rd_s;
  logic                  jump_s;
  imm_src_t              imm_src_s;
  logic                  trap_illegal_s;

  //------------------------------------------
  // EX Stage signals
  //------------------------------------------
  logic [reg_width-1:0]  alu_src_a_mux_s;
  logic [reg_width-1:0]  alu_src_b_mux_s;
  logic [reg_width-1:0]  alu_result_s;
  logic [iaddr_width-1:0] pc_branch_ex_s;
  logic [iaddr_width-1:0] pc_or_rs1_s;

  //------------------------------------------
  // WB Stage signals
  //------------------------------------------
  logic [reg_width-1:0]  wb_result_s;
  logic                  wb_reg_wr_s;
  logic [4:0]            wb_rd_addr_s;

  //------------------------------------------
  // Scan chain (kept from original)
  //------------------------------------------
  logic gated_clk_s, clk_mux_s;
  logic and_in01_s, and_in02_s, and_out_s;
  logic sc01_01_s, sc01_02_s, sc01_03_s;

  //------------------------------------------
  // IR output (for D-Mem byte select)
  //------------------------------------------
  assign ir_o = if_id_r.instr;

  //==========================================
  // IF STAGE
  //==========================================
  assign pc_plus4_s   = pc_r + 64'd4;
  assign iBusAddr_o   = pc_r;

  // Branch target computed in EX stage
  assign branch_flush_s = take_s; // flush IF+ID on taken branch

  // PC next logic
  always_comb begin
    if (branch_flush_s)
      pc_next_s = pc_branch_ex_s;
    else if (stall_if_s)
      pc_next_s = pc_r;
    else
      pc_next_s = pc_plus4_s;
  end

  // PC register
  always_ff @(posedge clk_i, posedge rst_i) begin
    if (rst_i)
      pc_r <= 64'h0;
    else
      pc_r <= pc_next_s;
  end

  // IF/ID pipeline register
  always_ff @(posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
      if_id_r.pc    <= '0;
      if_id_r.instr <= 32'h00000013; // NOP
      if_id_r.valid <= 1'b0;
    end else if (branch_flush_s) begin
      if_id_r.pc    <= '0;
      if_id_r.instr <= 32'h00000013; // flush = NOP
      if_id_r.valid <= 1'b0;
    end else if (!stall_id_s) begin
      if_id_r.pc    <= pc_r;
      if_id_r.instr <= iBusDataRd_i;
      if_id_r.valid <= 1'b1;
    end
  end

  //==========================================
  // ID STAGE
  //==========================================

  // Register file read
  as_regfile regfile (
    .clk_i    (clk_i),
    .rst_i    (rst_i),
    .we_i     (wb_reg_wr_s),
    .raddr01_i(if_id_r.instr[19:15]),
    .raddr02_i(if_id_r.instr[24:20]),
    .waddr01_i(wb_rd_addr_s),
    .wdata01_i(wb_result_s),
    .rdata01_o(rs1_data_s),
    .rdata02_o(rs2_data_s)
  );

  // Instruction decode
  as_instr_decode control (
    .instr_opcode_i     (if_id_r.instr[6:0]),
    .instr_func3_i      (if_id_r.instr[14:12]),
    .instr_func7b5_i    (if_id_r.instr[30]),
    .take_i             (take_s),
    .mux_resultSrc_o    (result_src_s),
    .en_dMemWr_o        (mem_wr_s),
    .en_dMemRd_o        (mem_rd_s),
    .mux_aluSrcB_o      (alu_src_b_s),
    .mux_aluSrcA_o      (alu_src_a_s),
    .en_regWr_o         (reg_wr_s),
    .mux_jump_o         (jump_s),
    .sel_immSrc_o       (imm_src_s),
    .alu_op_o           (alu_op_s),
    .br_op_o            (br_op_s),
    .trap_illegal_instr_o(trap_illegal_s)
  );

  // Immediate generation
  always_comb
    case (imm_src_s)
      IMM_I   : imm_s = {{(XLEN-12){if_id_r.instr[31]}}, if_id_r.instr[31:20]};
      IMM_S   : imm_s = {{(XLEN-12){if_id_r.instr[31]}}, if_id_r.instr[31:25], if_id_r.instr[11:7]};
      IMM_B   : imm_s = {{(XLEN-12){if_id_r.instr[31]}}, if_id_r.instr[7], if_id_r.instr[30:25], if_id_r.instr[11:8], 1'b0};
      IMM_J   : imm_s = {{(XLEN-20){if_id_r.instr[31]}}, if_id_r.instr[19:12], if_id_r.instr[20], if_id_r.instr[30:21], 1'b0};
      IMM_U   : imm_s = {{(XLEN-32){if_id_r.instr[31]}}, if_id_r.instr[31:12], 12'b0};
      default : imm_s = '0;
    endcase

  // Hazard detection
 as_hazard hazard (
    .id_ex_rs1_addr_i (id_ex_r.rs1_addr),
    .id_ex_rs2_addr_i (id_ex_r.rs2_addr),
    .id_ex_mem_rd_i   (id_ex_r.mem_rd),
    .ex_mem_rd_addr_i (ex_mem_r.rd_addr),
    .ex_mem_mem_rd_i  (ex_mem_r.mem_rd),
    .if_id_rs1_addr_i (if_id_r.instr[19:15]),
    .if_id_rs2_addr_i (if_id_r.instr[24:20]),
    .stall_if_o       (stall_if_s),
    .stall_id_o       (stall_id_s),
    .flush_ex_o       (flush_ex_s)
  );

 // ID/EX pipeline register
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      id_ex_r <= '0;
    end else if (flush_ex_s || branch_flush_s) begin
      id_ex_r <= '0;
    end else begin
      id_ex_r.pc         <= if_id_r.pc;
      id_ex_r.rs1_data   <= rs1_data_s;
      id_ex_r.rs2_data   <= rs2_data_s;
      id_ex_r.imm        <= imm_s;
      id_ex_r.rs1_addr   <= if_id_r.instr[19:15];
      id_ex_r.rs2_addr   <= if_id_r.instr[24:20];
      id_ex_r.rd_addr    <= if_id_r.instr[11:7];
      id_ex_r.result_src <= result_src_s;
      id_ex_r.alu_op     <= alu_op_s;
      id_ex_r.br_op      <= br_op_s;
      id_ex_r.alu_src_a  <= alu_src_a_s;
      id_ex_r.alu_src_b  <= alu_src_b_s;
      id_ex_r.reg_wr     <= reg_wr_s;
      id_ex_r.mem_wr     <= mem_wr_s;
      id_ex_r.mem_rd     <= mem_rd_s;
      id_ex_r.jump       <= jump_s;
      id_ex_r.imm_src    <= imm_src_s;
      id_ex_r.valid      <= if_id_r.valid;
    end
  end

  //==========================================
  // EX STAGE
  //==========================================

  // ALU source A mux
  always_comb
    case (id_ex_r.alu_src_a)
      SRC_REGA : alu_src_a_mux_s = id_ex_r.rs1_data;
      SRC_PC   : alu_src_a_mux_s = id_ex_r.pc;
      SRC_ZERO : alu_src_a_mux_s = '0;
      default  : alu_src_a_mux_s = id_ex_r.rs1_data;
    endcase

  // ALU source B mux
  assign alu_src_b_mux_s = id_ex_r.alu_src_b ? id_ex_r.imm : id_ex_r.rs2_data;

  // ALU
  as_alu alua (
    .data01_i   (alu_src_a_mux_s),
    .data02_i   (alu_src_b_mux_s),
    .alu_op_i   (id_ex_r.alu_op),
    .aluResult_o(alu_result_s)
  );

  // Branch ALU
  as_alu_branch alub (
    .data01_i(id_ex_r.rs1_data),
    .data02_i(id_ex_r.rs2_data),
    .br_op_i (id_ex_r.br_op),
    .take_o  (take_s)
  );

  // Branch target address
  assign pc_or_rs1_s   = id_ex_r.jump ? id_ex_r.rs1_data : id_ex_r.pc;
  assign pc_branch_ex_s = pc_or_rs1_s + id_ex_r.imm;

  // EX/MEM pipeline register
  always_ff @(posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
      ex_mem_r <= '0;
    end else begin
      ex_mem_r.alu_result <= alu_result_s;
      ex_mem_r.rs2_data   <= id_ex_r.rs2_data;
      ex_mem_r.pc_plus4   <= id_ex_r.pc + 64'd4;
      ex_mem_r.rd_addr    <= id_ex_r.rd_addr;
      ex_mem_r.result_src <= id_ex_r.result_src;
      ex_mem_r.reg_wr     <= id_ex_r.reg_wr;
      ex_mem_r.mem_wr     <= id_ex_r.mem_wr;
      ex_mem_r.mem_rd     <= id_ex_r.mem_rd;
      ex_mem_r.valid      <= id_ex_r.valid;
    end
  end

  //==========================================
  // MEM STAGE
  //==========================================
  assign dBusAddr_o   = ex_mem_r.alu_result;
  assign dBusDataWr_o = ex_mem_r.rs2_data;
  assign dBusWe_o     = ex_mem_r.mem_wr & ex_mem_r.valid;

  // MEM/WB pipeline register
  always_ff @(posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
      mem_wb_r <= '0;
    end else begin
      mem_wb_r.alu_result <= ex_mem_r.alu_result;
      mem_wb_r.mem_data   <= dBusDataRd_i;
      mem_wb_r.pc_plus4   <= ex_mem_r.pc_plus4;
      mem_wb_r.rd_addr    <= ex_mem_r.rd_addr;
      mem_wb_r.result_src <= ex_mem_r.result_src;
      mem_wb_r.reg_wr     <= ex_mem_r.reg_wr;
      mem_wb_r.valid      <= ex_mem_r.valid;
    end
  end

  //==========================================
  // WB STAGE
  //==========================================
  assign wb_rd_addr_s = mem_wb_r.rd_addr;
  assign wb_reg_wr_s  = mem_wb_r.reg_wr & mem_wb_r.valid;

  always_comb
    case (mem_wb_r.result_src)
      RES_ALU : wb_result_s = mem_wb_r.alu_result;
      RES_MEM : wb_result_s = mem_wb_r.mem_data;
      RES_PC4 : wb_result_s = mem_wb_r.pc_plus4;
      default : wb_result_s = '0;
    endcase

  //==========================================
  // Cache interfaces - disabled
  //==========================================
  assign icpu_if.ic_addr  = '0;
  assign icpu_if.ic_req   = 1'b0;
  assign icpu_if.ic_flush = 1'b0;
  assign dcpu_if.dc_addr  = '0;
  assign dcpu_if.dc_req   = 1'b0;
  assign dcpu_if.dc_wr    = 1'b0;
  assign dcpu_if.dc_size  = '0;
  assign dcpu_if.dc_wdata = '0;
  assign dcpu_if.dc_wstrb = '0;
  assign dcpu_if.dc_flush = 1'b0;

  //==========================================
  // Scan Chain (kept from original)
  //==========================================
  assign clk_mux_s  = (sc01_shift_i == 1) ? tck_i : gated_clk_s;
  assign gated_clk_s = clk_i && dr_cap_i;

  scan_cell sc01 (clk_mux_s, rst_i, sc01_shift_i, 1'b0,      sc01_tdi_i,  and_in01_s, sc01_01_s);
  scan_cell sc02 (clk_mux_s, rst_i, sc01_shift_i, 1'b0,      sc01_01_s,   and_in02_s, sc01_02_s);
  assign and_out_s = and_in01_s & and_in02_s;
  scan_cell sc03 (clk_mux_s, rst_i, sc01_shift_i, and_out_s, sc01_02_s,   ,           sc01_03_s);
  scan_cell sc04 (clk_mux_s, rst_i, sc01_shift_i, 1'b0,      sc01_03_s,   ,           sc01_tdo_o);

endmodule : as_cpux