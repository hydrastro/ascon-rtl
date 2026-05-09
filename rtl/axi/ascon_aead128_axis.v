`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Phase 5.2 AXI4-Stream AEAD shell.
//
// This module wraps the verified buffered AEAD core with AXI4-Stream ingress
// and egress adapters.  It deliberately keeps job control as direct signals.
// AXI-Lite control/status registers are added in the next phase.
//
// Streams:
//   s_axis_ad_*    : associated-data input stream
//   s_axis_data_*  : plaintext input for encrypt, ciphertext input for decrypt
//   m_axis_data_*  : ciphertext output for encrypt, plaintext output for decrypt
//
// tdata byte order:
//   tdata[7:0]       = byte 0
//   tdata[15:8]      = byte 1
//   ...
//   tdata[127:120]   = byte 15
//
// tkeep:
//   Expected to be low-contiguous on input. Non-contiguous masks are reported
//   via *_keep_error_o.  The datapath still masks according to tkeep.
//
// Output tlast:
//   Generated from msg_bytes_i by counting output blocks.  The internal AEAD
//   core reports byte count but not last-block status, so this wrapper owns the
//   output-block counter.

`default_nettype none

module ascon_aead128_axis #(
  parameter integer DECRYPT             = 0,
  parameter integer ROUNDS_PER_CYCLE    = 1,
  parameter integer AD_FIFO_DEPTH_LOG2   = 2,
  parameter integer IN_FIFO_DEPTH_LOG2   = 2,
  parameter integer OUT_FIFO_DEPTH_LOG2  = 2
) (
  input  wire         clk,
  input  wire         rst_n,

  input  wire         clear_i,

  input  wire         start_i,
  output wire         start_ready_o,
  input  wire [127:0] key_i,
  input  wire [127:0] nonce_i,
  input  wire [31:0]  ad_bytes_i,
  input  wire [31:0]  msg_bytes_i,
  input  wire [127:0] tag_i,

  output wire         busy_o,
  output wire         done_o,

  input  wire         s_axis_ad_tvalid_i,
  output wire         s_axis_ad_tready_o,
  input  wire [127:0] s_axis_ad_tdata_i,
  input  wire [15:0]  s_axis_ad_tkeep_i,
  input  wire         s_axis_ad_tlast_i,
  output wire         s_axis_ad_keep_error_o,

  input  wire         s_axis_data_tvalid_i,
  output wire         s_axis_data_tready_o,
  input  wire [127:0] s_axis_data_tdata_i,
  input  wire [15:0]  s_axis_data_tkeep_i,
  input  wire         s_axis_data_tlast_i,
  output wire         s_axis_data_keep_error_o,

  output wire         m_axis_data_tvalid_o,
  input  wire         m_axis_data_tready_i,
  output wire [127:0] m_axis_data_tdata_o,
  output wire [15:0]  m_axis_data_tkeep_o,
  output wire         m_axis_data_tlast_o,

  output wire         result_valid_o,
  input  wire         result_ready_i,
  output wire [127:0] result_tag_o,
  output wire         result_auth_ok_o,

  output wire         ad_fifo_empty_o,
  output wire         ad_fifo_full_o,
  output wire [AD_FIFO_DEPTH_LOG2:0] ad_fifo_level_o,

  output wire         data_in_fifo_empty_o,
  output wire         data_in_fifo_full_o,
  output wire [IN_FIFO_DEPTH_LOG2:0] data_in_fifo_level_o,

  output wire         data_out_fifo_empty_o,
  output wire         data_out_fifo_full_o,
  output wire [OUT_FIFO_DEPTH_LOG2:0] data_out_fifo_level_o
);

  wire         ad_block_valid_w;
  wire         ad_block_ready_w;
  wire [127:0] ad_block_data_w;
  wire [4:0]   ad_block_bytes_w;
  wire         ad_block_last_w;

  wire         data_in_block_valid_w;
  wire         data_in_block_ready_w;
  wire [127:0] data_in_block_data_w;
  wire [4:0]   data_in_block_bytes_w;
  wire         data_in_block_last_w;

  wire         data_out_block_valid_w;
  wire         data_out_block_ready_w;
  wire [127:0] data_out_block_data_w;
  wire [4:0]   data_out_block_bytes_w;

  reg [31:0] out_blocks_left_q;

  function [31:0] block_count;
    input [31:0] bytes;
    begin
      block_count = (bytes + 32'd15) >> 4;
    end
  endfunction

  wire start_fire_w = start_i && start_ready_o;
  wire data_out_fire_w = data_out_block_valid_w && data_out_block_ready_w;
  wire data_out_last_w = (out_blocks_left_q == 32'd1);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_blocks_left_q <= 32'd0;
    end else if (clear_i) begin
      out_blocks_left_q <= 32'd0;
    end else if (start_fire_w) begin
      out_blocks_left_q <= block_count(msg_bytes_i);
    end else if (data_out_fire_w && (out_blocks_left_q != 32'd0)) begin
      out_blocks_left_q <= out_blocks_left_q - 32'd1;
    end
  end

  ascon_axis_ingress128 u_ad_axis_ingress (
    .clk              (clk),
    .rst_n            (rst_n),
    .clear_i          (clear_i),
    .s_axis_tvalid_i  (s_axis_ad_tvalid_i),
    .s_axis_tready_o  (s_axis_ad_tready_o),
    .s_axis_tdata_i   (s_axis_ad_tdata_i),
    .s_axis_tkeep_i   (s_axis_ad_tkeep_i),
    .s_axis_tlast_i   (s_axis_ad_tlast_i),
    .block_valid_o    (ad_block_valid_w),
    .block_ready_i    (ad_block_ready_w),
    .block_data_o     (ad_block_data_w),
    .block_bytes_o    (ad_block_bytes_w),
    .block_last_o     (ad_block_last_w),
    .keep_error_o     (s_axis_ad_keep_error_o)
  );

  ascon_axis_ingress128 u_data_axis_ingress (
    .clk              (clk),
    .rst_n            (rst_n),
    .clear_i          (clear_i),
    .s_axis_tvalid_i  (s_axis_data_tvalid_i),
    .s_axis_tready_o  (s_axis_data_tready_o),
    .s_axis_tdata_i   (s_axis_data_tdata_i),
    .s_axis_tkeep_i   (s_axis_data_tkeep_i),
    .s_axis_tlast_i   (s_axis_data_tlast_i),
    .block_valid_o    (data_in_block_valid_w),
    .block_ready_i    (data_in_block_ready_w),
    .block_data_o     (data_in_block_data_w),
    .block_bytes_o    (data_in_block_bytes_w),
    .block_last_o     (data_in_block_last_w),
    .keep_error_o     (s_axis_data_keep_error_o)
  );

  /* verilator lint_off UNUSED */
  wire [4:0] unused_ad_block_bytes_w = ad_block_bytes_w;
  wire       unused_ad_block_last_w  = ad_block_last_w;
  wire [4:0] unused_data_in_block_bytes_w = data_in_block_bytes_w;
  wire       unused_data_in_block_last_w  = data_in_block_last_w;
  /* verilator lint_on UNUSED */

  ascon_aead128_buffered #(
    .DECRYPT             (DECRYPT),
    .ROUNDS_PER_CYCLE    (ROUNDS_PER_CYCLE),
    .AD_FIFO_DEPTH_LOG2   (AD_FIFO_DEPTH_LOG2),
    .IN_FIFO_DEPTH_LOG2   (IN_FIFO_DEPTH_LOG2),
    .OUT_FIFO_DEPTH_LOG2  (OUT_FIFO_DEPTH_LOG2)
  ) u_core (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .clear_i                 (clear_i),
    .start_i                 (start_i),
    .start_ready_o           (start_ready_o),
    .key_i                   (key_i),
    .nonce_i                 (nonce_i),
    .ad_bytes_i              (ad_bytes_i),
    .msg_bytes_i             (msg_bytes_i),
    .tag_i                   (tag_i),
    .busy_o                  (busy_o),
    .done_o                  (done_o),
    .ad_in_valid_i           (ad_block_valid_w),
    .ad_in_ready_o           (ad_block_ready_w),
    .ad_in_block_i           (ad_block_data_w),
    .data_in_valid_i         (data_in_block_valid_w),
    .data_in_ready_o         (data_in_block_ready_w),
    .data_in_block_i         (data_in_block_data_w),
    .data_out_valid_o        (data_out_block_valid_w),
    .data_out_ready_i        (data_out_block_ready_w),
    .data_out_block_o        (data_out_block_data_w),
    .data_out_bytes_o        (data_out_block_bytes_w),
    .result_valid_o          (result_valid_o),
    .result_ready_i          (result_ready_i),
    .result_tag_o            (result_tag_o),
    .result_auth_ok_o        (result_auth_ok_o),
    .ad_fifo_empty_o         (ad_fifo_empty_o),
    .ad_fifo_full_o          (ad_fifo_full_o),
    .ad_fifo_level_o         (ad_fifo_level_o),
    .data_in_fifo_empty_o    (data_in_fifo_empty_o),
    .data_in_fifo_full_o     (data_in_fifo_full_o),
    .data_in_fifo_level_o    (data_in_fifo_level_o),
    .data_out_fifo_empty_o   (data_out_fifo_empty_o),
    .data_out_fifo_full_o    (data_out_fifo_full_o),
    .data_out_fifo_level_o   (data_out_fifo_level_o)
  );

  ascon_axis_egress128 u_data_axis_egress (
    .clk              (clk),
    .rst_n            (rst_n),
    .clear_i          (clear_i),
    .block_valid_i    (data_out_block_valid_w),
    .block_ready_o    (data_out_block_ready_w),
    .block_data_i     (data_out_block_data_w),
    .block_bytes_i    (data_out_block_bytes_w),
    .block_last_i     (data_out_last_w),
    .m_axis_tvalid_o  (m_axis_data_tvalid_o),
    .m_axis_tready_i  (m_axis_data_tready_i),
    .m_axis_tdata_o   (m_axis_data_tdata_o),
    .m_axis_tkeep_o   (m_axis_data_tkeep_o),
    .m_axis_tlast_o   (m_axis_data_tlast_o)
  );

endmodule

`default_nettype wire
