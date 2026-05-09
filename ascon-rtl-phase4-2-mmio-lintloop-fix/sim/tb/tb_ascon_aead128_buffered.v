`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0

`include "ascon_aead128_ad_vectors.vh"

module tb_ascon_aead128_buffered;
  parameter integer RPC = 1;
  parameter integer DECRYPT = 0;

  reg clk;
  reg rst_n;
  reg clear_i;

  reg start_i;
  wire start_ready_o;
  reg [127:0] key_i;
  reg [127:0] nonce_i;
  reg [31:0] ad_bytes_i;
  reg [31:0] msg_bytes_i;
  reg [127:0] tag_i;
  wire busy_o;
  wire done_o;

  reg ad_in_valid_i;
  wire ad_in_ready_o;
  reg [127:0] ad_in_block_i;

  reg data_in_valid_i;
  wire data_in_ready_o;
  reg [127:0] data_in_block_i;

  wire data_out_valid_o;
  reg data_out_ready_i;
  wire [127:0] data_out_block_o;
  wire [4:0] data_out_bytes_o;

  wire result_valid_o;
  reg result_ready_i;
  wire [127:0] result_tag_o;
  wire result_auth_ok_o;

  wire ad_fifo_empty_o;
  wire ad_fifo_full_o;
  wire [2:0] ad_fifo_level_o;
  wire data_in_fifo_empty_o;
  wire data_in_fifo_full_o;
  wire [2:0] data_in_fifo_level_o;
  wire data_out_fifo_empty_o;
  wire data_out_fifo_full_o;
  wire [2:0] data_out_fifo_level_o;

  integer errors;

  ascon_aead128_buffered #(
    .DECRYPT(DECRYPT),
    .ROUNDS_PER_CYCLE(RPC),
    .AD_FIFO_DEPTH_LOG2(2),
    .IN_FIFO_DEPTH_LOG2(2),
    .OUT_FIFO_DEPTH_LOG2(2)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .clear_i(clear_i),
    .start_i(start_i),
    .start_ready_o(start_ready_o),
    .key_i(key_i),
    .nonce_i(nonce_i),
    .ad_bytes_i(ad_bytes_i),
    .msg_bytes_i(msg_bytes_i),
    .tag_i(tag_i),
    .busy_o(busy_o),
    .done_o(done_o),
    .ad_in_valid_i(ad_in_valid_i),
    .ad_in_ready_o(ad_in_ready_o),
    .ad_in_block_i(ad_in_block_i),
    .data_in_valid_i(data_in_valid_i),
    .data_in_ready_o(data_in_ready_o),
    .data_in_block_i(data_in_block_i),
    .data_out_valid_o(data_out_valid_o),
    .data_out_ready_i(data_out_ready_i),
    .data_out_block_o(data_out_block_o),
    .data_out_bytes_o(data_out_bytes_o),
    .result_valid_o(result_valid_o),
    .result_ready_i(result_ready_i),
    .result_tag_o(result_tag_o),
    .result_auth_ok_o(result_auth_ok_o),
    .ad_fifo_empty_o(ad_fifo_empty_o),
    .ad_fifo_full_o(ad_fifo_full_o),
    .ad_fifo_level_o(ad_fifo_level_o),
    .data_in_fifo_empty_o(data_in_fifo_empty_o),
    .data_in_fifo_full_o(data_in_fifo_full_o),
    .data_in_fifo_level_o(data_in_fifo_level_o),
    .data_out_fifo_empty_o(data_out_fifo_empty_o),
    .data_out_fifo_full_o(data_out_fifo_full_o),
    .data_out_fifo_level_o(data_out_fifo_level_o)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task reset_dut;
    begin
      rst_n <= 1'b0;
      clear_i <= 1'b0;
      start_i <= 1'b0;
      key_i <= 128'd0;
      nonce_i <= 128'd0;
      ad_bytes_i <= 32'd0;
      msg_bytes_i <= 32'd0;
      tag_i <= 128'd0;
      ad_in_valid_i <= 1'b0;
      ad_in_block_i <= 128'd0;
      data_in_valid_i <= 1'b0;
      data_in_block_i <= 128'd0;
      data_out_ready_i <= 1'b0;
      result_ready_i <= 1'b0;
      repeat (5) @(posedge clk);
      rst_n <= 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  function integer block_count;
    input integer len;
    begin
      block_count = (len + 15) / 16;
    end
  endfunction

  function [4:0] block_bytes;
    input integer len;
    input integer idx;
    integer remaining;
    begin
      remaining = len - (idx * 16);
      if (remaining >= 16) begin
        block_bytes = 5'd16;
      end else if (remaining > 0) begin
        block_bytes = remaining[4:0];
      end else begin
        block_bytes = 5'd0;
      end
    end
  endfunction

  function integer pick_ad_len;
    input integer case_idx;
    begin
      case (case_idx)
        7: pick_ad_len = VEC_AEAD_AD_C7_AD_BYTES;
        8: pick_ad_len = VEC_AEAD_AD_C8_AD_BYTES;
        default: pick_ad_len = VEC_AEAD_AD_C2_AD_BYTES;
      endcase
    end
  endfunction

  function integer pick_msg_len;
    input integer case_idx;
    begin
      case (case_idx)
        7: pick_msg_len = VEC_AEAD_AD_C7_MSG_BYTES;
        8: pick_msg_len = VEC_AEAD_AD_C8_MSG_BYTES;
        default: pick_msg_len = VEC_AEAD_AD_C2_MSG_BYTES;
      endcase
    end
  endfunction

  function [127:0] pick_ad;
    input integer case_idx;
    input integer block_idx;
    begin
      pick_ad = 128'd0;
      case (case_idx)
        7: pick_ad = (block_idx == 0) ? VEC_AEAD_AD_C7_AD0 : VEC_AEAD_AD_C7_AD1;
        8: pick_ad = (block_idx == 0) ? VEC_AEAD_AD_C8_AD0 : VEC_AEAD_AD_C8_AD1;
        default: pick_ad = VEC_AEAD_AD_C2_AD0;
      endcase
    end
  endfunction

  function [127:0] pick_pt;
    input integer case_idx;
    input integer block_idx;
    begin
      pick_pt = 128'd0;
      case (case_idx)
        7: pick_pt = (block_idx == 0) ? VEC_AEAD_AD_C7_PT0 : VEC_AEAD_AD_C7_PT1;
        8: pick_pt = (block_idx == 0) ? VEC_AEAD_AD_C8_PT0 : VEC_AEAD_AD_C8_PT1;
        default: pick_pt = VEC_AEAD_AD_C2_PT0;
      endcase
    end
  endfunction

  function [127:0] pick_ct;
    input integer case_idx;
    input integer block_idx;
    begin
      pick_ct = 128'd0;
      case (case_idx)
        7: pick_ct = (block_idx == 0) ? VEC_AEAD_AD_C7_CT0 : VEC_AEAD_AD_C7_CT1;
        8: pick_ct = (block_idx == 0) ? VEC_AEAD_AD_C8_CT0 : VEC_AEAD_AD_C8_CT1;
        default: pick_ct = VEC_AEAD_AD_C2_CT0;
      endcase
    end
  endfunction

  function [127:0] pick_tag;
    input integer case_idx;
    begin
      pick_tag = 128'd0;
      case (case_idx)
        7: pick_tag = VEC_AEAD_AD_C7_TAG;
        8: pick_tag = VEC_AEAD_AD_C8_TAG;
        default: pick_tag = VEC_AEAD_AD_C2_TAG;
      endcase
    end
  endfunction

  function [127:0] expected_input_block;
    input integer case_idx;
    input integer block_idx;
    begin
      expected_input_block = (DECRYPT == 0) ? pick_pt(case_idx, block_idx) : pick_ct(case_idx, block_idx);
    end
  endfunction

  function [127:0] expected_output_block;
    input integer case_idx;
    input integer block_idx;
    begin
      expected_output_block = (DECRYPT == 0) ? pick_ct(case_idx, block_idx) : pick_pt(case_idx, block_idx);
    end
  endfunction

  task push_ad_block;
    input [127:0] block;
    reg fire;
    begin
      fire = 1'b0;
      while (!fire) begin
        @(negedge clk);
        ad_in_block_i = block;
        ad_in_valid_i = 1'b1;
        #1;
        fire = ad_in_valid_i && ad_in_ready_o;
        @(posedge clk);
        #1;
      end
      @(negedge clk);
      ad_in_valid_i = 1'b0;
      ad_in_block_i = 128'd0;
    end
  endtask

  task push_data_block;
    input [127:0] block;
    reg fire;
    begin
      fire = 1'b0;
      while (!fire) begin
        @(negedge clk);
        data_in_block_i = block;
        data_in_valid_i = 1'b1;
        #1;
        fire = data_in_valid_i && data_in_ready_o;
        @(posedge clk);
        #1;
      end
      @(negedge clk);
      data_in_valid_i = 1'b0;
      data_in_block_i = 128'd0;
    end
  endtask

  task run_case;
    input integer case_idx;
    integer cycles;
    integer ad_len;
    integer msg_len;
    integer ad_blocks;
    integer msg_blocks;
    integer i;
    integer data_recv_idx;
    integer saw_result;
    integer done_seen;
    reg failed;
    reg data_fire;
    reg result_fire;
    reg [127:0] data_sample;
    reg [4:0] data_bytes_sample;
    reg [127:0] result_tag_sample;
    reg result_ok_sample;
    begin
      cycles = 0;
      ad_len = pick_ad_len(case_idx);
      msg_len = pick_msg_len(case_idx);
      ad_blocks = block_count(ad_len);
      msg_blocks = block_count(msg_len);
      data_recv_idx = 0;
      saw_result = 0;
      done_seen = 0;
      failed = 1'b0;

      for (i = 0; i < ad_blocks; i = i + 1) begin
        push_ad_block(pick_ad(case_idx, i));
      end
      for (i = 0; i < msg_blocks; i = i + 1) begin
        push_data_block(expected_input_block(case_idx, i));
      end

      @(negedge clk);
      key_i = VEC_AEAD_AD_KEY;
      nonce_i = VEC_AEAD_AD_NONCE;
      ad_bytes_i = ad_len[31:0];
      msg_bytes_i = msg_len[31:0];
      tag_i = pick_tag(case_idx);
      start_i = 1'b1;
      #1;
      if (!start_ready_o) begin
        $display("FAIL wrapper case%0d mode=%0d RPC=%0d start_ready_o low", case_idx, DECRYPT, RPC);
        failed = 1'b1;
      end
      @(posedge clk);
      #1;
      start_i = 1'b0;

      while (!done_seen && cycles < 10000) begin
        @(negedge clk);
        cycles = cycles + 1;
        data_out_ready_i = ((cycles % 7) != 2) && ((cycles % 11) != 4);
        result_ready_i = ((cycles % 5) != 3);
        #1;
        data_fire = data_out_valid_o && data_out_ready_i;
        result_fire = result_valid_o && result_ready_i;
        data_sample = data_out_block_o;
        data_bytes_sample = data_out_bytes_o;
        result_tag_sample = result_tag_o;
        result_ok_sample = result_auth_ok_o;
        @(posedge clk);
        #1;

        if (data_fire) begin
          if (data_recv_idx >= msg_blocks) begin
            $display("FAIL wrapper case%0d mode=%0d RPC=%0d unexpected data %032x", case_idx, DECRYPT, RPC, data_sample);
            failed = 1'b1;
          end else if (data_sample !== expected_output_block(case_idx, data_recv_idx)) begin
            $display("FAIL wrapper case%0d mode=%0d RPC=%0d data%0d got=%032x exp=%032x",
                     case_idx, DECRYPT, RPC, data_recv_idx, data_sample,
                     expected_output_block(case_idx, data_recv_idx));
            failed = 1'b1;
          end else if (data_bytes_sample !== block_bytes(msg_len, data_recv_idx)) begin
            $display("FAIL wrapper case%0d mode=%0d RPC=%0d data%0d bytes got=%0d exp=%0d",
                     case_idx, DECRYPT, RPC, data_recv_idx, data_bytes_sample,
                     block_bytes(msg_len, data_recv_idx));
            failed = 1'b1;
          end
          data_recv_idx = data_recv_idx + 1;
        end

        if (result_fire) begin
          saw_result = 1;
          if (DECRYPT == 0) begin
            if (result_tag_sample !== pick_tag(case_idx)) begin
              $display("FAIL wrapper case%0d mode=%0d RPC=%0d tag got=%032x exp=%032x",
                       case_idx, DECRYPT, RPC, result_tag_sample, pick_tag(case_idx));
              failed = 1'b1;
            end
            if (result_ok_sample !== 1'b1) begin
              $display("FAIL wrapper case%0d mode=%0d RPC=%0d encryption auth_ok low", case_idx, DECRYPT, RPC);
              failed = 1'b1;
            end
          end else begin
            if (result_tag_sample !== 128'd0) begin
              $display("FAIL wrapper case%0d mode=%0d RPC=%0d decrypt result_tag nonzero %032x",
                       case_idx, DECRYPT, RPC, result_tag_sample);
              failed = 1'b1;
            end
            if (result_ok_sample !== 1'b1) begin
              $display("FAIL wrapper case%0d mode=%0d RPC=%0d decrypt auth failed", case_idx, DECRYPT, RPC);
              failed = 1'b1;
            end
          end
        end

        if (done_o) begin
          done_seen = 1;
        end
      end

      data_out_ready_i = 1'b0;
      result_ready_i = 1'b0;

      if (!done_seen) begin
        $display("FAIL wrapper case%0d mode=%0d RPC=%0d timeout", case_idx, DECRYPT, RPC);
        failed = 1'b1;
      end
      if (data_recv_idx != msg_blocks) begin
        $display("FAIL wrapper case%0d mode=%0d RPC=%0d output count got=%0d exp=%0d",
                 case_idx, DECRYPT, RPC, data_recv_idx, msg_blocks);
        failed = 1'b1;
      end
      if (!saw_result) begin
        $display("FAIL wrapper case%0d mode=%0d RPC=%0d no result", case_idx, DECRYPT, RPC);
        failed = 1'b1;
      end

      if (failed) begin
        errors = errors + 1;
      end else begin
        $display("PASS wrapper case%0d mode=%0d RPC=%0d cycles=%0d", case_idx, DECRYPT, RPC, cycles);
      end

      @(negedge clk);
      clear_i = 1'b1;
      @(posedge clk);
      @(negedge clk);
      clear_i = 1'b0;
      repeat (2) @(posedge clk);
    end
  endtask

  initial begin
    errors = 0;
    reset_dut();
    run_case(7);
    run_case(8);

    if (errors == 0) begin
      $display("ALL UNIFIED BUFFERED AEAD WRAPPER TESTS PASSED mode=%0d RPC=%0d", DECRYPT, RPC);
      $finish;
    end else begin
      $display("UNIFIED BUFFERED AEAD WRAPPER TESTS FAILED mode=%0d RPC=%0d errors=%0d", DECRYPT, RPC, errors);
      $fatal;
    end
  end
endmodule
