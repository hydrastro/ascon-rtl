`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0

module tb_ascon_aead128_fullblock_enc;
  parameter integer RPC = 1;

  `include "ascon_aead128_fullblock_vectors.vh"

  reg clk;
  reg rst_n;
  reg start_i;
  reg [127:0] key_i;
  reg [127:0] nonce_i;
  reg [31:0] msg_blocks_i;
  wire busy_o;
  wire done_o;
  wire plaintext_ready_o;
  reg plaintext_valid_i;
  reg [127:0] plaintext_block_i;
  wire ciphertext_valid_o;
  reg ciphertext_ready_i;
  wire [127:0] ciphertext_block_o;
  wire tag_valid_o;
  reg tag_ready_i;
  wire [127:0] tag_o;

  integer errors;

  ascon_aead128_fullblock_enc #(
    .ROUNDS_PER_CYCLE(RPC)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .start_i(start_i),
    .key_i(key_i),
    .nonce_i(nonce_i),
    .msg_blocks_i(msg_blocks_i),
    .busy_o(busy_o),
    .done_o(done_o),
    .plaintext_ready_o(plaintext_ready_o),
    .plaintext_valid_i(plaintext_valid_i),
    .plaintext_block_i(plaintext_block_i),
    .ciphertext_valid_o(ciphertext_valid_o),
    .ciphertext_ready_i(ciphertext_ready_i),
    .ciphertext_block_o(ciphertext_block_o),
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
      msg_blocks_i = 32'd0;
      plaintext_valid_i = 1'b0;
      plaintext_block_i = 128'd0;
      ciphertext_ready_i = 1'b1;
      tag_ready_i = 1'b1;
      repeat (5) @(posedge clk);
      rst_n = 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  function [127:0] pick_pt;
    input integer blocks;
    input integer idx;
    begin
      if (blocks == 1) begin
        pick_pt = VEC_AEAD_1BLK_PT0;
      end else if (idx == 0) begin
        pick_pt = VEC_AEAD_2BLK_PT0;
      end else begin
        pick_pt = VEC_AEAD_2BLK_PT1;
      end
    end
  endfunction

  function [127:0] pick_ct;
    input integer blocks;
    input integer idx;
    begin
      if (blocks == 1) begin
        pick_ct = VEC_AEAD_1BLK_CT0;
      end else if (idx == 0) begin
        pick_ct = VEC_AEAD_2BLK_CT0;
      end else begin
        pick_ct = VEC_AEAD_2BLK_CT1;
      end
    end
  endfunction

  function [127:0] pick_tag;
    input integer blocks;
    begin
      if (blocks == 0) begin
        pick_tag = VEC_AEAD_EMPTY_TAG;
      end else if (blocks == 1) begin
        pick_tag = VEC_AEAD_1BLK_TAG;
      end else begin
        pick_tag = VEC_AEAD_2BLK_TAG;
      end
    end
  endfunction

  task run_case;
    input [127:0] name;
    input integer blocks;
    integer cycles;
    integer feed_idx;
    integer recv_idx;
    integer saw_tag;
    reg failed;
    begin
      cycles = 0;
      feed_idx = 0;
      recv_idx = 0;
      saw_tag = 0;
      failed = 1'b0;

      @(posedge clk);
      key_i <= VEC_AEAD_KEY;
      nonce_i <= VEC_AEAD_NONCE;
      msg_blocks_i <= blocks[31:0];
      start_i <= 1'b1;
      @(posedge clk);
      start_i <= 1'b0;

      while (!done_o && cycles < 2000) begin
        @(posedge clk);
        #1;
        cycles = cycles + 1;

        if (plaintext_ready_o && feed_idx < blocks) begin
          plaintext_block_i <= pick_pt(blocks, feed_idx);
          plaintext_valid_i <= 1'b1;
          feed_idx = feed_idx + 1;
        end else begin
          plaintext_valid_i <= 1'b0;
        end

        if (ciphertext_valid_o) begin
          if (recv_idx >= blocks) begin
            $display("FAIL %0s RPC=%0d unexpected ciphertext %032x", name, RPC, ciphertext_block_o);
            failed = 1'b1;
          end else if (ciphertext_block_o !== pick_ct(blocks, recv_idx)) begin
            $display("FAIL %0s RPC=%0d ct%0d got=%032x exp=%032x",
                     name, RPC, recv_idx, ciphertext_block_o, pick_ct(blocks, recv_idx));
            failed = 1'b1;
          end
          recv_idx = recv_idx + 1;
        end

        if (tag_valid_o) begin
          saw_tag = 1;
          if (tag_o !== pick_tag(blocks)) begin
            $display("FAIL %0s RPC=%0d tag got=%032x exp=%032x",
                     name, RPC, tag_o, pick_tag(blocks));
            failed = 1'b1;
          end
        end
      end

      plaintext_valid_i <= 1'b0;
      @(posedge clk);

      if (cycles >= 2000) begin
        $display("FAIL %0s RPC=%0d timeout", name, RPC);
        failed = 1'b1;
      end
      if (recv_idx != blocks) begin
        $display("FAIL %0s RPC=%0d received %0d ciphertext blocks, expected %0d",
                 name, RPC, recv_idx, blocks);
        failed = 1'b1;
      end
      if (!saw_tag) begin
        $display("FAIL %0s RPC=%0d missing tag", name, RPC);
        failed = 1'b1;
      end

      if (failed) begin
        errors = errors + 1;
      end else begin
        $display("PASS %0s RPC=%0d blocks=%0d cycles=%0d", name, RPC, blocks, cycles);
      end
    end
  endtask

  initial begin
    errors = 0;
    reset_dut();

    run_case("empty", 0);
    run_case("one_block", 1);
    run_case("two_blocks", 2);

    if (errors == 0) begin
      $display("ALL AEAD FULL-BLOCK TESTS PASSED for RPC=%0d", RPC);
    end else begin
      $display("AEAD FULL-BLOCK TESTS FAILED for RPC=%0d errors=%0d", RPC, errors);
      $fatal;
    end

    $finish;
  end

endmodule
