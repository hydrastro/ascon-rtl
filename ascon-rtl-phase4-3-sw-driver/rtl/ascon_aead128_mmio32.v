`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Phase 4.1 generic 32-bit MMIO-style wrapper for the buffered Ascon-AEAD128
// datapath.
//
// This is a platform-neutral bring-up wrapper, not the final high-throughput
// NEORV32 datapath.  It exposes a simple valid/ready 32-bit register bus and
// adapts 32-bit writes/reads to the internal 128-bit block-stream boundary.
//
// Address map, byte addresses:
//   0x00 CTRL       write bit0=start, bit1=clear, bit2=result_ack
//   0x04 STATUS     read status and small metadata fields
//   0x08 AD_BYTES   read/write associated-data byte length
//   0x0c MSG_BYTES  read/write payload byte length
//   0x10..0x1c KEY  read/write key words, word0 at key[31:0]
//   0x20..0x2c NONCE read/write nonce words, word0 at nonce[31:0]
//   0x30..0x3c TAG_IN read/write expected decrypt tag words
//   0x40 AD_IN      write 32-bit associated-data word stream
//   0x44 DATA_IN    write 32-bit plaintext/ciphertext word stream
//   0x48 DATA_OUT   read 32-bit ciphertext/plaintext word stream; read pops
//   0x4c DOUT_META  read bits[2:0]=bytes, bit8=last, bit16=valid
//   0x50..0x5c RESULT read generated tag words for encryption, zero for decrypt
//   0x60 LEVELS     read FIFO levels
//
// AD/DATA stream word order is byte-stream order: word 0 carries bytes 0..3
// of each 16-byte block, word 1 carries bytes 4..7, word 2 carries bytes
// 8..11, and word 3 carries bytes 12..15. KEY/NONCE/TAG registers remain raw
// 128-bit register slices, word0 at bits [31:0].

`default_nettype none

