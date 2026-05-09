`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0

`include "ascon_aead128_ad_vectors.vh"

`default_nettype none

module tb_ascon_aead128_axis;
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

  reg          s_axis_ad_tvalid_i;
  wire         s_axis_ad_tready_o;
  reg  [127:0] s_axis_ad_tdata_i;
  reg  [15:0]  s_axis_ad_tkeep_i;
  reg          s_axis_ad_tlast_i;
  wire         s_axis_ad_keep_error_o;

  reg          s_axis_data_tvalid_i;
  wire         s_axis_data_tready_o;
  reg  [127:0] s_axis_data_tdata_i;
  reg  [15:0]  s_axis_data_tkeep_i;
  reg          s_axis_data_tlast_i;
  wire         s_axis_data_keep_error_o;

  wire         m_axis_data_tvalid_o;
  reg          m_axis_data_tready_i;
  wire [127:0] m_axis_data_tdata_o;
  wire [15:0]  m_axis_data_tkeep_o;
  wire         m_axis_data_tlast_o;

  wire         result_valid_o;
  reg          result_ready_i;
  wire [127:0] result_tag_o;
  wire         result_auth_ok_o;

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

  ascon_aead128_axis #(
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

    .s_axis_ad_tvalid_i(s_axis_ad_tvalid_i),
    .s_axis_ad_tready_o(s_axis_ad_tready_o),
    .s_axis_ad_tdata_i(s_axis_ad_tdata_i),
    .s_axis_ad_tkeep_i(s_axis_ad_tkeep_i),
    .s_axis_ad_tlast_i(s_axis_ad_tlast_i),
    .s_axis_ad_keep_error_o(s_axis_ad_keep_error_o),

    .s_axis_data_tvalid_i(s_axis_data_tvalid_i),
    .s_axis_data_tready_o(s_axis_data_tready_o),
    .s_axis_data_tdata_i(s_axis_data_tdata_i),
    .s_axis_data_tkeep_i(s_axis_data_tkeep_i),
    .s_axis_data_tlast_i(s_axis_data_tlast_i),
    .s_axis_data_keep_error_o(s_axis_data_keep_error_o),

    .m_axis_data_tvalid_o(m_axis_data_tvalid_o),
    .m_axis_data_tready_i(m_axis_data_tready_i),
    .m_axis_data_tdata_o(m_axis_data_tdata_o),
    .m_axis_data_tkeep_o(m_axis_data_tkeep_o),
    .m_axis_data_tlast_o(m_axis_data_tlast_o),

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

  function [15:0] keep_from_bytes;
    input [4:0] bytes;
    begin
      case (bytes)
        5'd0:  keep_from_bytes = 16'h0000;
        5'd1:  keep_from_bytes = 16'h0001;
        5'd2:  keep_from_bytes = 16'h0003;
        5'd3:  keep_from_bytes = 16'h0007;
        5'd4:  keep_from_bytes = 16'h000f;
        5'd5:  keep_from_bytes = 16'h001f;
        5'd6:  keep_from_bytes = 16'h003f;
        5'd7:  keep_from_bytes = 16'h007f;
        5'd8:  keep_from_bytes = 16'h00ff;
        5'd9:  keep_from_bytes = 16'h01ff;
        5'd10: keep_from_bytes = 16'h03ff;
        5'd11: keep_from_bytes = 16'h07ff;
        5'd12: keep_from_bytes = 16'h0fff;
        5'd13: keep_from_bytes = 16'h1fff;
        5'd14: keep_from_bytes = 16'h3fff;
        5'd15: keep_from_bytes = 16'h7fff;
        default: keep_from_bytes = 16'hffff;
      endcase
    end
  endfunction

  function [127:0] block_to_axis_ref;
    input [127:0] block;
    begin
      block_to_axis_ref[31:0]   = block[95:64];
      block_to_axis_ref[63:32]  = block[127:96];
      block_to_axis_ref[95:64]  = block[31:0];
      block_to_axis_ref[127:96] = block[63:32];
    end
  endfunction

  function [127:0] mask_axis_ref;
    input [127:0] data;
    input [15:0]  keep;
    integer i;
    begin
      mask_axis_ref = 128'd0;
      for (i = 0; i < 16; i = i + 1) begin
        if (keep[i]) begin
          mask_axis_ref[(8*i)+:8] = data[(8*i)+:8];
        end
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

      s_axis_ad_tvalid_i <= 1'b0;
      s_axis_ad_tdata_i <= 128'd0;
      s_axis_ad_tkeep_i <= 16'd0;
      s_axis_ad_tlast_i <= 1'b0;

      s_axis_data_tvalid_i <= 1'b0;
      s_axis_data_tdata_i <= 128'd0;
      s_axis_data_tkeep_i <= 16'd0;
      s_axis_data_tlast_i <= 1'b0;

      m_axis_data_tready_i <= 1'b0;
      result_ready_i <= 1'b0;

      repeat (5) @(posedge clk);
      rst_n <= 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  task push_ad_axis;
    input [127:0] block;
    input [4:0] bytes;
    input last;
    reg fire;
    begin
      fire = 1'b0;
      while (!fire) begin
        @(negedge clk);
        s_axis_ad_tdata_i = block_to_axis_ref(block);
        s_axis_ad_tkeep_i = keep_from_bytes(bytes);
        s_axis_ad_tlast_i = last;
        s_axis_ad_tvalid_i = 1'b1;
        #1;
        fire = s_axis_ad_tvalid_i && s_axis_ad_tready_o;
        if (s_axis_ad_keep_error_o) begin
          $display("FAIL axis mode=%0d RPC=%0d unexpected AD keep error", DECRYPT, RPC);
          errors = errors + 1;
        end
        @(posedge clk);
        #1;
      end
      @(negedge clk);
      s_axis_ad_tvalid_i = 1'b0;
      s_axis_ad_tdata_i = 128'd0;
      s_axis_ad_tkeep_i = 16'd0;
      s_axis_ad_tlast_i = 1'b0;
    end
  endtask

  task push_data_axis;
    input [127:0] block;
    input [4:0] bytes;
    input last;
    reg fire;
    begin
      fire = 1'b0;
      while (!fire) begin
        @(negedge clk);
        s_axis_data_tdata_i = block_to_axis_ref(block);
        s_axis_data_tkeep_i = keep_from_bytes(bytes);
        s_axis_data_tlast_i = last;
        s_axis_data_tvalid_i = 1'b1;
        #1;
        fire = s_axis_data_tvalid_i && s_axis_data_tready_o;
        if (s_axis_data_keep_error_o) begin
          $display("FAIL axis mode=%0d RPC=%0d unexpected DATA keep error", DECRYPT, RPC);
          errors = errors + 1;
        end
        @(posedge clk);
        #1;
      end
      @(negedge clk);
      s_axis_data_tvalid_i = 1'b0;
      s_axis_data_tdata_i = 128'd0;
      s_axis_data_tkeep_i = 16'd0;
      s_axis_data_tlast_i = 1'b0;
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
    integer out_idx;
    integer saw_result;
    integer done_seen;
    reg failed;
    reg out_fire;
    reg result_fire;
    reg [127:0] out_data_sample;
    reg [15:0] out_keep_sample;
    reg out_last_sample;
    reg [127:0] result_tag_sample;
    reg result_ok_sample;
    reg [15:0] exp_keep;
    reg [127:0] exp_data;
    begin
      cycles = 0;
      ad_len = pick_ad_len(case_idx);
      msg_len = pick_msg_len(case_idx);
      ad_blocks = block_count(ad_len);
      msg_blocks = block_count(msg_len);
      out_idx = 0;
      saw_result = 0;
      done_seen = 0;
      failed = 1'b0;

      for (i = 0; i < ad_blocks; i = i + 1) begin
        push_ad_axis(pick_ad(case_idx, i), block_bytes(ad_len, i), (i == (ad_blocks - 1)));
      end

      for (i = 0; i < msg_blocks; i = i + 1) begin
        push_data_axis(expected_input_block(case_idx, i), block_bytes(msg_len, i), (i == (msg_blocks - 1)));
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
        $display("FAIL axis case%0d mode=%0d RPC=%0d start_ready_o low", case_idx, DECRYPT, RPC);
        failed = 1'b1;
      end
      @(posedge clk);
      #1;
      start_i = 1'b0;

      while (!done_seen && cycles < 10000) begin
        @(negedge clk);
        cycles = cycles + 1;
        m_axis_data_tready_i = ((cycles % 7) != 2) && ((cycles % 11) != 4);
        result_ready_i = ((cycles % 5) != 3);
        #1;
        out_fire = m_axis_data_tvalid_o && m_axis_data_tready_i;
        result_fire = result_valid_o && result_ready_i;
        out_data_sample = m_axis_data_tdata_o;
        out_keep_sample = m_axis_data_tkeep_o;
        out_last_sample = m_axis_data_tlast_o;
        result_tag_sample = result_tag_o;
        result_ok_sample = result_auth_ok_o;
        @(posedge clk);
        #1;

        if (out_fire) begin
          if (out_idx >= msg_blocks) begin
            $display("FAIL axis case%0d mode=%0d RPC=%0d unexpected output %032x",
                     case_idx, DECRYPT, RPC, out_data_sample);
            failed = 1'b1;
          end else begin
            exp_keep = keep_from_bytes(block_bytes(msg_len, out_idx));
            exp_data = mask_axis_ref(block_to_axis_ref(expected_output_block(case_idx, out_idx)), exp_keep);

            if (out_data_sample !== exp_data) begin
              $display("FAIL axis case%0d mode=%0d RPC=%0d out%0d data got=%032x exp=%032x",
                       case_idx, DECRYPT, RPC, out_idx, out_data_sample, exp_data);
              failed = 1'b1;
            end
            if (out_keep_sample !== exp_keep) begin
              $display("FAIL axis case%0d mode=%0d RPC=%0d out%0d keep got=%04x exp=%04x",
                       case_idx, DECRYPT, RPC, out_idx, out_keep_sample, exp_keep);
              failed = 1'b1;
            end
            if (out_last_sample !== (out_idx == (msg_blocks - 1))) begin
              $display("FAIL axis case%0d mode=%0d RPC=%0d out%0d last got=%0d exp=%0d",
                       case_idx, DECRYPT, RPC, out_idx, out_last_sample, (out_idx == (msg_blocks - 1)));
              failed = 1'b1;
            end
          end
          out_idx = out_idx + 1;
        end

        if (result_fire) begin
          saw_result = 1;
          if (DECRYPT == 0) begin
            if (result_tag_sample !== pick_tag(case_idx)) begin
              $display("FAIL axis case%0d mode=%0d RPC=%0d tag got=%032x exp=%032x",
                       case_idx, DECRYPT, RPC, result_tag_sample, pick_tag(case_idx));
              failed = 1'b1;
            end
            if (result_ok_sample !== 1'b1) begin
              $display("FAIL axis case%0d mode=%0d RPC=%0d encryption auth_ok low", case_idx, DECRYPT, RPC);
              failed = 1'b1;
            end
          end else begin
            if (result_tag_sample !== 128'd0) begin
              $display("FAIL axis case%0d mode=%0d RPC=%0d decrypt result tag nonzero %032x",
                       case_idx, DECRYPT, RPC, result_tag_sample);
              failed = 1'b1;
            end
            if (result_ok_sample !== 1'b1) begin
              $display("FAIL axis case%0d mode=%0d RPC=%0d decrypt auth failed", case_idx, DECRYPT, RPC);
              failed = 1'b1;
            end
          end
        end

        if (done_o) begin
          done_seen = 1;
        end
      end

      m_axis_data_tready_i = 1'b0;
      result_ready_i = 1'b0;

      if (!done_seen) begin
        $display("FAIL axis case%0d mode=%0d RPC=%0d timeout", case_idx, DECRYPT, RPC);
        failed = 1'b1;
      end
      if (out_idx != msg_blocks) begin
        $display("FAIL axis case%0d mode=%0d RPC=%0d output count got=%0d exp=%0d",
                 case_idx, DECRYPT, RPC, out_idx, msg_blocks);
        failed = 1'b1;
      end
      if (!saw_result) begin
        $display("FAIL axis case%0d mode=%0d RPC=%0d no result", case_idx, DECRYPT, RPC);
        failed = 1'b1;
      end

      if (failed) begin
        errors = errors + 1;
      end else begin
        $display("PASS AXIS case%0d mode=%0d RPC=%0d cycles=%0d", case_idx, DECRYPT, RPC, cycles);
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
      $display("ALL AXIS AEAD WRAPPER TESTS PASSED mode=%0d RPC=%0d", DECRYPT, RPC);
      $finish;
    end else begin
      $display("AXIS AEAD WRAPPER TESTS FAILED mode=%0d RPC=%0d errors=%0d", DECRYPT, RPC, errors);
      $fatal;
    end
  end

endmodule

`default_nettype wire
