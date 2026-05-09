`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Phase 3.3 buffered Ascon-AEAD128 decryption wrapper.
//
// This module mirrors the Phase 3.2 buffered encryption shell.  It keeps the
// verified Phase 2.4 decryption/authentication core bus-agnostic and inserts
// ready/valid FIFOs on the high-volume AD, ciphertext, and plaintext streams.
//
// Scope:
//   - Decryption only.
//   - Associated data supported.
//   - Arbitrary associated-data and ciphertext/plaintext lengths in bytes.
//   - Internal 128-bit Ascon block order only; CPU/bus byte packing belongs in
//     platform wrappers.
//   - Authentication status is forwarded directly with ready/valid and is not
//     buffered.
//
// Authentication contract:
//   Plaintext output is tentative until auth_out_valid_o && auth_out_ok_o has
//   been accepted.  A NEORV32/software wrapper must discard all plaintext for
//   the job if auth_out_ok_o is low.
//
// Contract:
//   - Input streams may be preloaded before start_i.
//   - start_i is accepted only when start_ready_o is high.
//   - clear_i clears only the stream FIFOs; assert it only while the core is
//     idle.  Full job abort/reset policy belongs in a later control wrapper.

`default_nettype none

module ascon_aead128_dec_ad_buffered #(
  parameter integer ROUNDS_PER_CYCLE    = 1,
  parameter integer AD_FIFO_DEPTH_LOG2   = 2,
  parameter integer CT_FIFO_DEPTH_LOG2   = 2,
  parameter integer PT_FIFO_DEPTH_LOG2   = 2
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

  input  wire         ciphertext_in_valid_i,
  output wire         ciphertext_in_ready_o,
  input  wire [127:0] ciphertext_in_block_i,

  output wire         plaintext_out_valid_o,
  input  wire         plaintext_out_ready_i,
  output wire [127:0] plaintext_out_block_o,
  output wire [4:0]   plaintext_out_bytes_o,

  output wire         auth_out_valid_o,
  input  wire         auth_out_ready_i,
  output wire         auth_out_ok_o,

  output wire         ad_fifo_empty_o,
  output wire         ad_fifo_full_o,
  output wire [AD_FIFO_DEPTH_LOG2:0] ad_fifo_level_o,

  output wire         ciphertext_fifo_empty_o,
  output wire         ciphertext_fifo_full_o,
  output wire [CT_FIFO_DEPTH_LOG2:0] ciphertext_fifo_level_o,

  output wire         plaintext_fifo_empty_o,
  output wire         plaintext_fifo_full_o,
  output wire [PT_FIFO_DEPTH_LOG2:0] plaintext_fifo_level_o
);

  wire         core_start_w;
  wire         core_busy_w;
  wire         core_done_w;

  wire         ad_fifo_out_valid_w;
  wire         ad_fifo_out_ready_w;
  wire [127:0] ad_fifo_out_data_w;

  wire         ct_fifo_out_valid_w;
  wire         ct_fifo_out_ready_w;
  wire [127:0] ct_fifo_out_data_w;

  wire         core_pt_valid_w;
  wire         core_pt_ready_w;
  wire [127:0] core_pt_block_w;
  wire [4:0]   core_pt_bytes_w;

  wire [132:0] pt_fifo_in_data_w;
  wire [132:0] pt_fifo_out_data_w;

  assign core_start_w = start_i && start_ready_o;

  // A new job is accepted only when the previous core job is idle and the
  // tentative-plaintext FIFO is empty, preventing output from different jobs
  // from being interleaved.  Authentication is direct, so the core not being
  // busy also implies no pending auth verdict.
  assign start_ready_o = !core_busy_w && plaintext_fifo_empty_o && !clear_i;
  assign busy_o        = core_busy_w;
  assign done_o        = core_done_w;

  assign pt_fifo_in_data_w = {core_pt_bytes_w, core_pt_block_w};
  assign plaintext_out_bytes_o = pt_fifo_out_data_w[132:128];
  assign plaintext_out_block_o = pt_fifo_out_data_w[127:0];

  ascon_stream_fifo #(
    .WIDTH(128),
    .DEPTH_LOG2(AD_FIFO_DEPTH_LOG2)
  ) u_ad_fifo (
    .clk        (clk),
    .rst_n      (rst_n),
    .clear_i    (clear_i),
    .in_valid_i (ad_in_valid_i),
    .in_ready_o (ad_in_ready_o),
    .in_data_i  (ad_in_block_i),
    .out_valid_o(ad_fifo_out_valid_w),
    .out_ready_i(ad_fifo_out_ready_w),
    .out_data_o (ad_fifo_out_data_w),
    .empty_o    (ad_fifo_empty_o),
    .full_o     (ad_fifo_full_o),
    .level_o    (ad_fifo_level_o)
  );

  ascon_stream_fifo #(
    .WIDTH(128),
    .DEPTH_LOG2(CT_FIFO_DEPTH_LOG2)
  ) u_ct_fifo (
    .clk        (clk),
    .rst_n      (rst_n),
    .clear_i    (clear_i),
    .in_valid_i (ciphertext_in_valid_i),
    .in_ready_o (ciphertext_in_ready_o),
    .in_data_i  (ciphertext_in_block_i),
    .out_valid_o(ct_fifo_out_valid_w),
    .out_ready_i(ct_fifo_out_ready_w),
    .out_data_o (ct_fifo_out_data_w),
    .empty_o    (ciphertext_fifo_empty_o),
    .full_o     (ciphertext_fifo_full_o),
    .level_o    (ciphertext_fifo_level_o)
  );

  ascon_stream_fifo #(
    .WIDTH(133),
    .DEPTH_LOG2(PT_FIFO_DEPTH_LOG2)
  ) u_pt_fifo (
    .clk        (clk),
    .rst_n      (rst_n),
    .clear_i    (clear_i),
    .in_valid_i (core_pt_valid_w),
    .in_ready_o (core_pt_ready_w),
    .in_data_i  (pt_fifo_in_data_w),
    .out_valid_o(plaintext_out_valid_o),
    .out_ready_i(plaintext_out_ready_i),
    .out_data_o (pt_fifo_out_data_w),
    .empty_o    (plaintext_fifo_empty_o),
    .full_o     (plaintext_fifo_full_o),
    .level_o    (plaintext_fifo_level_o)
  );

  ascon_aead128_dec_ad #(
    .ROUNDS_PER_CYCLE(ROUNDS_PER_CYCLE)
  ) u_core (
    .clk                  (clk),
    .rst_n                (rst_n),
    .start_i              (core_start_w),
    .key_i                (key_i),
    .nonce_i              (nonce_i),
    .ad_bytes_i           (ad_bytes_i),
    .msg_bytes_i          (msg_bytes_i),
    .tag_i                (tag_i),
    .busy_o               (core_busy_w),
    .done_o               (core_done_w),
    .ad_ready_o           (ad_fifo_out_ready_w),
    .ad_valid_i           (ad_fifo_out_valid_w),
    .ad_block_i           (ad_fifo_out_data_w),
    .ciphertext_ready_o   (ct_fifo_out_ready_w),
    .ciphertext_valid_i   (ct_fifo_out_valid_w),
    .ciphertext_block_i   (ct_fifo_out_data_w),
    .plaintext_valid_o    (core_pt_valid_w),
    .plaintext_ready_i    (core_pt_ready_w),
    .plaintext_block_o    (core_pt_block_w),
    .plaintext_bytes_o    (core_pt_bytes_w),
    .auth_valid_o         (auth_out_valid_o),
    .auth_ready_i         (auth_out_ready_i),
    .auth_ok_o            (auth_out_ok_o)
  );

endmodule

`default_nettype wire