module ascon_aead128_mmio32 #(
  parameter integer DECRYPT             = 0,
  parameter integer ROUNDS_PER_CYCLE    = 1,
  parameter integer AD_FIFO_DEPTH_LOG2   = 2,
  parameter integer IN_FIFO_DEPTH_LOG2   = 2,
  parameter integer OUT_FIFO_DEPTH_LOG2  = 2
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        reg_valid_i,
  output wire        reg_ready_o,
  input  wire        reg_write_i,
  input  wire [7:0]  reg_addr_i,
  input  wire [31:0] reg_wdata_i,
  input  wire [3:0]  reg_wstrb_i,
  output reg  [31:0] reg_rdata_o,

  output wire        irq_o
);

  localparam [7:0] ADDR_CTRL      = 8'h00;
  localparam [7:0] ADDR_STATUS    = 8'h04;
  localparam [7:0] ADDR_AD_BYTES  = 8'h08;
  localparam [7:0] ADDR_MSG_BYTES = 8'h0c;
  localparam [7:0] ADDR_KEY0      = 8'h10;
  localparam [7:0] ADDR_KEY1      = 8'h14;
  localparam [7:0] ADDR_KEY2      = 8'h18;
  localparam [7:0] ADDR_KEY3      = 8'h1c;
  localparam [7:0] ADDR_NONCE0    = 8'h20;
  localparam [7:0] ADDR_NONCE1    = 8'h24;
  localparam [7:0] ADDR_NONCE2    = 8'h28;
  localparam [7:0] ADDR_NONCE3    = 8'h2c;
  localparam [7:0] ADDR_TAG0      = 8'h30;
  localparam [7:0] ADDR_TAG1      = 8'h34;
  localparam [7:0] ADDR_TAG2      = 8'h38;
  localparam [7:0] ADDR_TAG3      = 8'h3c;
  localparam [7:0] ADDR_AD_IN     = 8'h40;
  localparam [7:0] ADDR_DATA_IN   = 8'h44;
  localparam [7:0] ADDR_DATA_OUT  = 8'h48;
  localparam [7:0] ADDR_DOUT_META = 8'h4c;
  localparam [7:0] ADDR_RES0      = 8'h50;
  localparam [7:0] ADDR_RES1      = 8'h54;
  localparam [7:0] ADDR_RES2      = 8'h58;
  localparam [7:0] ADDR_RES3      = 8'h5c;
  localparam [7:0] ADDR_LEVELS    = 8'h60;

  reg [127:0] key_q;
  reg [127:0] nonce_q;
  reg [127:0] tag_in_q;
  reg [127:0] result_tag_q;
  reg         result_auth_ok_q;
  reg         result_pending_q;
  reg [31:0]  ad_bytes_q;
  reg [31:0]  msg_bytes_q;
  reg [31:0]  ad_write_remaining_q;
  reg [31:0]  data_write_remaining_q;
  reg [31:0]  data_read_remaining_q;

  wire is_ctrl_w      = (reg_addr_i == ADDR_CTRL);
  wire is_ad_in_w     = (reg_addr_i == ADDR_AD_IN);
  wire is_data_in_w   = (reg_addr_i == ADDR_DATA_IN);
  wire is_data_out_w  = (reg_addr_i == ADDR_DATA_OUT);

  wire full_word_write_w = (reg_wstrb_i == 4'hf);

  wire ad_word_ready_w;
  wire data_word_ready_w;
  wire ad_block_valid_w;
  wire ad_block_ready_w;
  wire [127:0] ad_block_w;
  wire [4:0] ad_block_bytes_w;
  wire data_in_block_valid_w;
  wire data_in_block_ready_w;
  wire [127:0] data_in_block_w;
  wire [4:0] data_in_block_bytes_w;

  wire data_out_block_valid_w;
  wire data_out_block_ready_w;
  wire [127:0] data_out_block_w;
  wire [4:0] data_out_block_bytes_w;

  wire data_out_word_valid_w;
  wire data_out_word_ready_w;
  wire [31:0] data_out_word_w;
  wire [2:0] data_out_word_bytes_w;
  wire data_out_word_last_w;

  wire start_ready_w;
  wire busy_w;
  wire done_w;
  wire result_valid_w;
  wire result_ready_w;
  wire [127:0] result_tag_w;
  wire result_auth_ok_w;

  wire ad_fifo_empty_w;
  wire ad_fifo_full_w;
  wire [AD_FIFO_DEPTH_LOG2:0] ad_fifo_level_w;
  wire data_in_fifo_empty_w;
  wire data_in_fifo_full_w;
  wire [IN_FIFO_DEPTH_LOG2:0] data_in_fifo_level_w;
  wire data_out_fifo_empty_w;
  wire data_out_fifo_full_w;
  wire [OUT_FIFO_DEPTH_LOG2:0] data_out_fifo_level_w;

  wire [1:0] ad_packer_fill_words_w;
  wire [4:0] ad_packer_fill_bytes_w;
  wire       ad_packer_block_pending_w;
  wire [1:0] data_packer_fill_words_w;
  wire [4:0] data_packer_fill_bytes_w;
  wire       data_packer_block_pending_w;
  wire       data_unpacker_active_w;
  wire [1:0] data_unpacker_word_index_w;
  wire [2:0] data_unpacker_words_left_w;

  // CTRL writes are always accepted, while stream ports may apply backpressure.
  // Keep CTRL side effects independent of reg_ready_o to avoid a combinational
  // loop through clear_i -> packer ready -> reg_ready_o -> write_transfer_w.
  wire ctrl_transfer_w  = reg_valid_i && reg_write_i && is_ctrl_w;
  wire write_transfer_w = reg_valid_i && reg_write_i && reg_ready_o;
  wire read_transfer_w  = reg_valid_i && !reg_write_i && reg_ready_o;

  wire ctrl_start_w      = ctrl_transfer_w && reg_wdata_i[0];
  wire ctrl_clear_w      = ctrl_transfer_w && reg_wdata_i[1];
  wire ctrl_result_ack_w = ctrl_transfer_w && reg_wdata_i[2];

  function [2:0] bytes_next_word;
    input [31:0] remaining;
    begin
      if (remaining == 32'd0) begin
        bytes_next_word = 3'd4;
      end else if (remaining >= 32'd4) begin
        bytes_next_word = 3'd4;
      end else begin
        bytes_next_word = remaining[2:0];
      end
    end
  endfunction

  function last_next_word;
    input [31:0] remaining;
    begin
      last_next_word = (remaining <= 32'd4);
    end
  endfunction

  wire [2:0] ad_word_bytes_w   = bytes_next_word(ad_write_remaining_q);
  wire [2:0] data_word_bytes_w = bytes_next_word(data_write_remaining_q);
  wire ad_word_last_w          = last_next_word(ad_write_remaining_q);
  wire data_word_last_w        = last_next_word(data_write_remaining_q);
  wire [2:0] data_out_word_bytes_global_w = bytes_next_word(data_read_remaining_q);
  wire       data_out_word_last_global_w  = last_next_word(data_read_remaining_q);

  assign reg_ready_o = !reg_valid_i ? 1'b1 :
                       (reg_write_i && is_ad_in_w) ? ad_word_ready_w :
                       (reg_write_i && is_data_in_w) ? data_word_ready_w :
                       (!reg_write_i && is_data_out_w) ? data_out_word_valid_w :
                       1'b1;

  wire ad_word_valid_w = reg_valid_i && reg_write_i && is_ad_in_w && full_word_write_w &&
                         (ad_write_remaining_q != 32'd0);
  wire data_word_valid_w = reg_valid_i && reg_write_i && is_data_in_w && full_word_write_w &&
                           (data_write_remaining_q != 32'd0);

  assign data_out_word_ready_w = read_transfer_w && is_data_out_w;

  assign result_ready_w = !result_pending_q;
  assign irq_o = result_pending_q;

  ascon_block_packer32 u_ad_packer (
    .clk             (clk),
    .rst_n           (rst_n),
    .clear_i         (ctrl_clear_w),
    .word_valid_i    (ad_word_valid_w),
    .word_ready_o    (ad_word_ready_w),
    .word_data_i     (reg_wdata_i),
    .word_bytes_i    (ad_word_bytes_w),
    .word_last_i     (ad_word_last_w),
    .block_valid_o   (ad_block_valid_w),
    .block_ready_i   (ad_block_ready_w),
    .block_data_o    (ad_block_w),
    .block_bytes_o   (ad_block_bytes_w),
    .fill_words_o    (ad_packer_fill_words_w),
    .fill_bytes_o    (ad_packer_fill_bytes_w),
    .block_pending_o (ad_packer_block_pending_w)
  );

  ascon_block_packer32 u_data_packer (
    .clk             (clk),
    .rst_n           (rst_n),
    .clear_i         (ctrl_clear_w),
    .word_valid_i    (data_word_valid_w),
    .word_ready_o    (data_word_ready_w),
    .word_data_i     (reg_wdata_i),
    .word_bytes_i    (data_word_bytes_w),
    .word_last_i     (data_word_last_w),
    .block_valid_o   (data_in_block_valid_w),
    .block_ready_i   (data_in_block_ready_w),
    .block_data_o    (data_in_block_w),
    .block_bytes_o   (data_in_block_bytes_w),
    .fill_words_o    (data_packer_fill_words_w),
    .fill_bytes_o    (data_packer_fill_bytes_w),
    .block_pending_o (data_packer_block_pending_w)
  );

  // The buffered core already knows byte counts from msg_bytes_i/ad_bytes_i;
  // block byte counts from the input packers are intentionally unused here.
  /* verilator lint_off UNUSED */
  wire [4:0] unused_ad_block_bytes_w   = ad_block_bytes_w;
  wire [4:0] unused_data_block_bytes_w = data_in_block_bytes_w;
  wire [1:0] unused_ad_packer_fill_words_w = ad_packer_fill_words_w;
  wire [4:0] unused_ad_packer_fill_bytes_w = ad_packer_fill_bytes_w;
  wire       unused_ad_packer_block_pending_w = ad_packer_block_pending_w;
  wire [1:0] unused_data_packer_fill_words_w = data_packer_fill_words_w;
  wire [4:0] unused_data_packer_fill_bytes_w = data_packer_fill_bytes_w;
  wire       unused_data_packer_block_pending_w = data_packer_block_pending_w;
  wire [2:0] unused_data_out_word_bytes_w = data_out_word_bytes_w;
  wire       unused_data_out_word_last_w = data_out_word_last_w;
  wire       unused_data_unpacker_active_w = data_unpacker_active_w;
  wire [1:0] unused_data_unpacker_word_index_w = data_unpacker_word_index_w;
  wire [2:0] unused_data_unpacker_words_left_w = data_unpacker_words_left_w;
  /* verilator lint_on UNUSED */

  ascon_aead128_buffered #(
    .DECRYPT            (DECRYPT),
    .ROUNDS_PER_CYCLE   (ROUNDS_PER_CYCLE),
    .AD_FIFO_DEPTH_LOG2  (AD_FIFO_DEPTH_LOG2),
    .IN_FIFO_DEPTH_LOG2  (IN_FIFO_DEPTH_LOG2),
    .OUT_FIFO_DEPTH_LOG2 (OUT_FIFO_DEPTH_LOG2)
  ) u_core (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .clear_i                 (ctrl_clear_w),
    .start_i                 (ctrl_start_w),
    .start_ready_o           (start_ready_w),
    .key_i                   (key_q),
    .nonce_i                 (nonce_q),
    .ad_bytes_i              (ad_bytes_q),
    .msg_bytes_i             (msg_bytes_q),
    .tag_i                   (tag_in_q),
    .busy_o                  (busy_w),
    .done_o                  (done_w),
    .ad_in_valid_i           (ad_block_valid_w),
    .ad_in_ready_o           (ad_block_ready_w),
    .ad_in_block_i           (ad_block_w),
    .data_in_valid_i         (data_in_block_valid_w),
    .data_in_ready_o         (data_in_block_ready_w),
    .data_in_block_i         (data_in_block_w),
    .data_out_valid_o        (data_out_block_valid_w),
    .data_out_ready_i        (data_out_block_ready_w),
    .data_out_block_o        (data_out_block_w),
    .data_out_bytes_o        (data_out_block_bytes_w),
    .result_valid_o          (result_valid_w),
    .result_ready_i          (result_ready_w),
    .result_tag_o            (result_tag_w),
    .result_auth_ok_o        (result_auth_ok_w),
    .ad_fifo_empty_o         (ad_fifo_empty_w),
    .ad_fifo_full_o          (ad_fifo_full_w),
    .ad_fifo_level_o         (ad_fifo_level_w),
    .data_in_fifo_empty_o    (data_in_fifo_empty_w),
    .data_in_fifo_full_o     (data_in_fifo_full_w),
    .data_in_fifo_level_o    (data_in_fifo_level_w),
    .data_out_fifo_empty_o   (data_out_fifo_empty_w),
    .data_out_fifo_full_o    (data_out_fifo_full_w),
    .data_out_fifo_level_o   (data_out_fifo_level_w)
  );

  ascon_block_unpacker32 u_data_unpacker (
    .clk             (clk),
    .rst_n           (rst_n),
    .clear_i         (ctrl_clear_w),
    .block_valid_i   (data_out_block_valid_w),
    .block_ready_o   (data_out_block_ready_w),
    .block_data_i    (data_out_block_w),
    .block_bytes_i   (data_out_block_bytes_w),
    .word_valid_o    (data_out_word_valid_w),
    .word_ready_i    (data_out_word_ready_w),
    .word_data_o     (data_out_word_w),
    .word_bytes_o    (data_out_word_bytes_w),
    .word_last_o     (data_out_word_last_w),
    .active_o        (data_unpacker_active_w),
    .word_index_o    (data_unpacker_word_index_w),
    .words_left_o    (data_unpacker_words_left_w)
  );

  always @* begin
    reg_rdata_o = 32'd0;
    case (reg_addr_i)
      ADDR_STATUS: begin
        reg_rdata_o[0]      = start_ready_w;
        reg_rdata_o[1]      = busy_w;
        reg_rdata_o[2]      = done_w;
        reg_rdata_o[3]      = data_out_word_valid_w;
        reg_rdata_o[4]      = result_pending_q;
        reg_rdata_o[5]      = result_auth_ok_q;
        reg_rdata_o[6]      = ad_word_ready_w;
        reg_rdata_o[7]      = data_word_ready_w;
        reg_rdata_o[8]      = irq_o;
        reg_rdata_o[11:9]   = data_out_word_bytes_global_w;
        reg_rdata_o[12]     = data_out_word_last_global_w;
        reg_rdata_o[16]     = ad_fifo_empty_w;
        reg_rdata_o[17]     = ad_fifo_full_w;
        reg_rdata_o[18]     = data_in_fifo_empty_w;
        reg_rdata_o[19]     = data_in_fifo_full_w;
        reg_rdata_o[20]     = data_out_fifo_empty_w;
        reg_rdata_o[21]     = data_out_fifo_full_w;
      end
      ADDR_AD_BYTES:  reg_rdata_o = ad_bytes_q;
      ADDR_MSG_BYTES: reg_rdata_o = msg_bytes_q;
      ADDR_KEY0:      reg_rdata_o = key_q[31:0];
      ADDR_KEY1:      reg_rdata_o = key_q[63:32];
      ADDR_KEY2:      reg_rdata_o = key_q[95:64];
      ADDR_KEY3:      reg_rdata_o = key_q[127:96];
      ADDR_NONCE0:    reg_rdata_o = nonce_q[31:0];
      ADDR_NONCE1:    reg_rdata_o = nonce_q[63:32];
      ADDR_NONCE2:    reg_rdata_o = nonce_q[95:64];
      ADDR_NONCE3:    reg_rdata_o = nonce_q[127:96];
      ADDR_TAG0:      reg_rdata_o = tag_in_q[31:0];
      ADDR_TAG1:      reg_rdata_o = tag_in_q[63:32];
      ADDR_TAG2:      reg_rdata_o = tag_in_q[95:64];
      ADDR_TAG3:      reg_rdata_o = tag_in_q[127:96];
      ADDR_DATA_OUT:  reg_rdata_o = data_out_word_w;
      ADDR_DOUT_META: begin
        reg_rdata_o[2:0] = data_out_word_bytes_global_w;
        reg_rdata_o[8]   = data_out_word_last_global_w;
        reg_rdata_o[16]  = data_out_word_valid_w;
      end
      ADDR_RES0:      reg_rdata_o = result_tag_q[31:0];
      ADDR_RES1:      reg_rdata_o = result_tag_q[63:32];
      ADDR_RES2:      reg_rdata_o = result_tag_q[95:64];
      ADDR_RES3:      reg_rdata_o = result_tag_q[127:96];
      ADDR_LEVELS: begin
        reg_rdata_o[AD_FIFO_DEPTH_LOG2:0] = ad_fifo_level_w;
        reg_rdata_o[8 + IN_FIFO_DEPTH_LOG2:8] = data_in_fifo_level_w;
        reg_rdata_o[16 + OUT_FIFO_DEPTH_LOG2:16] = data_out_fifo_level_w;
      end
      default: reg_rdata_o = 32'd0;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      key_q                    <= 128'd0;
      nonce_q                  <= 128'd0;
      tag_in_q                 <= 128'd0;
      result_tag_q             <= 128'd0;
      result_auth_ok_q         <= 1'b0;
      result_pending_q         <= 1'b0;
      ad_bytes_q               <= 32'd0;
      msg_bytes_q              <= 32'd0;
      ad_write_remaining_q     <= 32'd0;
      data_write_remaining_q   <= 32'd0;
      data_read_remaining_q    <= 32'd0;
    end else begin
      if (result_valid_w && result_ready_w) begin
        result_tag_q     <= result_tag_w;
        result_auth_ok_q <= result_auth_ok_w;
        result_pending_q <= 1'b1;
      end

      if (ctrl_result_ack_w || ctrl_clear_w) begin
        result_pending_q <= 1'b0;
      end

      if (ctrl_clear_w) begin
        ad_write_remaining_q   <= ad_bytes_q;
        data_write_remaining_q <= msg_bytes_q;
        data_read_remaining_q  <= msg_bytes_q;
      end

      if (write_transfer_w && full_word_write_w) begin
        case (reg_addr_i)
          ADDR_AD_BYTES: begin
            ad_bytes_q           <= reg_wdata_i;
            ad_write_remaining_q <= reg_wdata_i;
          end
          ADDR_MSG_BYTES: begin
            msg_bytes_q            <= reg_wdata_i;
            data_write_remaining_q <= reg_wdata_i;
            data_read_remaining_q  <= reg_wdata_i;
          end
          ADDR_KEY0:   key_q[31:0]     <= reg_wdata_i;
          ADDR_KEY1:   key_q[63:32]    <= reg_wdata_i;
          ADDR_KEY2:   key_q[95:64]    <= reg_wdata_i;
          ADDR_KEY3:   key_q[127:96]   <= reg_wdata_i;
          ADDR_NONCE0: nonce_q[31:0]   <= reg_wdata_i;
          ADDR_NONCE1: nonce_q[63:32]  <= reg_wdata_i;
          ADDR_NONCE2: nonce_q[95:64]  <= reg_wdata_i;
          ADDR_NONCE3: nonce_q[127:96] <= reg_wdata_i;
          ADDR_TAG0:   tag_in_q[31:0]  <= reg_wdata_i;
          ADDR_TAG1:   tag_in_q[63:32] <= reg_wdata_i;
          ADDR_TAG2:   tag_in_q[95:64] <= reg_wdata_i;
          ADDR_TAG3:   tag_in_q[127:96] <= reg_wdata_i;
          default: begin
          end
        endcase
      end

      if (write_transfer_w && is_ad_in_w && (ad_write_remaining_q != 32'd0)) begin
        if (ad_write_remaining_q <= 32'd4) begin
          ad_write_remaining_q <= 32'd0;
        end else begin
          ad_write_remaining_q <= ad_write_remaining_q - 32'd4;
        end
      end

      if (write_transfer_w && is_data_in_w && (data_write_remaining_q != 32'd0)) begin
        if (data_write_remaining_q <= 32'd4) begin
          data_write_remaining_q <= 32'd0;
        end else begin
          data_write_remaining_q <= data_write_remaining_q - 32'd4;
        end
      end

      if (read_transfer_w && is_data_out_w && (data_read_remaining_q != 32'd0)) begin
        if (data_read_remaining_q <= 32'd4) begin
          data_read_remaining_q <= 32'd0;
        end else begin
          data_read_remaining_q <= data_read_remaining_q - 32'd4;
        end
      end
    end
  end

endmodule

`default_nettype wire
