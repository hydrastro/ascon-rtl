`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// ASCON internal 128-bit block to AXI4-Stream 128-bit egress adapter.
//
// This is the inverse of ascon_axis_ingress128.  It converts internal ASCON
// block order into AXI byte-stream order, generates tkeep from block_bytes_i,
// and forwards block_last_i to tlast.

`default_nettype none

module ascon_axis_egress128 (
  input  wire         clk,
  input  wire         rst_n,

  input  wire         clear_i,

  input  wire         block_valid_i,
  output wire         block_ready_o,
  input  wire [127:0] block_data_i,
  input  wire [4:0]   block_bytes_i,
  input  wire         block_last_i,

  output wire         m_axis_tvalid_o,
  input  wire         m_axis_tready_i,
  output wire [127:0] m_axis_tdata_o,
  output wire [15:0]  m_axis_tkeep_o,
  output wire         m_axis_tlast_o
);

  /* verilator lint_off UNUSED */
  wire unused_clk_w = clk;
  wire unused_rst_w = rst_n;
  /* verilator lint_on UNUSED */

  assign block_ready_o   = !clear_i && m_axis_tready_i;
  assign m_axis_tvalid_o = !clear_i && block_valid_i;
  assign m_axis_tlast_o  = block_last_i;

  function [15:0] keep_from_bytes;
    input [4:0] bytes;
    begin
      case (bytes)
        5'd0:  keep_from_bytes = 16'h0000;
        5'd1:  keep_from_bytes = 16'h0001;
        5'd2:  keep_from_bytes = 16'h0003;
        5'd3:  keep_from_bytes = 16'h0007;
        5'd4:  keep_from_bytes = 16'h000f;
        5'd5:  keep_from_bytes = 16'h001f;
        5'd6:  keep_from_bytes = 16'h003f;
        5'd7:  keep_from_bytes = 16'h007f;
        5'd8:  keep_from_bytes = 16'h00ff;
        5'd9:  keep_from_bytes = 16'h01ff;
        5'd10: keep_from_bytes = 16'h03ff;
        5'd11: keep_from_bytes = 16'h07ff;
        5'd12: keep_from_bytes = 16'h0fff;
        5'd13: keep_from_bytes = 16'h1fff;
        5'd14: keep_from_bytes = 16'h3fff;
        5'd15: keep_from_bytes = 16'h7fff;
        default: keep_from_bytes = 16'hffff;
      endcase
    end
  endfunction

  function [127:0] block_to_axis;
    input [127:0] block;
    begin
      block_to_axis[31:0]     = block[95:64];
      block_to_axis[63:32]    = block[127:96];
      block_to_axis[95:64]    = block[31:0];
      block_to_axis[127:96]   = block[63:32];
    end
  endfunction

  function [127:0] mask_tdata;
    input [127:0] data;
    input [15:0]  keep;
    integer i;
    begin
      mask_tdata = 128'd0;
      for (i = 0; i < 16; i = i + 1) begin
        if (keep[i]) begin
          mask_tdata[(8*i)+:8] = data[(8*i)+:8];
        end
      end
    end
  endfunction

  wire [15:0] keep_w = keep_from_bytes(block_bytes_i);

  assign m_axis_tkeep_o = keep_w;
  assign m_axis_tdata_o = mask_tdata(block_to_axis(block_data_i), keep_w);

endmodule

`default_nettype wire
