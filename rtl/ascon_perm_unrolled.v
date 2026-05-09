`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Parameterized ASCON permutation controller.
//
// This module applies p[12], p[8], or p[6] to a 320-bit state. The datapath
// can be partially or fully unrolled by changing ROUNDS_PER_CYCLE.
//
// ROUNDS_PER_CYCLE = 1  -> one round per cycle, easiest timing
// ROUNDS_PER_CYCLE = 2  -> moderate unroll
// ROUNDS_PER_CYCLE = 4  -> high-throughput baseline
// ROUNDS_PER_CYCLE = 8  -> one p[8] bulk-message permutation per cycle
//
// The module is intentionally bus-agnostic. Later repositories/wrappers should
// connect this to NEORV32 CFS/XBUS/SLINK, AXI, or Tiny Tapeout IOs.

module ascon_perm_unrolled #(
  parameter integer ROUNDS_PER_CYCLE = 1
) (
  input  wire         clk,
  input  wire         rst_n,

  input  wire         start_i,
  input  wire [3:0]   rounds_i,
  input  wire [319:0] state_i,

  output reg          busy_o,
  output reg          done_o,
  output reg  [319:0] state_o
);

  localparam integer RPC_INT =
    (ROUNDS_PER_CYCLE < 1) ? 1 :
    (ROUNDS_PER_CYCLE > 8) ? 8 : ROUNDS_PER_CYCLE;

  localparam [3:0] RPC = RPC_INT;

  reg [3:0] rounds_r;
  reg [3:0] round_ctr_r;

  function [7:0] rc_lut;
    input [3:0] idx;
    begin
      case (idx)
        4'd0:    rc_lut = 8'hf0;
        4'd1:    rc_lut = 8'he1;
        4'd2:    rc_lut = 8'hd2;
        4'd3:    rc_lut = 8'hc3;
        4'd4:    rc_lut = 8'hb4;
        4'd5:    rc_lut = 8'ha5;
        4'd6:    rc_lut = 8'h96;
        4'd7:    rc_lut = 8'h87;
        4'd8:    rc_lut = 8'h78;
        4'd9:    rc_lut = 8'h69;
        4'd10:   rc_lut = 8'h5a;
        4'd11:   rc_lut = 8'h4b;
        default: rc_lut = 8'h00;
      endcase
    end
  endfunction

  function [3:0] sanitize_rounds;
    input [3:0] rounds;
    begin
      case (rounds)
        4'd6:    sanitize_rounds = 4'd6;
        4'd8:    sanitize_rounds = 4'd8;
        4'd12:   sanitize_rounds = 4'd12;
        default: sanitize_rounds = 4'd12;
      endcase
    end
  endfunction

  wire [3:0] remaining_w  = rounds_r - round_ctr_r;
  wire [3:0] step_count_w = (remaining_w > RPC) ? RPC : remaining_w;
  wire [3:0] rc_base_w    = (4'd12 - rounds_r) + round_ctr_r;

  wire [319:0] r0_state_w;
  wire [319:0] r1_state_w;
  wire [319:0] r2_state_w;
  wire [319:0] r3_state_w;
  wire [319:0] r4_state_w;
  wire [319:0] r5_state_w;
  wire [319:0] r6_state_w;
  wire [319:0] r7_state_w;

  ascon_round_comb u_round0 (.state_i(state_o),    .rc_i(rc_lut(rc_base_w + 4'd0)), .state_o(r0_state_w));
  ascon_round_comb u_round1 (.state_i(r0_state_w), .rc_i(rc_lut(rc_base_w + 4'd1)), .state_o(r1_state_w));
  ascon_round_comb u_round2 (.state_i(r1_state_w), .rc_i(rc_lut(rc_base_w + 4'd2)), .state_o(r2_state_w));
  ascon_round_comb u_round3 (.state_i(r2_state_w), .rc_i(rc_lut(rc_base_w + 4'd3)), .state_o(r3_state_w));
  ascon_round_comb u_round4 (.state_i(r3_state_w), .rc_i(rc_lut(rc_base_w + 4'd4)), .state_o(r4_state_w));
  ascon_round_comb u_round5 (.state_i(r4_state_w), .rc_i(rc_lut(rc_base_w + 4'd5)), .state_o(r5_state_w));
  ascon_round_comb u_round6 (.state_i(r5_state_w), .rc_i(rc_lut(rc_base_w + 4'd6)), .state_o(r6_state_w));
  ascon_round_comb u_round7 (.state_i(r6_state_w), .rc_i(rc_lut(rc_base_w + 4'd7)), .state_o(r7_state_w));

  reg [319:0] step_state_w;

  always @(*) begin
    case (step_count_w)
      4'd0:    step_state_w = state_o;
      4'd1:    step_state_w = r0_state_w;
      4'd2:    step_state_w = r1_state_w;
      4'd3:    step_state_w = r2_state_w;
      4'd4:    step_state_w = r3_state_w;
      4'd5:    step_state_w = r4_state_w;
      4'd6:    step_state_w = r5_state_w;
      4'd7:    step_state_w = r6_state_w;
      default: step_state_w = r7_state_w;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rounds_r    <= 4'd0;
      round_ctr_r <= 4'd0;
      busy_o      <= 1'b0;
      done_o      <= 1'b0;
      state_o     <= 320'd0;
    end else begin
      done_o <= 1'b0;

      if (start_i && !busy_o) begin
        rounds_r    <= sanitize_rounds(rounds_i);
        round_ctr_r <= 4'd0;
        busy_o      <= 1'b1;
        state_o     <= state_i;
      end else if (busy_o) begin
        state_o <= step_state_w;

        if ((round_ctr_r + step_count_w) >= rounds_r) begin
          rounds_r    <= 4'd0;
          round_ctr_r <= 4'd0;
          busy_o      <= 1'b0;
          done_o      <= 1'b1;
        end else begin
          round_ctr_r <= round_ctr_r + step_count_w;
        end
      end
    end
  end

endmodule
