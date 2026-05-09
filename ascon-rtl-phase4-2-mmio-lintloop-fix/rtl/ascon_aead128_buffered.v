`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Phase 3.4 unified buffered Ascon-AEAD128 job-level shell.
//
// This module is the stable stream/job boundary for future platform wrappers
// (NEORV32, XBUS, SLINK, AXI, Tiny Tapeout).  It deliberately selects
// encryption or decryption at elaboration time with DECRYPT, instead of taking
// a runtime op bit, so synthesis instantiates only one datapath.
//
// DECRYPT=0:
//   data_in_*  = plaintext blocks
//   data_out_* = ciphertext blocks
//   result_*   = generated tag, auth_ok_o is always 1 when result fires
//
// DECRYPT=1:
//   data_in_*  = ciphertext blocks
//   tag_i      = expected authentication tag
//   data_out_* = tentative plaintext blocks
//   result_*   = authentication verdict; result_tag_o is zero
//
// The interface is internal 128-bit Ascon block order.  CPU/bus byte packing
// belongs in later platform wrappers.

`default_nettype none

module ascon_aead128_buffered #(
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

  input  wire         ad_in_valid_i,
  output wire         ad_in_ready_o,
  input  wire [127:0] ad_in_block_i,

  input  wire         data_in_valid_i,
  output wire         data_in_ready_o,
  input  wire [127:0] data_in_block_i,

  output wire         data_out_valid_o,
  input  wire         data_out_ready_i,
  output wire [127:0] data_out_block_o,
  output wire [4:0]   data_out_bytes_o,

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

  generate
    if (DECRYPT == 0) begin : g_encrypt
      wire [127:0] tag_w;

      // tag_i is meaningful only for decryption jobs.
      /* verilator lint_off UNUSED */
      wire [127:0] unused_tag_i_w = tag_i;
      /* verilator lint_on UNUSED */

      assign result_tag_o     = tag_w;
      assign result_auth_ok_o = 1'b1;

      ascon_aead128_enc_ad_buffered #(
        .ROUNDS_PER_CYCLE   (ROUNDS_PER_CYCLE),
        .AD_FIFO_DEPTH_LOG2  (AD_FIFO_DEPTH_LOG2),
        .PT_FIFO_DEPTH_LOG2  (IN_FIFO_DEPTH_LOG2),
        .CT_FIFO_DEPTH_LOG2  (OUT_FIFO_DEPTH_LOG2)
      ) u_enc (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .clear_i                  (clear_i),
        .start_i                  (start_i),
        .start_ready_o            (start_ready_o),
        .key_i                    (key_i),
        .nonce_i                  (nonce_i),
        .ad_bytes_i               (ad_bytes_i),
        .msg_bytes_i              (msg_bytes_i),
        .busy_o                   (busy_o),
        .done_o                   (done_o),
        .ad_in_valid_i            (ad_in_valid_i),
        .ad_in_ready_o            (ad_in_ready_o),
        .ad_in_block_i            (ad_in_block_i),
        .plaintext_in_valid_i     (data_in_valid_i),
        .plaintext_in_ready_o     (data_in_ready_o),
        .plaintext_in_block_i     (data_in_block_i),
        .ciphertext_out_valid_o   (data_out_valid_o),
        .ciphertext_out_ready_i   (data_out_ready_i),
        .ciphertext_out_block_o   (data_out_block_o),
        .ciphertext_out_bytes_o   (data_out_bytes_o),
        .tag_out_valid_o          (result_valid_o),
        .tag_out_ready_i          (result_ready_i),
        .tag_out_o                (tag_w),
        .ad_fifo_empty_o          (ad_fifo_empty_o),
        .ad_fifo_full_o           (ad_fifo_full_o),
        .ad_fifo_level_o          (ad_fifo_level_o),
        .plaintext_fifo_empty_o   (data_in_fifo_empty_o),
        .plaintext_fifo_full_o    (data_in_fifo_full_o),
        .plaintext_fifo_level_o   (data_in_fifo_level_o),
        .ciphertext_fifo_empty_o  (data_out_fifo_empty_o),
        .ciphertext_fifo_full_o   (data_out_fifo_full_o),
        .ciphertext_fifo_level_o  (data_out_fifo_level_o)
      );
    end else begin : g_decrypt
      wire auth_ok_w;

      assign result_tag_o     = 128'd0;
      assign result_auth_ok_o = auth_ok_w;

      ascon_aead128_dec_ad_buffered #(
        .ROUNDS_PER_CYCLE   (ROUNDS_PER_CYCLE),
        .AD_FIFO_DEPTH_LOG2  (AD_FIFO_DEPTH_LOG2),
        .CT_FIFO_DEPTH_LOG2  (IN_FIFO_DEPTH_LOG2),
        .PT_FIFO_DEPTH_LOG2  (OUT_FIFO_DEPTH_LOG2)
      ) u_dec (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .clear_i                  (clear_i),
        .start_i                  (start_i),
        .start_ready_o            (start_ready_o),
        .key_i                    (key_i),
        .nonce_i                  (nonce_i),
        .ad_bytes_i               (ad_bytes_i),
        .msg_bytes_i              (msg_bytes_i),
        .tag_i                    (tag_i),
        .busy_o                   (busy_o),
        .done_o                   (done_o),
        .ad_in_valid_i            (ad_in_valid_i),
        .ad_in_ready_o            (ad_in_ready_o),
        .ad_in_block_i            (ad_in_block_i),
        .ciphertext_in_valid_i    (data_in_valid_i),
        .ciphertext_in_ready_o    (data_in_ready_o),
        .ciphertext_in_block_i    (data_in_block_i),
        .plaintext_out_valid_o    (data_out_valid_o),
        .plaintext_out_ready_i    (data_out_ready_i),
        .plaintext_out_block_o    (data_out_block_o),
        .plaintext_out_bytes_o    (data_out_bytes_o),
        .auth_out_valid_o         (result_valid_o),
        .auth_out_ready_i         (result_ready_i),
        .auth_out_ok_o            (auth_ok_w),
        .ad_fifo_empty_o          (ad_fifo_empty_o),
        .ad_fifo_full_o           (ad_fifo_full_o),
        .ad_fifo_level_o          (ad_fifo_level_o),
        .ciphertext_fifo_empty_o  (data_in_fifo_empty_o),
        .ciphertext_fifo_full_o   (data_in_fifo_full_o),
        .ciphertext_fifo_level_o  (data_in_fifo_level_o),
        .plaintext_fifo_empty_o   (data_out_fifo_empty_o),
        .plaintext_fifo_full_o    (data_out_fifo_full_o),
        .plaintext_fifo_level_o   (data_out_fifo_level_o)
      );
    end
  endgenerate

endmodule

`default_nettype wire
