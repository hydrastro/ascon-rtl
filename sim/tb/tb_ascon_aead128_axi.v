`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0

`include "ascon_aead128_ad_vectors.vh"

`default_nettype none

module tb_ascon_aead128_axi;
  parameter integer RPC = 1;
  parameter integer DECRYPT = 0;

  localparam [31:0] A_CTRL      = 32'h00;
  localparam [31:0] A_STATUS    = 32'h04;
  localparam [31:0] A_AD_BYTES  = 32'h08;
  localparam [31:0] A_MSG_BYTES = 32'h0c;
  localparam [31:0] A_KEY0      = 32'h10;
  localparam [31:0] A_NONCE0    = 32'h20;
  localparam [31:0] A_TAGIN0    = 32'h30;
  localparam [31:0] A_RESULT0   = 32'h50;

  reg clk;
  reg rst_n;

  reg [31:0]  s_axil_awaddr_i;
  reg         s_axil_awvalid_i;
  wire        s_axil_awready_o;
  reg [31:0]  s_axil_wdata_i;
  reg [3:0]   s_axil_wstrb_i;
  reg         s_axil_wvalid_i;
  wire        s_axil_wready_o;
  wire [1:0]  s_axil_bresp_o;
  wire        s_axil_bvalid_o;
  reg         s_axil_bready_i;
  reg [31:0]  s_axil_araddr_i;
  reg         s_axil_arvalid_i;
  wire        s_axil_arready_o;
  wire [31:0] s_axil_rdata_o;
  wire [1:0]  s_axil_rresp_o;
  wire        s_axil_rvalid_o;
  reg         s_axil_rready_i;

  reg          s_axis_ad_tvalid_i;
  wire         s_axis_ad_tready_o;
  reg  [127:0] s_axis_ad_tdata_i;
  reg  [15:0]  s_axis_ad_tkeep_i;
  reg          s_axis_ad_tlast_i;

  reg          s_axis_data_tvalid_i;
  wire         s_axis_data_tready_o;
  reg  [127:0] s_axis_data_tdata_i;
  reg  [15:0]  s_axis_data_tkeep_i;
  reg          s_axis_data_tlast_i;

  wire         m_axis_data_tvalid_o;
  reg          m_axis_data_tready_i;
  wire [127:0] m_axis_data_tdata_o;
  wire [15:0]  m_axis_data_tkeep_o;
  wire         m_axis_data_tlast_o;

  integer errors;

  ascon_aead128_axi #(
    .DECRYPT(DECRYPT),
    .ROUNDS_PER_CYCLE(RPC),
    .AD_FIFO_DEPTH_LOG2(2),
    .IN_FIFO_DEPTH_LOG2(2),
    .OUT_FIFO_DEPTH_LOG2(2)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .s_axil_awaddr_i(s_axil_awaddr_i),
    .s_axil_awvalid_i(s_axil_awvalid_i),
    .s_axil_awready_o(s_axil_awready_o),
    .s_axil_wdata_i(s_axil_wdata_i),
    .s_axil_wstrb_i(s_axil_wstrb_i),
    .s_axil_wvalid_i(s_axil_wvalid_i),
    .s_axil_wready_o(s_axil_wready_o),
    .s_axil_bresp_o(s_axil_bresp_o),
    .s_axil_bvalid_o(s_axil_bvalid_o),
    .s_axil_bready_i(s_axil_bready_i),
    .s_axil_araddr_i(s_axil_araddr_i),
    .s_axil_arvalid_i(s_axil_arvalid_i),
    .s_axil_arready_o(s_axil_arready_o),
    .s_axil_rdata_o(s_axil_rdata_o),
    .s_axil_rresp_o(s_axil_rresp_o),
    .s_axil_rvalid_o(s_axil_rvalid_o),
    .s_axil_rready_i(s_axil_rready_i),
    .s_axis_ad_tvalid_i(s_axis_ad_tvalid_i),
    .s_axis_ad_tready_o(s_axis_ad_tready_o),
    .s_axis_ad_tdata_i(s_axis_ad_tdata_i),
    .s_axis_ad_tkeep_i(s_axis_ad_tkeep_i),
    .s_axis_ad_tlast_i(s_axis_ad_tlast_i),
    .s_axis_data_tvalid_i(s_axis_data_tvalid_i),
    .s_axis_data_tready_o(s_axis_data_tready_o),
    .s_axis_data_tdata_i(s_axis_data_tdata_i),
    .s_axis_data_tkeep_i(s_axis_data_tkeep_i),
    .s_axis_data_tlast_i(s_axis_data_tlast_i),
    .m_axis_data_tvalid_o(m_axis_data_tvalid_o),
    .m_axis_data_tready_i(m_axis_data_tready_i),
    .m_axis_data_tdata_o(m_axis_data_tdata_o),
    .m_axis_data_tkeep_o(m_axis_data_tkeep_o),
    .m_axis_data_tlast_o(m_axis_data_tlast_o)
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
      if (remaining >= 16) block_bytes = 5'd16;
      else if (remaining > 0) block_bytes = remaining[4:0];
      else block_bytes = 5'd0;
    end
  endfunction

  function [15:0] keep_from_bytes;
    input [4:0] bytes;
    begin
      case (bytes)
        5'd0: keep_from_bytes = 16'h0000;
        5'd1: keep_from_bytes = 16'h0001;
        5'd2: keep_from_bytes = 16'h0003;
        5'd3: keep_from_bytes = 16'h0007;
        5'd4: keep_from_bytes = 16'h000f;
        5'd5: keep_from_bytes = 16'h001f;
        5'd6: keep_from_bytes = 16'h003f;
        5'd7: keep_from_bytes = 16'h007f;
        5'd8: keep_from_bytes = 16'h00ff;
        5'd9: keep_from_bytes = 16'h01ff;
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
    input [15:0] keep;
    integer i;
    begin
      mask_axis_ref = 128'd0;
      for (i = 0; i < 16; i = i + 1) begin
        if (keep[i]) mask_axis_ref[(8*i)+:8] = data[(8*i)+:8];
      end
    end
  endfunction

  function [127:0] pick_ad;
    input integer case_idx;
    input integer block_idx;
    begin
      if (case_idx == 8) pick_ad = (block_idx == 0) ? VEC_AEAD_AD_C8_AD0 : VEC_AEAD_AD_C8_AD1;
      else pick_ad = (block_idx == 0) ? VEC_AEAD_AD_C7_AD0 : VEC_AEAD_AD_C7_AD1;
    end
  endfunction

  function [127:0] pick_pt;
    input integer case_idx;
    input integer block_idx;
    begin
      if (case_idx == 8) pick_pt = (block_idx == 0) ? VEC_AEAD_AD_C8_PT0 : VEC_AEAD_AD_C8_PT1;
      else pick_pt = (block_idx == 0) ? VEC_AEAD_AD_C7_PT0 : VEC_AEAD_AD_C7_PT1;
    end
  endfunction

  function [127:0] pick_ct;
    input integer case_idx;
    input integer block_idx;
    begin
      if (case_idx == 8) pick_ct = (block_idx == 0) ? VEC_AEAD_AD_C8_CT0 : VEC_AEAD_AD_C8_CT1;
      else pick_ct = (block_idx == 0) ? VEC_AEAD_AD_C7_CT0 : VEC_AEAD_AD_C7_CT1;
    end
  endfunction

  function [127:0] pick_tag;
    input integer case_idx;
    begin
      pick_tag = (case_idx == 8) ? VEC_AEAD_AD_C8_TAG : VEC_AEAD_AD_C7_TAG;
    end
  endfunction

  function integer pick_ad_len;
    input integer case_idx;
    begin
      pick_ad_len = (case_idx == 8) ? VEC_AEAD_AD_C8_AD_BYTES : VEC_AEAD_AD_C7_AD_BYTES;
    end
  endfunction

  function integer pick_msg_len;
    input integer case_idx;
    begin
      pick_msg_len = (case_idx == 8) ? VEC_AEAD_AD_C8_MSG_BYTES : VEC_AEAD_AD_C7_MSG_BYTES;
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
      s_axil_awaddr_i <= 32'd0;
      s_axil_awvalid_i <= 1'b0;
      s_axil_wdata_i <= 32'd0;
      s_axil_wstrb_i <= 4'hf;
      s_axil_wvalid_i <= 1'b0;
      s_axil_bready_i <= 1'b0;
      s_axil_araddr_i <= 32'd0;
      s_axil_arvalid_i <= 1'b0;
      s_axil_rready_i <= 1'b0;

      s_axis_ad_tvalid_i <= 1'b0;
      s_axis_ad_tdata_i <= 128'd0;
      s_axis_ad_tkeep_i <= 16'd0;
      s_axis_ad_tlast_i <= 1'b0;

      s_axis_data_tvalid_i <= 1'b0;
      s_axis_data_tdata_i <= 128'd0;
      s_axis_data_tkeep_i <= 16'd0;
      s_axis_data_tlast_i <= 1'b0;

      m_axis_data_tready_i <= 1'b0;

      repeat (5) @(posedge clk);
      rst_n <= 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  task axil_write;
    input [31:0] addr;
    input [31:0] data;
    begin
      @(negedge clk);
      s_axil_awaddr_i = addr;
      s_axil_awvalid_i = 1'b1;
      s_axil_wdata_i = data;
      s_axil_wstrb_i = 4'hf;
      s_axil_wvalid_i = 1'b1;
      s_axil_bready_i = 1'b1;
      while (!(s_axil_awvalid_i && s_axil_awready_o && s_axil_wvalid_i && s_axil_wready_o)) begin
        @(negedge clk);
      end
      @(posedge clk);
      #1;
      s_axil_awvalid_i = 1'b0;
      s_axil_wvalid_i = 1'b0;
      while (!s_axil_bvalid_o) begin
        @(posedge clk);
      end
      @(posedge clk);
      #1;
      s_axil_bready_i = 1'b0;
    end
  endtask

  task axil_read;
    input [31:0] addr;
    output [31:0] data;
    begin
      @(negedge clk);
      s_axil_araddr_i = addr;
      s_axil_arvalid_i = 1'b1;
      s_axil_rready_i = 1'b1;
      while (!(s_axil_arvalid_i && s_axil_arready_o)) begin
        @(negedge clk);
      end
      @(posedge clk);
      #1;
      s_axil_arvalid_i = 1'b0;
      while (!s_axil_rvalid_o) begin
        @(posedge clk);
      end
      data = s_axil_rdata_o;
      @(posedge clk);
      #1;
      s_axil_rready_i = 1'b0;
    end
  endtask

  task write_u128;
    input [31:0] base;
    input [127:0] value;
    begin
      axil_write(base + 32'd0,  value[31:0]);
      axil_write(base + 32'd4,  value[63:32]);
      axil_write(base + 32'd8,  value[95:64]);
      axil_write(base + 32'd12, value[127:96]);
    end
  endtask

  task read_u128;
    input [31:0] base;
    output [127:0] value;
    reg [31:0] w0;
    reg [31:0] w1;
    reg [31:0] w2;
    reg [31:0] w3;
    begin
      axil_read(base + 32'd0, w0);
      axil_read(base + 32'd4, w1);
      axil_read(base + 32'd8, w2);
      axil_read(base + 32'd12, w3);
      value = {w3, w2, w1, w0};
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
    integer ad_len;
    integer msg_len;
    integer ad_blocks;
    integer msg_blocks;
    integer i;
    integer out_idx;
    integer cycles;
    integer saw_result;
    reg failed;
    reg out_fire;
    reg [127:0] out_data_sample;
    reg [15:0] out_keep_sample;
    reg out_last_sample;
    reg [127:0] exp_data;
    reg [15:0] exp_keep;
    reg [31:0] status;
    reg [127:0] result_tag;
    begin
      ad_len = pick_ad_len(case_idx);
      msg_len = pick_msg_len(case_idx);
      ad_blocks = block_count(ad_len);
      msg_blocks = block_count(msg_len);
      out_idx = 0;
      cycles = 0;
      saw_result = 0;
      failed = 1'b0;

      axil_write(A_CTRL, 32'h2);
      axil_write(A_AD_BYTES, ad_len[31:0]);
      axil_write(A_MSG_BYTES, msg_len[31:0]);
      write_u128(A_KEY0, VEC_AEAD_AD_KEY);
      write_u128(A_NONCE0, VEC_AEAD_AD_NONCE);
      write_u128(A_TAGIN0, pick_tag(case_idx));

      for (i = 0; i < ad_blocks; i = i + 1) begin
        push_ad_axis(pick_ad(case_idx, i), block_bytes(ad_len, i), (i == (ad_blocks - 1)));
      end

      for (i = 0; i < msg_blocks; i = i + 1) begin
        push_data_axis(expected_input_block(case_idx, i), block_bytes(msg_len, i), (i == (msg_blocks - 1)));
      end

      axil_write(A_CTRL, 32'h1);

      while (!saw_result && cycles < 10000) begin
        @(negedge clk);
        cycles = cycles + 1;
        m_axis_data_tready_i = ((cycles % 7) != 3);
        #1;
        out_fire = m_axis_data_tvalid_o && m_axis_data_tready_i;
        out_data_sample = m_axis_data_tdata_o;
        out_keep_sample = m_axis_data_tkeep_o;
        out_last_sample = m_axis_data_tlast_o;
        @(posedge clk);
        #1;

        if (out_fire) begin
          if (out_idx >= msg_blocks) begin
            $display("FAIL AXI case%0d mode=%0d RPC=%0d unexpected output", case_idx, DECRYPT, RPC);
            failed = 1'b1;
          end else begin
            exp_keep = keep_from_bytes(block_bytes(msg_len, out_idx));
            exp_data = mask_axis_ref(block_to_axis_ref(expected_output_block(case_idx, out_idx)), exp_keep);

            if (out_data_sample !== exp_data) begin
              $display("FAIL AXI case%0d mode=%0d RPC=%0d out%0d data got=%032x exp=%032x",
                       case_idx, DECRYPT, RPC, out_idx, out_data_sample, exp_data);
              failed = 1'b1;
            end
            if (out_keep_sample !== exp_keep) begin
              $display("FAIL AXI case%0d mode=%0d RPC=%0d out%0d keep got=%04x exp=%04x",
                       case_idx, DECRYPT, RPC, out_idx, out_keep_sample, exp_keep);
              failed = 1'b1;
            end
            if (out_last_sample !== (out_idx == (msg_blocks - 1))) begin
              $display("FAIL AXI case%0d mode=%0d RPC=%0d out%0d last got=%0d exp=%0d",
                       case_idx, DECRYPT, RPC, out_idx, out_last_sample, (out_idx == (msg_blocks - 1)));
              failed = 1'b1;
            end
          end
          out_idx = out_idx + 1;
        end

        axil_read(A_STATUS, status);
        if (status[3]) begin
          saw_result = 1;
        end
      end

      m_axis_data_tready_i = 1'b0;

      if (!saw_result) begin
        $display("FAIL AXI case%0d mode=%0d RPC=%0d timeout/no result", case_idx, DECRYPT, RPC);
        failed = 1'b1;
      end

      if (out_idx != msg_blocks) begin
        $display("FAIL AXI case%0d mode=%0d RPC=%0d output count got=%0d exp=%0d",
                 case_idx, DECRYPT, RPC, out_idx, msg_blocks);
        failed = 1'b1;
      end

      read_u128(A_RESULT0, result_tag);
      if (DECRYPT == 0) begin
        if (result_tag !== pick_tag(case_idx)) begin
          $display("FAIL AXI case%0d mode=%0d RPC=%0d tag got=%032x exp=%032x",
                   case_idx, DECRYPT, RPC, result_tag, pick_tag(case_idx));
          failed = 1'b1;
        end
      end else begin
        if (!status[4]) begin
          $display("FAIL AXI case%0d mode=%0d RPC=%0d auth_ok low", case_idx, DECRYPT, RPC);
          failed = 1'b1;
        end
      end

      axil_write(A_CTRL, 32'h4);

      if (failed) begin
        errors = errors + 1;
      end else begin
        $display("PASS AXI-LITE+AXIS case%0d mode=%0d RPC=%0d cycles=%0d",
                 case_idx, DECRYPT, RPC, cycles);
      end

      repeat (2) @(posedge clk);
    end
  endtask

  initial begin
    errors = 0;
    reset_dut();
    run_case(7);
    run_case(8);

    if (errors == 0) begin
      $display("ALL AXI-LITE+AXIS AEAD TESTS PASSED mode=%0d RPC=%0d", DECRYPT, RPC);
      $finish;
    end else begin
      $display("AXI-LITE+AXIS AEAD TESTS FAILED mode=%0d RPC=%0d errors=%0d", DECRYPT, RPC, errors);
      $fatal;
    end
  end

endmodule

`default_nettype wire
