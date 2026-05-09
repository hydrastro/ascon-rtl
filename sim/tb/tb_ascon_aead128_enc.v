`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0

module tb_ascon_aead128_enc;
  parameter integer RPC = 1;

  `include "ascon_aead128_vectors.vh"

  reg clk;
  reg rst_n;
  reg start_i;
  reg [127:0] key_i;
  reg [127:0] nonce_i;
  reg [31:0] msg_bytes_i;
  wire busy_o;
  wire done_o;
  wire plaintext_ready_o;
  reg plaintext_valid_i;
  reg [127:0] plaintext_block_i;
  wire ciphertext_valid_o;
  reg ciphertext_ready_i;
  wire [127:0] ciphertext_block_o;
  wire [4:0] ciphertext_bytes_o;
  wire tag_valid_o;
  reg tag_ready_i;
  wire [127:0] tag_o;

  integer errors;

  ascon_aead128_enc #(
    .ROUNDS_PER_CYCLE(RPC)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .start_i(start_i),
    .key_i(key_i),
    .nonce_i(nonce_i),
    .msg_bytes_i(msg_bytes_i),
    .busy_o(busy_o),
    .done_o(done_o),
    .plaintext_ready_o(plaintext_ready_o),
    .plaintext_valid_i(plaintext_valid_i),
    .plaintext_block_i(plaintext_block_i),
    .ciphertext_valid_o(ciphertext_valid_o),
    .ciphertext_ready_i(ciphertext_ready_i),
    .ciphertext_block_o(ciphertext_block_o),
    .ciphertext_bytes_o(ciphertext_bytes_o),
    .tag_valid_o(tag_valid_o),
    .tag_ready_i(tag_ready_i),
    .tag_o(tag_o)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task reset_dut;
    begin
      rst_n = 1'b0;
      start_i = 1'b0;
      key_i = 128'd0;
      nonce_i = 128'd0;
      msg_bytes_i = 32'd0;
      plaintext_valid_i = 1'b0;
      plaintext_block_i = 128'd0;
      ciphertext_ready_i = 1'b1;
      tag_ready_i = 1'b1;
      repeat (5) @(posedge clk);
      rst_n = 1'b1;
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

  function [127:0] pick_pt;
    input integer len;
    input integer idx;
    begin
      pick_pt = 128'd0;
      case (len)
        1:  pick_pt = VEC_AEAD_LEN1_PT0;
        7:  pick_pt = VEC_AEAD_LEN7_PT0;
        8:  pick_pt = VEC_AEAD_LEN8_PT0;
        9:  pick_pt = VEC_AEAD_LEN9_PT0;
        15: pick_pt = VEC_AEAD_LEN15_PT0;
        16: pick_pt = VEC_AEAD_LEN16_PT0;
        17: pick_pt = (idx == 0) ? VEC_AEAD_LEN17_PT0 : VEC_AEAD_LEN17_PT1;
        31: pick_pt = (idx == 0) ? VEC_AEAD_LEN31_PT0 : VEC_AEAD_LEN31_PT1;
        32: pick_pt = (idx == 0) ? VEC_AEAD_LEN32_PT0 : VEC_AEAD_LEN32_PT1;
        default: pick_pt = 128'd0;
      endcase
    end
  endfunction

  function [127:0] pick_ct;
    input integer len;
    input integer idx;
    begin
      pick_ct = 128'd0;
      case (len)
        1:  pick_ct = VEC_AEAD_LEN1_CT0;
        7:  pick_ct = VEC_AEAD_LEN7_CT0;
        8:  pick_ct = VEC_AEAD_LEN8_CT0;
        9:  pick_ct = VEC_AEAD_LEN9_CT0;
        15: pick_ct = VEC_AEAD_LEN15_CT0;
        16: pick_ct = VEC_AEAD_LEN16_CT0;
        17: pick_ct = (idx == 0) ? VEC_AEAD_LEN17_CT0 : VEC_AEAD_LEN17_CT1;
        31: pick_ct = (idx == 0) ? VEC_AEAD_LEN31_CT0 : VEC_AEAD_LEN31_CT1;
        32: pick_ct = (idx == 0) ? VEC_AEAD_LEN32_CT0 : VEC_AEAD_LEN32_CT1;
        default: pick_ct = 128'd0;
      endcase
    end
  endfunction

  function [127:0] pick_tag;
    input integer len;
    begin
      pick_tag = 128'd0;
      case (len)
        0:  pick_tag = VEC_AEAD_LEN0_TAG;
        1:  pick_tag = VEC_AEAD_LEN1_TAG;
        7:  pick_tag = VEC_AEAD_LEN7_TAG;
        8:  pick_tag = VEC_AEAD_LEN8_TAG;
        9:  pick_tag = VEC_AEAD_LEN9_TAG;
        15: pick_tag = VEC_AEAD_LEN15_TAG;
        16: pick_tag = VEC_AEAD_LEN16_TAG;
        17: pick_tag = VEC_AEAD_LEN17_TAG;
        31: pick_tag = VEC_AEAD_LEN31_TAG;
        32: pick_tag = VEC_AEAD_LEN32_TAG;
        default: pick_tag = 128'd0;
      endcase
    end
  endfunction

  task run_case;
    input [127:0] name;
    input integer len;
    integer cycles;
    integer feed_idx;
    integer recv_idx;
    integer expected_blocks;
    integer saw_tag;
    reg failed;
    begin
      cycles = 0;
      feed_idx = 0;
      recv_idx = 0;
      expected_blocks = block_count(len);
      saw_tag = 0;
      failed = 1'b0;

      @(posedge clk);
      key_i <= VEC_AEAD_KEY;
      nonce_i <= VEC_AEAD_NONCE;
      msg_bytes_i <= len[31:0];
      start_i <= 1'b1;
      @(posedge clk);
      start_i <= 1'b0;

      while (!done_o && cycles < 3000) begin
        @(posedge clk);
        #1;
        cycles = cycles + 1;

        if (plaintext_ready_o && feed_idx < expected_blocks) begin
          plaintext_block_i <= pick_pt(len, feed_idx);
          plaintext_valid_i <= 1'b1;
          feed_idx = feed_idx + 1;
        end else begin
          plaintext_valid_i <= 1'b0;
        end

        if (ciphertext_valid_o) begin
          if (recv_idx >= expected_blocks) begin
            $display("FAIL %0s RPC=%0d unexpected ciphertext %032x", name, RPC, ciphertext_block_o);
            failed = 1'b1;
          end else if (ciphertext_block_o !== pick_ct(len, recv_idx)) begin
            $display("FAIL %0s RPC=%0d ct%0d got=%032x exp=%032x",
                     name, RPC, recv_idx, ciphertext_block_o, pick_ct(len, recv_idx));
            failed = 1'b1;
          end else if (ciphertext_bytes_o !== block_bytes(len, recv_idx)) begin
            $display("FAIL %0s RPC=%0d ct%0d bytes got=%0d exp=%0d",
                     name, RPC, recv_idx, ciphertext_bytes_o, block_bytes(len, recv_idx));
            failed = 1'b1;
          end
          recv_idx = recv_idx + 1;
        end

        if (tag_valid_o) begin
          saw_tag = 1;
          if (tag_o !== pick_tag(len)) begin
            $display("FAIL %0s RPC=%0d tag got=%032x exp=%032x",
                     name, RPC, tag_o, pick_tag(len));
            failed = 1'b1;
          end
        end
      end

      plaintext_valid_i <= 1'b0;
      @(posedge clk);

      if (cycles >= 3000) begin
        $display("FAIL %0s RPC=%0d timeout", name, RPC);
        failed = 1'b1;
      end
      if (recv_idx != expected_blocks) begin
        $display("FAIL %0s RPC=%0d received %0d ciphertext blocks, expected %0d",
                 name, RPC, recv_idx, expected_blocks);
        failed = 1'b1;
      end
      if (!saw_tag) begin
        $display("FAIL %0s RPC=%0d missing tag", name, RPC);
        failed = 1'b1;
      end

      if (failed) begin
        errors = errors + 1;
      end else begin
        $display("PASS %0s RPC=%0d bytes=%0d blocks=%0d cycles=%0d",
                 name, RPC, len, expected_blocks, cycles);
      end
    end
  endtask

  initial begin
    errors = 0;
    reset_dut();

    run_case("len0", 0);
    run_case("len1", 1);
    run_case("len7", 7);
    run_case("len8", 8);
    run_case("len9", 9);
    run_case("len15", 15);
    run_case("len16", 16);
    run_case("len17", 17);
    run_case("len31", 31);
    run_case("len32", 32);

    if (errors == 0) begin
      $display("ALL AEAD VARIABLE-LENGTH TESTS PASSED for RPC=%0d", RPC);
    end else begin
      $display("AEAD VARIABLE-LENGTH TESTS FAILED for RPC=%0d errors=%0d", RPC, errors);
      $fatal;
    end

    $finish;
  end

endmodule
