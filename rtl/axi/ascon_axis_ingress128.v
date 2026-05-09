`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// AXI4-Stream 128-bit ingress adapter for the ASCON core.
//
// This module converts one AXI4-Stream beat into one internal ASCON 128-bit
// block.  It is intentionally thin: no FIFO, no packet scheduler, no AXI-Lite
// control.  Backpressure is direct.
//
// AXI byte order:
//   s_axis_tdata_i[7:0]     = byte 0
//   s_axis_tdata_i[15:8]    = byte 1
//   ...
//   s_axis_tdata_i[127:120] = byte 15
//
// Internal ASCON block order follows the existing project convention:
//   block[127:64] = first  8 bytes loaded little-endian into ASCON word 0
//   block[63:0]   = second 8 bytes loaded little-endian into ASCON word 1
//
// This is the same byte-stream order used by ascon_block_packer32:
//   bytes 0..3   -> block[95:64]
//   bytes 4..7   -> block[127:96]
//   bytes 8..11  -> block[31:0]
//   bytes 12..15 -> block[63:32]
//
// tkeep is expected to be contiguous from bit 0 upward.  keep_error_o flags
// non-contiguous masks for wrapper/testbench policy, but the data path still
// masks bytes according to tkeep.

`default_nettype none

module ascon_axis_ingress128 (
  input  wire         clk,
  input  wire         rst_n,

  input  wire         clear_i,

  input  wire         s_axis_tvalid_i,
  output wire         s_axis_tready_o,
  input  wire [127:0] s_axis_tdata_i,
  input  wire [15:0]  s_axis_tkeep_i,
  input  wire         s_axis_tlast_i,

  output wire         block_valid_o,
  input  wire         block_ready_i,
  output wire [127:0] block_data_o,
  output wire [4:0]   block_bytes_o,
  output wire         block_last_o,
  output wire         keep_error_o
);

  // clk/rst are present to keep the adapter interface consistent with future
  // buffered/registered variants.  This phase is purely combinational.
  /* verilator lint_off UNUSED */
  wire unused_clk_w = clk;
  wire unused_rst_w = rst_n;
  /* verilator lint_on UNUSED */

  assign s_axis_tready_o = !clear_i && block_ready_i;
  assign block_valid_o   = !clear_i && s_axis_tvalid_i;
  assign block_last_o    = s_axis_tlast_i;

  function [4:0] count_keep;
    input [15:0] keep;
    integer i;
    begin
      count_keep = 5'd0;
      for (i = 0; i < 16; i = i + 1) begin
        count_keep = count_keep + {4'd0, keep[i]};
      end
    end
  endfunction

  function is_low_contiguous;
    input [15:0] keep;
    integer i;
    reg seen_zero;
    begin
      seen_zero = 1'b0;
      is_low_contiguous = 1'b1;
      for (i = 0; i < 16; i = i + 1) begin
        if (!keep[i]) begin
          seen_zero = 1'b1;
        end else if (seen_zero) begin
          is_low_contiguous = 1'b0;
        end
      end
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

  function [127:0] axis_to_block;
    input [127:0] axis_data;
    reg [127:0] m;
    begin
      m = axis_data;
      axis_to_block[95:64]    = m[31:0];
      axis_to_block[127:96]   = m[63:32];
      axis_to_block[31:0]     = m[95:64];
      axis_to_block[63:32]    = m[127:96];
    end
  endfunction

  wire [127:0] masked_data_w = mask_tdata(s_axis_tdata_i, s_axis_tkeep_i);

  assign block_data_o  = axis_to_block(masked_data_w);
  assign block_bytes_o = count_keep(s_axis_tkeep_i);
  assign keep_error_o  = s_axis_tvalid_i && !is_low_contiguous(s_axis_tkeep_i);

endmodule

`default_nettype wire
