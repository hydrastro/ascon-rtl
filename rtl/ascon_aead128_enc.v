`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Phase 2.2 Ascon-AEAD128 encryption core.
//
// Scope of this module:
//   - Encryption only.
//   - No associated data.
//   - Arbitrary plaintext length in bytes.
//   - Inputs/outputs use internal Ascon 64-bit word order, not CPU byte order.
//   - The bus/wrapper is responsible for packing raw bytes into the internal
//     little-endian Ascon words used here.
//
// Packing convention:
//   key_i[127:64]         = K0 = LOADBYTES(k,     8)
//   key_i[63:0]           = K1 = LOADBYTES(k + 8, 8)
//   nonce_i[127:64]       = N0 = LOADBYTES(n,     8)
//   nonce_i[63:0]         = N1 = LOADBYTES(n + 8, 8)
//   plaintext_block_i     = {M0, M1}
//   ciphertext_block_o    = {C0, C1}
//   tag_o                 = {T0, T1}
//
// Message interface:
//   msg_bytes_i declares the total plaintext length.
//   The core requests ceil(msg_bytes_i / 16) plaintext blocks.
//   ciphertext_bytes_o tells the wrapper how many bytes are valid in each
//   ciphertext block. It is 16 for full blocks and 1..15 for the final partial
//   block. Empty messages produce no ciphertext block and one tag.

module ascon_aead128_enc #(
  parameter integer ROUNDS_PER_CYCLE = 1
) (
  input  wire         clk,
  input  wire         rst_n,

  input  wire         start_i,
  input  wire [127:0] key_i,
  input  wire [127:0] nonce_i,
  input  wire [31:0]  msg_bytes_i,

  output wire         busy_o,
  output reg          done_o,

  output wire         plaintext_ready_o,
  input  wire         plaintext_valid_i,
  input  wire [127:0] plaintext_block_i,

  output reg          ciphertext_valid_o,
  input  wire         ciphertext_ready_i,
  output reg  [127:0] ciphertext_block_o,
  output reg  [4:0]   ciphertext_bytes_o,

  output reg          tag_valid_o,
  input  wire         tag_ready_i,
  output reg  [127:0] tag_o
);

  localparam [63:0] ASCON_128A_IV = 64'h00001000808c0001;
  localparam [63:0] ASCON_PAD0    = 64'h0000000000000001;
  localparam [63:0] ASCON_DSEP    = 64'h8000000000000000;

  localparam [3:0] ST_IDLE             = 4'd0;
  localparam [3:0] ST_INIT_WAIT        = 4'd1;
  localparam [3:0] ST_WAIT_FULL        = 4'd2;
  localparam [3:0] ST_FULL_PERM_WAIT   = 4'd3;
  localparam [3:0] ST_WAIT_PARTIAL     = 4'd4;
  localparam [3:0] ST_DRAIN_CT         = 4'd5;
  localparam [3:0] ST_FINAL_WAIT       = 4'd6;
  localparam [3:0] ST_TAG_WAIT         = 4'd7;

  reg [3:0]   state_q;
  reg [319:0] ascon_state_q;
  reg [127:0] key_q;
  reg [31:0]  full_blocks_left_q;
  reg [4:0]   final_bytes_q;

  reg         perm_start_q;
  reg [3:0]   perm_rounds_q;
  reg [319:0] perm_state_i_q;
  wire        perm_busy_w;
  wire        perm_done_w;
  wire [319:0] perm_state_o_w;

  wire [63:0] k0_w = key_q[127:64];
  wire [63:0] k1_w = key_q[63:0];

  wire [63:0] s0_w = ascon_state_q[319:256];
  wire [63:0] s1_w = ascon_state_q[255:192];
  wire [63:0] s2_w = ascon_state_q[191:128];
  wire [63:0] s3_w = ascon_state_q[127:64];
  wire [63:0] s4_w = ascon_state_q[63:0];

  wire [63:0] m0_w = plaintext_block_i[127:64];
  wire [63:0] m1_w = plaintext_block_i[63:0];

  wire [63:0] full_c0_w = s0_w ^ m0_w;
  wire [63:0] full_c1_w = s1_w ^ m1_w;

  wire [4:0] part0_bytes_w = (final_bytes_q > 5'd8) ? 5'd8 : final_bytes_q;
  wire [4:0] part1_bytes_w = (final_bytes_q > 5'd8) ? (final_bytes_q - 5'd8) : 5'd0;

  wire [63:0] part0_mask_w = byte_mask64(part0_bytes_w);
  wire [63:0] part1_mask_w = byte_mask64(part1_bytes_w);
  wire [63:0] part_m0_w    = m0_w & part0_mask_w;
  wire [63:0] part_m1_w    = m1_w & part1_mask_w;
  wire [63:0] part_c0_w    = (s0_w ^ part_m0_w) & part0_mask_w;
  wire [63:0] part_c1_w    = (s1_w ^ part_m1_w) & part1_mask_w;

  wire [63:0] part_s0_w = (final_bytes_q < 5'd8) ?
                          (s0_w ^ part_m0_w ^ pad64(final_bytes_q)) :
                          (s0_w ^ part_m0_w);

  wire [63:0] part_s1_w = (final_bytes_q < 5'd8) ?
                          s1_w :
                          ((final_bytes_q == 5'd8) ?
                           (s1_w ^ ASCON_PAD0) :
                           (s1_w ^ part_m1_w ^ pad64(part1_bytes_w)));

  assign busy_o = (state_q != ST_IDLE) | perm_busy_w;
  assign plaintext_ready_o =
    ((state_q == ST_WAIT_FULL) || (state_q == ST_WAIT_PARTIAL)) &&
    !ciphertext_valid_o;

  ascon_perm_unrolled #(
    .ROUNDS_PER_CYCLE(ROUNDS_PER_CYCLE)
  ) u_perm (
    .clk     (clk),
    .rst_n   (rst_n),
    .start_i (perm_start_q),
    .rounds_i(perm_rounds_q),
    .state_i (perm_state_i_q),
    .busy_o  (perm_busy_w),
    .done_o  (perm_done_w),
    .state_o (perm_state_o_w)
  );

  function [63:0] byte_mask64;
    input [4:0] n;
    begin
      case (n)
        5'd0:    byte_mask64 = 64'h0000000000000000;
        5'd1:    byte_mask64 = 64'h00000000000000ff;
        5'd2:    byte_mask64 = 64'h000000000000ffff;
        5'd3:    byte_mask64 = 64'h0000000000ffffff;
        5'd4:    byte_mask64 = 64'h00000000ffffffff;
        5'd5:    byte_mask64 = 64'h000000ffffffffff;
        5'd6:    byte_mask64 = 64'h0000ffffffffffff;
        5'd7:    byte_mask64 = 64'h00ffffffffffffff;
        default: byte_mask64 = 64'hffffffffffffffff;
      endcase
    end
  endfunction

  function [63:0] pad64;
    input [4:0] byte_index;
    begin
      case (byte_index)
        5'd0:    pad64 = 64'h0000000000000001;
        5'd1:    pad64 = 64'h0000000000000100;
        5'd2:    pad64 = 64'h0000000000010000;
        5'd3:    pad64 = 64'h0000000001000000;
        5'd4:    pad64 = 64'h0000000100000000;
        5'd5:    pad64 = 64'h0000010000000000;
        5'd6:    pad64 = 64'h0001000000000000;
        5'd7:    pad64 = 64'h0100000000000000;
        default: pad64 = 64'h0000000000000000;
      endcase
    end
  endfunction

  task start_perm;
    input [3:0] rounds;
    input [319:0] state_in;
    begin
      perm_rounds_q  <= rounds;
      perm_state_i_q <= state_in;
      perm_start_q   <= 1'b1;
    end
  endtask

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q              <= ST_IDLE;
      ascon_state_q        <= 320'd0;
      key_q                <= 128'd0;
      full_blocks_left_q   <= 32'd0;
      final_bytes_q        <= 5'd0;
      perm_start_q         <= 1'b0;
      perm_rounds_q        <= 4'd0;
      perm_state_i_q       <= 320'd0;
      done_o               <= 1'b0;
      ciphertext_valid_o   <= 1'b0;
      ciphertext_block_o   <= 128'd0;
      ciphertext_bytes_o   <= 5'd0;
      tag_valid_o          <= 1'b0;
      tag_o                <= 128'd0;
    end else begin
      perm_start_q <= 1'b0;
      done_o       <= 1'b0;

      if (ciphertext_valid_o && ciphertext_ready_i) begin
        ciphertext_valid_o <= 1'b0;
      end

      case (state_q)
        ST_IDLE: begin
          if (start_i) begin
            key_q              <= key_i;
            full_blocks_left_q <= {4'd0, msg_bytes_i[31:4]};
            final_bytes_q      <= {1'b0, msg_bytes_i[3:0]};
            ascon_state_q      <= {ASCON_128A_IV, key_i[127:64], key_i[63:0],
                                   nonce_i[127:64], nonce_i[63:0]};
            start_perm(4'd12, {ASCON_128A_IV, key_i[127:64], key_i[63:0],
                               nonce_i[127:64], nonce_i[63:0]});
            state_q <= ST_INIT_WAIT;
          end
        end

        ST_INIT_WAIT: begin
          if (perm_done_w) begin
            // Finish initialization: S3 ^= K0, S4 ^= K1, then domain separation.
            ascon_state_q <= {perm_state_o_w[319:128],
                              perm_state_o_w[127:64] ^ k0_w,
                              (perm_state_o_w[63:0] ^ k1_w) ^ ASCON_DSEP};

            if (full_blocks_left_q != 32'd0) begin
              state_q <= ST_WAIT_FULL;
            end else if (final_bytes_q != 5'd0) begin
              state_q <= ST_WAIT_PARTIAL;
            end else begin
              state_q <= ST_DRAIN_CT;
            end
          end
        end

        ST_WAIT_FULL: begin
          if (plaintext_valid_i && plaintext_ready_o) begin
            ciphertext_block_o <= {full_c0_w, full_c1_w};
            ciphertext_bytes_o <= 5'd16;
            ciphertext_valid_o <= 1'b1;
            ascon_state_q      <= {full_c0_w, full_c1_w, s2_w, s3_w, s4_w};
            full_blocks_left_q <= full_blocks_left_q - 32'd1;
            start_perm(4'd8, {full_c0_w, full_c1_w, s2_w, s3_w, s4_w});
            state_q <= ST_FULL_PERM_WAIT;
          end
        end

        ST_FULL_PERM_WAIT: begin
          if (perm_done_w) begin
            ascon_state_q <= perm_state_o_w;
            if (full_blocks_left_q != 32'd0) begin
              state_q <= ST_WAIT_FULL;
            end else if (final_bytes_q != 5'd0) begin
              state_q <= ST_WAIT_PARTIAL;
            end else begin
              state_q <= ST_DRAIN_CT;
            end
          end
        end

        ST_WAIT_PARTIAL: begin
          if (plaintext_valid_i && plaintext_ready_o) begin
            ciphertext_block_o <= {part_c0_w, part_c1_w};
            ciphertext_bytes_o <= final_bytes_q;
            ciphertext_valid_o <= 1'b1;
            ascon_state_q      <= {part_s0_w, part_s1_w, s2_w, s3_w, s4_w};
            state_q            <= ST_DRAIN_CT;
          end
        end

        ST_DRAIN_CT: begin
          if (!ciphertext_valid_o) begin
            if (final_bytes_q == 5'd0) begin
              // Exact rate-multiple message, including mlen=0: apply the
              // required empty final plaintext block padding before finalizing.
              start_perm(4'd12, {s0_w ^ ASCON_PAD0,
                                 s1_w,
                                 s2_w ^ k0_w,
                                 s3_w ^ k1_w,
                                 s4_w});
            end else begin
              // Partial final block has already applied the padding byte.
              start_perm(4'd12, {s0_w,
                                 s1_w,
                                 s2_w ^ k0_w,
                                 s3_w ^ k1_w,
                                 s4_w});
            end
            state_q <= ST_FINAL_WAIT;
          end
        end

        ST_FINAL_WAIT: begin
          if (perm_done_w) begin
            ascon_state_q <= {perm_state_o_w[319:128],
                              perm_state_o_w[127:64] ^ k0_w,
                              perm_state_o_w[63:0] ^ k1_w};
            tag_o       <= {perm_state_o_w[127:64] ^ k0_w,
                            perm_state_o_w[63:0] ^ k1_w};
            tag_valid_o <= 1'b1;
            state_q     <= ST_TAG_WAIT;
          end
        end

        ST_TAG_WAIT: begin
          if (tag_valid_o && tag_ready_i) begin
            tag_valid_o <= 1'b0;
            done_o      <= 1'b1;
            state_q     <= ST_IDLE;
          end
        end

        default: begin
          state_q <= ST_IDLE;
        end
      endcase
    end
  end

endmodule
