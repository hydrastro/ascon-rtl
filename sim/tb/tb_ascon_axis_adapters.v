`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module tb_ascon_axis_adapters;

  reg clk;
  reg rst_n;
  reg clear;

  reg          s_valid;
  wire         s_ready;
  reg  [127:0] s_data;
  reg  [15:0]  s_keep;
  reg          s_last;

  wire         b_valid;
  reg          b_ready;
  wire [127:0] b_data;
  wire [4:0]   b_bytes;
  wire         b_last;
  wire         keep_error;

  reg          e_b_valid;
  wire         e_b_ready;
  reg  [127:0] e_b_data;
  reg  [4:0]   e_b_bytes;
  reg          e_b_last;

  wire         m_valid;
  reg          m_ready;
  wire [127:0] m_data;
  wire [15:0]  m_keep;
  wire         m_last;

  integer errors;

  ascon_axis_ingress128 u_ingress (
    .clk            (clk),
    .rst_n          (rst_n),
    .clear_i        (clear),
    .s_axis_tvalid_i(s_valid),
    .s_axis_tready_o(s_ready),
    .s_axis_tdata_i (s_data),
    .s_axis_tkeep_i (s_keep),
    .s_axis_tlast_i (s_last),
    .block_valid_o  (b_valid),
    .block_ready_i  (b_ready),
    .block_data_o   (b_data),
    .block_bytes_o  (b_bytes),
    .block_last_o   (b_last),
    .keep_error_o   (keep_error)
  );

  ascon_axis_egress128 u_egress (
    .clk            (clk),
    .rst_n          (rst_n),
    .clear_i        (clear),
    .block_valid_i  (e_b_valid),
    .block_ready_o  (e_b_ready),
    .block_data_i   (e_b_data),
    .block_bytes_i  (e_b_bytes),
    .block_last_i   (e_b_last),
    .m_axis_tvalid_o(m_valid),
    .m_axis_tready_i(m_ready),
    .m_axis_tdata_o (m_data),
    .m_axis_tkeep_o (m_keep),
    .m_axis_tlast_o (m_last)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function [127:0] axis_to_block_ref;
    input [127:0] axis_data;
    begin
      axis_to_block_ref[95:64]  = axis_data[31:0];
      axis_to_block_ref[127:96] = axis_data[63:32];
      axis_to_block_ref[31:0]   = axis_data[95:64];
      axis_to_block_ref[63:32]  = axis_data[127:96];
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

  task expect;
    input cond;
    input [255:0] msg;
    begin
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL: %0s", msg);
      end
    end
  endtask

  task check_ingress;
    input [127:0] data;
    input [15:0]  keep;
    input         last;
    input [4:0]   bytes;
    input         expect_err;
    reg [127:0] exp_block;
    begin
      s_valid = 1'b1;
      s_data  = data;
      s_keep  = keep;
      s_last  = last;
      b_ready = 1'b1;
      #1;
      exp_block = axis_to_block_ref(mask_axis_ref(data, keep));
      expect(s_ready === 1'b1, "ingress tready");
      expect(b_valid === 1'b1, "ingress block_valid");
      expect(b_data === exp_block, "ingress block data");
      expect(b_bytes === bytes, "ingress block bytes");
      expect(b_last === last, "ingress block last");
      expect(keep_error === expect_err, "ingress keep_error");
      @(posedge clk);
      s_valid = 1'b0;
      s_data  = 128'd0;
      s_keep  = 16'd0;
      s_last  = 1'b0;
      b_ready = 1'b0;
      #1;
    end
  endtask

  task check_egress;
    input [127:0] block;
    input [4:0]   bytes;
    input         last;
    input [15:0]  exp_keep;
    reg [127:0] exp_data;
    begin
      e_b_valid = 1'b1;
      e_b_data  = block;
      e_b_bytes = bytes;
      e_b_last  = last;
      m_ready   = 1'b1;
      #1;
      exp_data = mask_axis_ref(block_to_axis_ref(block), exp_keep);
      expect(e_b_ready === 1'b1, "egress block_ready");
      expect(m_valid === 1'b1, "egress tvalid");
      expect(m_data === exp_data, "egress tdata");
      expect(m_keep === exp_keep, "egress tkeep");
      expect(m_last === last, "egress tlast");
      @(posedge clk);
      e_b_valid = 1'b0;
      e_b_data  = 128'd0;
      e_b_bytes = 5'd0;
      e_b_last  = 1'b0;
      m_ready   = 1'b0;
      #1;
    end
  endtask

  initial begin
    errors = 0;
    clear = 1'b0;
    rst_n = 1'b0;

    s_valid = 1'b0;
    s_data  = 128'd0;
    s_keep  = 16'd0;
    s_last  = 1'b0;
    b_ready = 1'b0;

    e_b_valid = 1'b0;
    e_b_data  = 128'd0;
    e_b_bytes = 5'd0;
    e_b_last  = 1'b0;
    m_ready   = 1'b0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    check_ingress(128'hffeeddccbbaa99887766554433221100, 16'hffff, 1'b0, 5'd16, 1'b0);
    check_ingress(128'hffeeddccbbaa99887766554433221100, 16'h001f, 1'b1, 5'd5, 1'b0);
    check_ingress(128'hffeeddccbbaa99887766554433221100, 16'h00f7, 1'b1, 5'd7, 1'b1);

    check_egress(128'h7766554433221100ffeeddccbbaa9988, 5'd16, 1'b0, 16'hffff);
    check_egress(128'h7766554433221100ffeeddccbbaa9988, 5'd5, 1'b1, 16'h001f);
    check_egress(128'h7766554433221100ffeeddccbbaa9988, 5'd0, 1'b1, 16'h0000);

    // Backpressure propagation.
    s_valid = 1'b1;
    s_data  = 128'h0123456789abcdeffedcba9876543210;
    s_keep  = 16'hffff;
    s_last  = 1'b0;
    b_ready = 1'b0;
    #1;
    expect(s_ready === 1'b0, "ingress backpressure tready low");
    expect(b_valid === 1'b1, "ingress valid remains high during backpressure");

    e_b_valid = 1'b1;
    e_b_data  = 128'h0123456789abcdeffedcba9876543210;
    e_b_bytes = 5'd16;
    e_b_last  = 1'b0;
    m_ready   = 1'b0;
    #1;
    expect(e_b_ready === 1'b0, "egress backpressure block_ready low");
    expect(m_valid === 1'b1, "egress valid remains high during backpressure");

    clear = 1'b1;
    #1;
    expect(s_ready === 1'b0, "clear forces ingress tready low");
    expect(b_valid === 1'b0, "clear forces ingress block_valid low");
    expect(e_b_ready === 1'b0, "clear forces egress block_ready low");
    expect(m_valid === 1'b0, "clear forces egress tvalid low");
    clear = 1'b0;

    if (errors == 0) begin
      $display("ALL AXI4-STREAM ADAPTER TESTS PASSED");
    end else begin
      $display("AXI4-STREAM ADAPTER TESTS FAILED errors=%0d", errors);
      $fatal;
    end

    $finish;
  end

endmodule

`default_nettype wire
