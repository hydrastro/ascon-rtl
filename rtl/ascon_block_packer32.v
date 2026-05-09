`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Phase 3.5 32-bit-to-128-bit block packer.
//
// This module is a small platform-neutral adapter for MMIO/XBUS/CFS-style
// wrappers.  It collects 32-bit words into the internal 128-bit Ascon block
// order used by the bus-agnostic cores.
//
// Lane order:
//   accepted word 0 -> block_data_o[31:0]
//   accepted word 1 -> block_data_o[63:32]
//   accepted word 2 -> block_data_o[95:64]
//   accepted word 3 -> block_data_o[127:96]
//
// word_bytes_i gives the number of valid low-order bytes in word_data_i.  It
// must be 1, 2, 3, or 4 when word_valid_i is high.  word_last_i flushes a
// short block before four words have been collected.  A full four-word block
// is emitted automatically even when word_last_i is low.

`default_nettype none

module ascon_block_packer32 (
  input  wire         clk,
  input  wire         rst_n,

  input  wire         clear_i,

  input  wire         word_valid_i,
  output wire         word_ready_o,
  input  wire [31:0]  word_data_i,
  input  wire [2:0]   word_bytes_i,
  input  wire         word_last_i,

  output wire         block_valid_o,
  input  wire         block_ready_i,
  output wire [127:0] block_data_o,
  output wire [4:0]   block_bytes_o,

  output wire [1:0]   fill_words_o,
  output wire [4:0]   fill_bytes_o,
  output wire         block_pending_o
);

  reg [127:0] buf_q;
  reg [1:0]   fill_words_q;
  reg [4:0]   fill_bytes_q;

  reg         block_valid_q;
  reg [127:0] block_data_q;
  reg [4:0]   block_bytes_q;

  wire word_complete_w = (fill_words_q == 2'd3) || word_last_i;
  wire block_fire_w    = block_valid_q && block_ready_i;
  wire word_fire_w     = word_valid_i && word_ready_o;

  assign word_ready_o    = !clear_i && (!word_complete_w || !block_valid_q || block_ready_i);
  assign block_valid_o   = block_valid_q;
  assign block_data_o    = block_data_q;
  assign block_bytes_o   = block_bytes_q;
  assign fill_words_o    = fill_words_q;
  assign fill_bytes_o    = fill_bytes_q;
  assign block_pending_o = block_valid_q;

  function [31:0] mask_word;
    input [31:0] data;
    input [2:0]  bytes;
    begin
      case (bytes)
        3'd1: mask_word = {24'd0, data[7:0]};
        3'd2: mask_word = {16'd0, data[15:0]};
        3'd3: mask_word = {8'd0,  data[23:0]};
        default: mask_word = data;
      endcase
    end
  endfunction

  function [127:0] insert_word;
    input [127:0] old_block;
    input [1:0]   idx;
    input [31:0]  word;
    begin
      insert_word = old_block;
      case (idx)
        2'd0: insert_word[31:0]    = word;
        2'd1: insert_word[63:32]   = word;
        2'd2: insert_word[95:64]   = word;
        default: insert_word[127:96] = word;
      endcase
    end
  endfunction

  wire [31:0]  masked_word_w = mask_word(word_data_i, word_bytes_i);
  wire [127:0] next_buf_w    = insert_word(buf_q, fill_words_q, masked_word_w);
  wire [4:0]   next_bytes_w  = fill_bytes_q + {2'd0, word_bytes_i};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buf_q         <= 128'd0;
      fill_words_q  <= 2'd0;
      fill_bytes_q  <= 5'd0;
      block_valid_q <= 1'b0;
      block_data_q  <= 128'd0;
      block_bytes_q <= 5'd0;
    end else if (clear_i) begin
      buf_q         <= 128'd0;
      fill_words_q  <= 2'd0;
      fill_bytes_q  <= 5'd0;
      block_valid_q <= 1'b0;
      block_data_q  <= 128'd0;
      block_bytes_q <= 5'd0;
    end else begin
      if (block_fire_w) begin
        block_valid_q <= 1'b0;
      end

      if (word_fire_w) begin
        if (word_complete_w) begin
          block_valid_q <= 1'b1;
          block_data_q  <= next_buf_w;
          block_bytes_q <= next_bytes_w;
          buf_q         <= 128'd0;
          fill_words_q  <= 2'd0;
          fill_bytes_q  <= 5'd0;
        end else begin
          buf_q         <= next_buf_w;
          fill_words_q  <= fill_words_q + 2'd1;
          fill_bytes_q  <= next_bytes_w;
        end
      end
    end
  end

endmodule

`default_nettype wire
