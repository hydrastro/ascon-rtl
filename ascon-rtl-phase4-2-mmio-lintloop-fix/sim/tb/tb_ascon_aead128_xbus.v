`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0

`include "ascon_aead128_ad_vectors.vh"

module tb_ascon_aead128_xbus;
  parameter integer RPC = 1;
  parameter integer DECRYPT = 0;

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

  reg clk;
  reg rst_n;
  reg [31:0] xbus_adr_i;
  reg [31:0] xbus_dat_i;
  wire [31:0] xbus_dat_o;
  reg xbus_we_i;
  reg [3:0] xbus_sel_i;
  reg xbus_stb_i;
  reg xbus_cyc_i;
  wire xbus_ack_o;
  wire xbus_err_o;
  wire irq_o;

  integer errors;

  ascon_aead128_xbus #(
    .DECRYPT(DECRYPT),
    .ROUNDS_PER_CYCLE(RPC),
    .AD_FIFO_DEPTH_LOG2(2),
    .IN_FIFO_DEPTH_LOG2(2),
    .OUT_FIFO_DEPTH_LOG2(2),
    .BASE_ADDR(32'hF000_0000),
    .ADDR_MASK(32'hFFFF_FF00),
    .ERROR_ON_MISS(1)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .xbus_adr_i(xbus_adr_i),
    .xbus_dat_i(xbus_dat_i),
    .xbus_dat_o(xbus_dat_o),
    .xbus_we_i(xbus_we_i),
    .xbus_sel_i(xbus_sel_i),
    .xbus_stb_i(xbus_stb_i),
    .xbus_cyc_i(xbus_cyc_i),
    .xbus_ack_o(xbus_ack_o),
    .xbus_err_o(xbus_err_o),
    .irq_o(irq_o)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task reset_dut;
    begin
      rst_n <= 1'b0;
      xbus_adr_i <= 32'd0;
      xbus_dat_i <= 32'd0;
      xbus_we_i <= 1'b0;
      xbus_sel_i <= 4'hf;
      xbus_stb_i <= 1'b0;
      xbus_cyc_i <= 1'b0;
      repeat (5) @(posedge clk);
      rst_n <= 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  task mmio_write;
    input [7:0] addr;
    input [31:0] data;
    integer guard;
    reg fired;
    begin
      guard = 0;
      fired = 1'b0;
      @(negedge clk);
      xbus_adr_i = 32'hF000_0000 | {24'd0, addr};
      xbus_dat_i = data;
      xbus_we_i = 1'b1;
      xbus_sel_i = 4'hf;
      xbus_stb_i = 1'b1;
      xbus_cyc_i = 1'b1;
      while (!fired && guard < 20000) begin
        @(posedge clk);
        #1;
        if (xbus_ack_o) begin
          fired = 1'b1;
        end
        if (xbus_err_o) begin
          $display("FAIL xbus write bus error addr=%02x data=%08x", addr, data);
          errors = errors + 1;
          fired = 1'b1;
        end
        guard = guard + 1;
      end
      @(negedge clk);
      xbus_stb_i = 1'b0;
      xbus_cyc_i = 1'b0;
      xbus_we_i = 1'b0;
      xbus_dat_i = 32'd0;
      xbus_adr_i = 32'd0;
      if (!fired) begin
        $display("FAIL xbus write timeout addr=%02x data=%08x", addr, data);
        errors = errors + 1;
      end
    end
  endtask

  task mmio_read;
    input [7:0] addr;
    output [31:0] data;
    integer guard;
    reg fired;
    begin
      guard = 0;
      fired = 1'b0;
      data = 32'd0;
      @(negedge clk);
      xbus_adr_i = 32'hF000_0000 | {24'd0, addr};
      xbus_dat_i = 32'd0;
      xbus_we_i = 1'b0;
      xbus_sel_i = 4'hf;
      xbus_stb_i = 1'b1;
      xbus_cyc_i = 1'b1;
      while (!fired && guard < 20000) begin
        @(posedge clk);
        #1;
        if (xbus_ack_o) begin
          data = xbus_dat_o;
          fired = 1'b1;
        end
        if (xbus_err_o) begin
          $display("FAIL xbus read bus error addr=%02x", addr);
          errors = errors + 1;
          fired = 1'b1;
        end
        guard = guard + 1;
      end
      @(negedge clk);
      xbus_stb_i = 1'b0;
      xbus_cyc_i = 1'b0;
      xbus_adr_i = 32'd0;
      if (!fired) begin
        $display("FAIL xbus read timeout addr=%02x", addr);
        errors = errors + 1;
      end
    end
  endtask

  function integer ceil_div4;
    input integer x;
    begin
      ceil_div4 = (x + 3) / 4;
    end
  endfunction

  function [31:0] select_word;
    input [127:0] block;
    input integer idx;
    begin
      // Byte-stream order for internal Ascon blocks {first8, second8}.
      case (idx)
        0: select_word = block[95:64];
        1: select_word = block[127:96];
        2: select_word = block[31:0];
        default: select_word = block[63:32];
      endcase
    end
  endfunction

  function [2:0] expected_word_bytes;
    input integer total_len;
    input integer word_idx;
    integer remaining;
    begin
      remaining = total_len - (word_idx * 4);
      if (remaining >= 4) begin
        expected_word_bytes = 3'd4;
      end else if (remaining > 0) begin
        expected_word_bytes = remaining[2:0];
      end else begin
        expected_word_bytes = 3'd0;
      end
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
        7: pick_pt = (block_idx == 0) ? VEC_AEAD_AD_C7_PT0 : VEC_AEAD_AD_C7_PT1;
        8: pick_pt = (block_idx == 0) ? VEC_AEAD_AD_C8_PT0 : VEC_AEAD_AD_C8_PT1;
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
        7: pick_ct = (block_idx == 0) ? VEC_AEAD_AD_C7_CT0 : VEC_AEAD_AD_C7_CT1;
        8: pick_ct = (block_idx == 0) ? VEC_AEAD_AD_C8_CT0 : VEC_AEAD_AD_C8_CT1;
        default: pick_ct = 128'd0;
      endcase
    end
  endfunction

  function [127:0] pick_tag;
    input integer case_idx;
    begin
      case (case_idx)
        7: pick_tag = VEC_AEAD_AD_C7_TAG;
        8: pick_tag = VEC_AEAD_AD_C8_TAG;
        default: pick_tag = 128'd0;
      endcase
    end
  endfunction

  function integer pick_ad_len;
    input integer case_idx;
    begin
      case (case_idx)
        7: pick_ad_len = VEC_AEAD_AD_C7_AD_BYTES;
        8: pick_ad_len = VEC_AEAD_AD_C8_AD_BYTES;
        default: pick_ad_len = 0;
      endcase
    end
  endfunction

  function integer pick_msg_len;
    input integer case_idx;
    begin
      case (case_idx)
        7: pick_msg_len = VEC_AEAD_AD_C7_MSG_BYTES;
        8: pick_msg_len = VEC_AEAD_AD_C8_MSG_BYTES;
        default: pick_msg_len = 0;
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

  task write_word128;
    input [7:0] base;
    input [127:0] value;
    begin
      mmio_write(base + 8'd0,  value[31:0]);
      mmio_write(base + 8'd4,  value[63:32]);
      mmio_write(base + 8'd8,  value[95:64]);
      mmio_write(base + 8'd12, value[127:96]);
    end
  endtask

  task read_word128;
    input [7:0] base;
    output [127:0] value;
    reg [31:0] w0;
    reg [31:0] w1;
    reg [31:0] w2;
    reg [31:0] w3;
    begin
      mmio_read(base + 8'd0, w0);
      mmio_read(base + 8'd4, w1);
      mmio_read(base + 8'd8, w2);
      mmio_read(base + 8'd12, w3);
      value = {w3, w2, w1, w0};
    end
  endtask

  task feed_words;
    input [7:0] addr;
    input integer total_len;
    input integer is_ad;
    input integer case_idx;
    integer words;
    integer i;
    integer blk;
    integer wi;
    reg [127:0] block;
    begin
      words = ceil_div4(total_len);
      for (i = 0; i < words; i = i + 1) begin
        blk = i / 4;
        wi = i % 4;
        block = is_ad ? pick_ad(case_idx, blk) : expected_input_block(case_idx, blk);
        mmio_write(addr, select_word(block, wi));
      end
    end
  endtask

  task check_output_words;
    input integer case_idx;
    input integer total_len;
    integer words;
    integer i;
    integer blk;
    integer wi;
    reg [31:0] meta;
    reg [31:0] got;
    reg [31:0] exp;
    reg [127:0] block;
    reg failed;
    begin
      failed = 1'b0;
      words = ceil_div4(total_len);
      for (i = 0; i < words; i = i + 1) begin
        meta = 32'd0;
        while (!meta[16]) begin
          mmio_read(ADDR_DOUT_META, meta);
        end
        if (meta[2:0] !== expected_word_bytes(total_len, i)) begin
          $display("FAIL xbus mode=%0d RPC=%0d word%0d bytes got=%0d exp=%0d",
                   DECRYPT, RPC, i, meta[2:0], expected_word_bytes(total_len, i));
          failed = 1'b1;
        end
        if (meta[8] !== (i == words - 1)) begin
          $display("FAIL xbus mode=%0d RPC=%0d word%0d last got=%0d exp=%0d",
                   DECRYPT, RPC, i, meta[8], (i == words - 1));
          failed = 1'b1;
        end
        mmio_read(ADDR_DATA_OUT, got);
        blk = i / 4;
        wi = i % 4;
        block = expected_output_block(case_idx, blk);
        exp = select_word(block, wi);
        if (got !== exp) begin
          $display("FAIL xbus mode=%0d RPC=%0d word%0d got=%08x exp=%08x",
                   DECRYPT, RPC, i, got, exp);
          failed = 1'b1;
        end
      end
      if (failed) begin
        errors = errors + 1;
      end
    end
  endtask

  task wait_result;
    output [31:0] status;
    integer cycles;
    begin
      status = 32'd0;
      cycles = 0;
      while (!status[4] && cycles < 20000) begin
        mmio_read(ADDR_STATUS, status);
        cycles = cycles + 1;
      end
      if (!status[4]) begin
        $display("FAIL xbus mode=%0d RPC=%0d timeout waiting result", DECRYPT, RPC);
        errors = errors + 1;
      end
    end
  endtask

  task run_case;
    input integer case_idx;
    integer ad_len;
    integer msg_len;
    reg [31:0] status;
    reg [127:0] result_tag;
    reg failed;
    begin
      failed = 1'b0;
      ad_len = pick_ad_len(case_idx);
      msg_len = pick_msg_len(case_idx);

      // Clear any previous pending job/FIFO state.
      mmio_write(ADDR_CTRL, 32'h00000002);
      repeat (4) @(posedge clk);

      write_word128(ADDR_KEY0, VEC_AEAD_AD_KEY);
      write_word128(ADDR_NONCE0, VEC_AEAD_AD_NONCE);
      write_word128(ADDR_TAG0, pick_tag(case_idx));
      mmio_write(ADDR_AD_BYTES, ad_len[31:0]);
      mmio_write(ADDR_MSG_BYTES, msg_len[31:0]);

      feed_words(ADDR_AD_IN, ad_len, 1, case_idx);
      feed_words(ADDR_DATA_IN, msg_len, 0, case_idx);
      repeat (4) @(posedge clk);

      mmio_write(ADDR_CTRL, 32'h00000001);
      check_output_words(case_idx, msg_len);
      wait_result(status);

      if (DECRYPT == 0) begin
        read_word128(ADDR_RES0, result_tag);
        if (result_tag !== pick_tag(case_idx)) begin
          $display("FAIL xbus enc RPC=%0d case%0d tag got=%032x exp=%032x",
                   RPC, case_idx, result_tag, pick_tag(case_idx));
          failed = 1'b1;
        end
        if (status[5] !== 1'b1) begin
          $display("FAIL xbus enc RPC=%0d case%0d auth_ok low", RPC, case_idx);
          failed = 1'b1;
        end
      end else begin
        if (status[5] !== 1'b1) begin
          $display("FAIL xbus dec RPC=%0d case%0d auth failed", RPC, case_idx);
          failed = 1'b1;
        end
      end

      if (!irq_o) begin
        $display("FAIL xbus mode=%0d RPC=%0d case%0d irq low with pending result", DECRYPT, RPC, case_idx);
        failed = 1'b1;
      end

      mmio_write(ADDR_CTRL, 32'h00000004);
      repeat (2) @(posedge clk);
      mmio_read(ADDR_STATUS, status);
      if (status[4] !== 1'b0) begin
        $display("FAIL xbus mode=%0d RPC=%0d case%0d result_ack failed status=%08x", DECRYPT, RPC, case_idx, status);
        failed = 1'b1;
      end

      if (failed) begin
        errors = errors + 1;
      end else begin
        $display("PASS xbus case%0d mode=%0d RPC=%0d", case_idx, DECRYPT, RPC);
      end
    end
  endtask

  initial begin
    errors = 0;
    reset_dut();
    run_case(7);
    run_case(8);

    if (errors == 0) begin
      $display("ALL XBUS AEAD WRAPPER TESTS PASSED mode=%0d RPC=%0d", DECRYPT, RPC);
      $finish;
    end else begin
      $display("XBUS AEAD WRAPPER TESTS FAILED mode=%0d RPC=%0d errors=%0d", DECRYPT, RPC, errors);
      $fatal;
    end
  end
endmodule
