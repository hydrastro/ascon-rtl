`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0

`include "ascon_aead128_ad_vectors.vh"

module tb_ascon_aead128_dec_ad;
  parameter integer RPC = 1;

  reg clk;
  reg rst_n;
  reg start_i;
  reg [127:0] key_i;
  reg [127:0] nonce_i;
  reg [31:0] ad_bytes_i;
  reg [31:0] msg_bytes_i;
  reg [127:0] tag_i;
  wire busy_o;
  wire done_o;

  wire ad_ready_o;
  reg ad_valid_i;
  reg [127:0] ad_block_i;

  wire ciphertext_ready_o;
  reg ciphertext_valid_i;
  reg [127:0] ciphertext_block_i;

  wire plaintext_valid_o;
  reg plaintext_ready_i;
  wire [127:0] plaintext_block_o;
  wire [4:0] plaintext_bytes_o;

  wire auth_valid_o;
  reg auth_ready_i;
  wire auth_ok_o;

  integer errors;

  ascon_aead128_dec_ad #(
    .ROUNDS_PER_CYCLE(RPC)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .start_i(start_i),
    .key_i(key_i),
    .nonce_i(nonce_i),
    .ad_bytes_i(ad_bytes_i),
    .msg_bytes_i(msg_bytes_i),
    .tag_i(tag_i),
    .busy_o(busy_o),
    .done_o(done_o),
    .ad_ready_o(ad_ready_o),
    .ad_valid_i(ad_valid_i),
    .ad_block_i(ad_block_i),
    .ciphertext_ready_o(ciphertext_ready_o),
    .ciphertext_valid_i(ciphertext_valid_i),
    .ciphertext_block_i(ciphertext_block_i),
    .plaintext_valid_o(plaintext_valid_o),
    .plaintext_ready_i(plaintext_ready_i),
    .plaintext_block_o(plaintext_block_o),
    .plaintext_bytes_o(plaintext_bytes_o),
    .auth_valid_o(auth_valid_o),
    .auth_ready_i(auth_ready_i),
    .auth_ok_o(auth_ok_o)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task reset_dut;
    begin
      rst_n <= 1'b0;
      start_i <= 1'b0;
      key_i <= 128'd0;
      nonce_i <= 128'd0;
      ad_bytes_i <= 32'd0;
      msg_bytes_i <= 32'd0;
      tag_i <= 128'd0;
      ad_valid_i <= 1'b0;
      ad_block_i <= 128'd0;
      ciphertext_valid_i <= 1'b0;
      ciphertext_block_i <= 128'd0;
      plaintext_ready_i <= 1'b1;
      auth_ready_i <= 1'b1;
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
        0: pick_ad_len = VEC_AEAD_AD_C0_AD_BYTES;
        1: pick_ad_len = VEC_AEAD_AD_C1_AD_BYTES;
        2: pick_ad_len = VEC_AEAD_AD_C2_AD_BYTES;
        3: pick_ad_len = VEC_AEAD_AD_C3_AD_BYTES;
        4: pick_ad_len = VEC_AEAD_AD_C4_AD_BYTES;
        5: pick_ad_len = VEC_AEAD_AD_C5_AD_BYTES;
        6: pick_ad_len = VEC_AEAD_AD_C6_AD_BYTES;
        7: pick_ad_len = VEC_AEAD_AD_C7_AD_BYTES;
        8: pick_ad_len = VEC_AEAD_AD_C8_AD_BYTES;
        9: pick_ad_len = VEC_AEAD_AD_C9_AD_BYTES;
        default: pick_ad_len = 0;
      endcase
    end
  endfunction

  function integer pick_msg_len;
    input integer case_idx;
    begin
      case (case_idx)
        0: pick_msg_len = VEC_AEAD_AD_C0_MSG_BYTES;
        1: pick_msg_len = VEC_AEAD_AD_C1_MSG_BYTES;
        2: pick_msg_len = VEC_AEAD_AD_C2_MSG_BYTES;
        3: pick_msg_len = VEC_AEAD_AD_C3_MSG_BYTES;
        4: pick_msg_len = VEC_AEAD_AD_C4_MSG_BYTES;
        5: pick_msg_len = VEC_AEAD_AD_C5_MSG_BYTES;
        6: pick_msg_len = VEC_AEAD_AD_C6_MSG_BYTES;
        7: pick_msg_len = VEC_AEAD_AD_C7_MSG_BYTES;
        8: pick_msg_len = VEC_AEAD_AD_C8_MSG_BYTES;
        9: pick_msg_len = VEC_AEAD_AD_C9_MSG_BYTES;
        default: pick_msg_len = 0;
      endcase
    end
  endfunction

  function [127:0] pick_ad;
    input integer case_idx;
    input integer block_idx;
    begin
      pick_ad = 128'd0;
      case (case_idx)
        1: pick_ad = VEC_AEAD_AD_C1_AD0;
        2: pick_ad = VEC_AEAD_AD_C2_AD0;
        3: pick_ad = VEC_AEAD_AD_C3_AD0;
        4: pick_ad = VEC_AEAD_AD_C4_AD0;
        5: pick_ad = VEC_AEAD_AD_C5_AD0;
        6: pick_ad = VEC_AEAD_AD_C6_AD0;
        7: pick_ad = (block_idx == 0) ? VEC_AEAD_AD_C7_AD0 : VEC_AEAD_AD_C7_AD1;
        8: pick_ad = (block_idx == 0) ? VEC_AEAD_AD_C8_AD0 : VEC_AEAD_AD_C8_AD1;
        9: pick_ad = (block_idx == 0) ? VEC_AEAD_AD_C9_AD0 : VEC_AEAD_AD_C9_AD1;
        default: pick_ad = 128'd0;
      endcase
    end
  endfunction

  function [127:0] pick_pt;
    input integer case_idx;
    input integer block_idx;
    begin
      pick_pt = 128'd0;
      case (case_idx)
        2: pick_pt = VEC_AEAD_AD_C2_PT0;
        3: pick_pt = VEC_AEAD_AD_C3_PT0;
        4: pick_pt = VEC_AEAD_AD_C4_PT0;
        5: pick_pt = VEC_AEAD_AD_C5_PT0;
        6: pick_pt = VEC_AEAD_AD_C6_PT0;
        7: pick_pt = (block_idx == 0) ? VEC_AEAD_AD_C7_PT0 : VEC_AEAD_AD_C7_PT1;
        8: pick_pt = (block_idx == 0) ? VEC_AEAD_AD_C8_PT0 : VEC_AEAD_AD_C8_PT1;
        9: pick_pt = (block_idx == 0) ? VEC_AEAD_AD_C9_PT0 : VEC_AEAD_AD_C9_PT1;
        default: pick_pt = 128'd0;
      endcase
    end
  endfunction

  function [127:0] pick_ct;
    input integer case_idx;
    input integer block_idx;
    begin
      pick_ct = 128'd0;
      case (case_idx)
        2: pick_ct = VEC_AEAD_AD_C2_CT0;
        3: pick_ct = VEC_AEAD_AD_C3_CT0;
        4: pick_ct = VEC_AEAD_AD_C4_CT0;
        5: pick_ct = VEC_AEAD_AD_C5_CT0;
        6: pick_ct = VEC_AEAD_AD_C6_CT0;
        7: pick_ct = (block_idx == 0) ? VEC_AEAD_AD_C7_CT0 : VEC_AEAD_AD_C7_CT1;
        8: pick_ct = (block_idx == 0) ? VEC_AEAD_AD_C8_CT0 : VEC_AEAD_AD_C8_CT1;
        9: pick_ct = (block_idx == 0) ? VEC_AEAD_AD_C9_CT0 : VEC_AEAD_AD_C9_CT1;
        default: pick_ct = 128'd0;
      endcase
    end
  endfunction

  function [127:0] pick_tag;
    input integer case_idx;
    begin
      pick_tag = 128'd0;
      case (case_idx)
        0: pick_tag = VEC_AEAD_AD_C0_TAG;
        1: pick_tag = VEC_AEAD_AD_C1_TAG;
        2: pick_tag = VEC_AEAD_AD_C2_TAG;
        3: pick_tag = VEC_AEAD_AD_C3_TAG;
        4: pick_tag = VEC_AEAD_AD_C4_TAG;
        5: pick_tag = VEC_AEAD_AD_C5_TAG;
        6: pick_tag = VEC_AEAD_AD_C6_TAG;
        7: pick_tag = VEC_AEAD_AD_C7_TAG;
        8: pick_tag = VEC_AEAD_AD_C8_TAG;
        9: pick_tag = VEC_AEAD_AD_C9_TAG;
        default: pick_tag = 128'd0;
      endcase
    end
  endfunction

  task run_case;
    input integer case_idx;
    input integer tamper_tag;
    integer cycles;
    integer ad_len;
    integer msg_len;
    integer ad_feed_idx;
    integer ct_feed_idx;
    integer pt_recv_idx;
    integer expected_ad_blocks;
    integer expected_msg_blocks;
    integer saw_auth;
    reg failed;
    reg [127:0] expected_pt;
    reg [4:0] expected_bytes;
    begin
      cycles = 0;
      ad_len = pick_ad_len(case_idx);
      msg_len = pick_msg_len(case_idx);
      ad_feed_idx = 0;
      ct_feed_idx = 0;
      pt_recv_idx = 0;
      expected_ad_blocks = block_count(ad_len);
      expected_msg_blocks = block_count(msg_len);
      saw_auth = 0;
      failed = 1'b0;

      @(posedge clk);
      key_i <= VEC_AEAD_AD_KEY;
      nonce_i <= VEC_AEAD_AD_NONCE;
      ad_bytes_i <= ad_len[31:0];
      msg_bytes_i <= msg_len[31:0];
      tag_i <= tamper_tag ? (pick_tag(case_idx) ^ 128'd1) : pick_tag(case_idx);
      start_i <= 1'b1;
      @(posedge clk);
      start_i <= 1'b0;

      while (!done_o && cycles < 5000) begin
        @(posedge clk);
        #1;
        cycles = cycles + 1;

        if (ad_ready_o && ad_feed_idx < expected_ad_blocks) begin
          ad_block_i <= pick_ad(case_idx, ad_feed_idx);
          ad_valid_i <= 1'b1;
          ad_feed_idx = ad_feed_idx + 1;
        end else begin
          ad_valid_i <= 1'b0;
        end

        if (ciphertext_ready_o && ct_feed_idx < expected_msg_blocks) begin
          ciphertext_block_i <= pick_ct(case_idx, ct_feed_idx);
          ciphertext_valid_i <= 1'b1;
          ct_feed_idx = ct_feed_idx + 1;
        end else begin
          ciphertext_valid_i <= 1'b0;
        end

        if (plaintext_valid_o) begin
          if (pt_recv_idx >= expected_msg_blocks) begin
            $display("FAIL case%0d RPC=%0d unexpected plaintext %032x", case_idx, RPC, plaintext_block_o);
            failed = 1'b1;
          end else begin
            expected_bytes = block_bytes(msg_len, pt_recv_idx);
            expected_pt = pick_pt(case_idx, pt_recv_idx);
            if (plaintext_block_o !== expected_pt) begin
              $display("FAIL case%0d RPC=%0d pt%0d got=%032x exp=%032x",
                       case_idx, RPC, pt_recv_idx, plaintext_block_o, expected_pt);
              failed = 1'b1;
            end else if (plaintext_bytes_o !== expected_bytes) begin
              $display("FAIL case%0d RPC=%0d pt%0d bytes got=%0d exp=%0d",
                       case_idx, RPC, pt_recv_idx, plaintext_bytes_o, expected_bytes);
              failed = 1'b1;
            end
          end
          pt_recv_idx = pt_recv_idx + 1;
        end

        if (auth_valid_o) begin
          saw_auth = 1;
          if (auth_ok_o !== !tamper_tag) begin
            $display("FAIL case%0d RPC=%0d auth_ok got=%0d exp=%0d tamper=%0d",
                     case_idx, RPC, auth_ok_o, !tamper_tag, tamper_tag);
            failed = 1'b1;
          end
        end
      end

      ad_valid_i <= 1'b0;
      ciphertext_valid_i <= 1'b0;
      @(posedge clk);

      if (cycles >= 5000) begin
        $display("FAIL case%0d RPC=%0d timeout", case_idx, RPC);
        failed = 1'b1;
      end
      if (ad_feed_idx != expected_ad_blocks) begin
        $display("FAIL case%0d RPC=%0d fed %0d AD blocks, expected %0d", case_idx, RPC, ad_feed_idx, expected_ad_blocks);
        failed = 1'b1;
      end
      if (ct_feed_idx != expected_msg_blocks) begin
        $display("FAIL case%0d RPC=%0d fed %0d ciphertext blocks, expected %0d", case_idx, RPC, ct_feed_idx, expected_msg_blocks);
        failed = 1'b1;
      end
      if (pt_recv_idx != expected_msg_blocks) begin
        $display("FAIL case%0d RPC=%0d received %0d plaintext blocks, expected %0d", case_idx, RPC, pt_recv_idx, expected_msg_blocks);
        failed = 1'b1;
      end
      if (!saw_auth) begin
        $display("FAIL case%0d RPC=%0d missing auth verdict", case_idx, RPC);
        failed = 1'b1;
      end

      if (failed) begin
        errors = errors + 1;
      end else begin
        $display("PASS DEC case%0d RPC=%0d ad_bytes=%0d msg_bytes=%0d ad_blocks=%0d msg_blocks=%0d tamper=%0d cycles=%0d",
                 case_idx, RPC, ad_len, msg_len, expected_ad_blocks, expected_msg_blocks, tamper_tag, cycles);
      end
    end
  endtask

  integer i;

  initial begin
    errors = 0;
    reset_dut();

    for (i = 0; i < 10; i = i + 1) begin
      run_case(i, 0);
    end
    run_case(9, 1);

    if (errors == 0) begin
      $display("ALL AEAD DECRYPT ASSOCIATED-DATA TESTS PASSED for RPC=%0d", RPC);
    end else begin
      $display("AEAD DECRYPT ASSOCIATED-DATA TESTS FAILED for RPC=%0d errors=%0d", RPC, errors);
      $fatal;
    end

    $finish;
  end

endmodule
