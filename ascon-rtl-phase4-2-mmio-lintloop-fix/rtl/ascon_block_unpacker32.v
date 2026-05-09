`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Phase 3.5 128-bit-to-32-bit block unpacker.
//
// This is the inverse companion to ascon_block_packer32.  It accepts one
// internal 128-bit Ascon block plus a byte count and emits the valid low-order
// 32-bit lanes in order.
//
// Lane order is byte-stream order for the internal Ascon block layout
// {W0, W1}, where W0 is the first 8 bytes and sits in block[127:64]:
//   output word 0 = block_data_i[95:64]   // bytes 0..3
//   output word 1 = block_data_i[127:96]  // bytes 4..7
//   output word 2 = block_data_i[31:0]    // bytes 8..11
//   output word 3 = block_data_i[63:32]   // bytes 12..15

`default_nettype none

module ascon_block_unpacker32 (
  input  wire         clk,
  input  wire         rst_n,

  input  wire         clear_i,

  input  wire         block_valid_i,
  output wire         block_ready_o,
  input  wire [127:0] block_data_i,
  input  wire [4:0]   block_bytes_i,

  output wire         word_valid_o,
  input  wire         word_ready_i,
  output wire [31:0]  word_data_o,
  output wire [2:0]   word_bytes_o,
  output wire         word_last_o,

  output wire         active_o,
  output wire [1:0]   word_index_o,
  output wire [2:0]   words_left_o
);

  reg [127:0] block_q;
  reg [4:0]   block_bytes_q;
  reg [2:0]   total_words_q;
  reg [1:0]   word_index_q;
  reg         active_q;

  wire out_fire_w = word_valid_o && word_ready_i;
  wire last_w     = active_q && (word_index_q == (total_words_q[1:0] - 2'd1));
  wire in_fire_w  = block_valid_i && block_ready_o;

  assign block_ready_o = !clear_i && (!active_q || (out_fire_w && last_w));
  assign word_valid_o  = active_q;
  assign word_last_o   = last_w;
  assign active_o      = active_q;
  assign word_index_o  = word_index_q;
  assign words_left_o  = active_q ? (total_words_q - {1'b0, word_index_q}) : 3'd0;

  function [2:0] words_for_bytes;
    input [4:0] bytes;
    begin
      if (bytes == 5'd0) begin
        words_for_bytes = 3'd0;
      end else if (bytes <= 5'd4) begin
        words_for_bytes = 3'd1;
      end else if (bytes <= 5'd8) begin
        words_for_bytes = 3'd2;
      end else if (bytes <= 5'd12) begin
        words_for_bytes = 3'd3;
      end else begin
        words_for_bytes = 3'd4;
      end
    end
  endfunction

  function [31:0] select_word;
    input [127:0] block;
    input [1:0] idx;
    begin
      case (idx)
        2'd0: select_word = block[95:64];
        2'd1: select_word = block[127:96];
        2'd2: select_word = block[31:0];
        default: select_word = block[63:32];
      endcase
    end
  endfunction

  function [2:0] last_word_bytes;
    input [1:0] byte_rem;
    begin
      case (byte_rem)
        2'd0: last_word_bytes = 3'd4;
        2'd1: last_word_bytes = 3'd1;
        2'd2: last_word_bytes = 3'd2;
        default: last_word_bytes = 3'd3;
      endcase
    end
  endfunction

  assign word_data_o  = select_word(block_q, word_index_q);
  assign word_bytes_o = word_last_o ? last_word_bytes(block_bytes_q[1:0]) : 3'd4;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      block_q       <= 128'd0;
      block_bytes_q <= 5'd0;
      total_words_q <= 3'd0;
      word_index_q  <= 2'd0;
      active_q      <= 1'b0;
    end else if (clear_i) begin
      block_q       <= 128'd0;
      block_bytes_q <= 5'd0;
      total_words_q <= 3'd0;
      word_index_q  <= 2'd0;
      active_q      <= 1'b0;
    end else begin
      if (in_fire_w) begin
        block_q       <= block_data_i;
        block_bytes_q <= block_bytes_i;
        total_words_q <= words_for_bytes(block_bytes_i);
        word_index_q  <= 2'd0;
        active_q      <= (block_bytes_i != 5'd0);
      end else if (out_fire_w) begin
        if (last_w) begin
          active_q     <= 1'b0;
          word_index_q <= 2'd0;
        end else begin
          word_index_q <= word_index_q + 2'd1;
        end
      end
    end
  end

endmodule

`default_nettype wire
