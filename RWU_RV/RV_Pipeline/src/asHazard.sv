// asHazard.sv
`timescale 1ns/1ps

import as_pack::*;

module as_hazard (
  input  logic [4:0]  id_ex_rs1_addr_i,
  input  logic [4:0]  id_ex_rs2_addr_i,
  input  logic        id_ex_mem_rd_i,
  input  logic [4:0]  ex_mem_rd_addr_i,
  input  logic        ex_mem_mem_rd_i,
  input  logic [4:0]  if_id_rs1_addr_i,
  input  logic [4:0]  if_id_rs2_addr_i,
  output logic        stall_if_o,
  output logic        stall_id_o,
  output logic        flush_ex_o
);

  logic load_use_ex_s;
  logic load_use_mem_s;

  always_comb begin
    stall_if_o = 1'b0;
    stall_id_o = 1'b0;
    flush_ex_o = 1'b0;

    // Load-use hazard: EX stage is a load
    load_use_ex_s = id_ex_mem_rd_i &&
                    (id_ex_rs1_addr_i != 5'b0) &&
                    ((id_ex_rs1_addr_i == if_id_rs1_addr_i) ||
                     (id_ex_rs1_addr_i == if_id_rs2_addr_i));

    // Load-use hazard: MEM stage is a load (sync memory needs extra cycle)
    load_use_mem_s = ex_mem_mem_rd_i &&
                     (ex_mem_rd_addr_i != 5'b0) &&
                     ((ex_mem_rd_addr_i == if_id_rs1_addr_i) ||
                      (ex_mem_rd_addr_i == if_id_rs2_addr_i));

    if (load_use_ex_s || load_use_mem_s) begin
      stall_if_o = 1'b1;
      stall_id_o = 1'b1;
      flush_ex_o = 1'b1;
    end
  end

endmodule : as_hazard