// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ps
`default_nettype none

module tb_ascon_stream_fifo;
  localparam integer WIDTH      = 134;
  localparam integer DEPTH_LOG2 = 2;
  localparam integer DEPTH      = (1 << DEPTH_LOG2);
  localparam [DEPTH_LOG2:0] DEPTH_COUNT = (1 << DEPTH_LOG2);
  localparam integer N_WORDS    = 64;

  reg clk;
  reg rst_n;
  reg clear_i;

  reg              in_valid_i;
  wire             in_ready_o;
  reg  [WIDTH-1:0] in_data_i;

  wire             out_valid_o;
  reg              out_ready_i;
  wire [WIDTH-1:0] out_data_o;

  wire empty_o;
  wire full_o;
  wire [DEPTH_LOG2:0] level_o;

  reg [WIDTH-1:0] expected [0:N_WORDS-1];
  integer send_idx;
  integer recv_idx;
  integer cycle;
  integer errors;
  reg tb_in_fire;
  reg tb_out_fire;
  reg [WIDTH-1:0] tb_out_data;

  ascon_stream_fifo #(
    .WIDTH(WIDTH),
    .DEPTH_LOG2(DEPTH_LOG2)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .clear_i(clear_i),
    .in_valid_i(in_valid_i),
    .in_ready_o(in_ready_o),
    .in_data_i(in_data_i),
    .out_valid_o(out_valid_o),
    .out_ready_i(out_ready_i),
    .out_data_o(out_data_o),
    .empty_o(empty_o),
    .full_o(full_o),
    .level_o(level_o)
  );

  always #5 clk = !clk;

  function [WIDTH-1:0] make_word;
    input [31:0] idx;
    reg [63:0] idx64;
    begin
      idx64 = {32'd0, idx};
      make_word = {idx[0], idx[4:0], 64'h0123_4567_89ab_cdef ^ idx64, 64'hfedc_ba98_7654_3210 ^ (idx64 << 1)};
    end
  endfunction

  integer i;

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    clear_i = 1'b0;
    in_valid_i = 1'b0;
    in_data_i = {WIDTH{1'b0}};
    out_ready_i = 1'b0;
    send_idx = 0;
    recv_idx = 0;
    cycle = 0;
    errors = 0;

    for (i = 0; i < N_WORDS; i = i + 1) begin
      expected[i] = make_word(i);
    end

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    while (recv_idx < N_WORDS && cycle < 1000) begin
      @(negedge clk);
      cycle = cycle + 1;

      // Deliberately create both source gaps and sink stalls.
      in_valid_i  = (send_idx < N_WORDS) && ((cycle % 5) != 1);
      out_ready_i = ((cycle % 7) != 2) && ((cycle % 11) != 3);
      in_data_i   = (send_idx < N_WORDS) ? expected[send_idx] : {WIDTH{1'b0}};

      // Ready/valid transfers are sampled at the active clock edge.  The FIFO
      // exposes out_data_o combinationally from rd_ptr_q, so sample the output
      // data before the edge that advances rd_ptr_q.
      #1;
      tb_in_fire  = in_valid_i && in_ready_o;
      tb_out_fire = out_valid_o && out_ready_i;
      tb_out_data = out_data_o;

      @(posedge clk);
      #1;

      if (tb_in_fire) begin
        send_idx = send_idx + 1;
      end

      if (tb_out_fire) begin
        if (tb_out_data !== expected[recv_idx]) begin
          $display("FAIL fifo word %0d expected=%h got=%h", recv_idx, expected[recv_idx], tb_out_data);
          errors = errors + 1;
        end
        recv_idx = recv_idx + 1;
      end

      if (level_o > DEPTH_COUNT) begin
        $display("FAIL fifo level overflow: level=%0d depth=%0d", level_o, DEPTH);
        errors = errors + 1;
      end
    end

    in_valid_i = 1'b0;
    out_ready_i = 1'b0;

    if (cycle >= 1000) begin
      $display("FAIL fifo timeout send=%0d recv=%0d", send_idx, recv_idx);
      errors = errors + 1;
    end

    // Verify clear from a non-empty state.
    @(negedge clk);
    in_valid_i = 1'b1;
    in_data_i = expected[0];
    out_ready_i = 1'b0;
    @(posedge clk);
    #1;
    if (!in_ready_o && !out_valid_o) begin
      $display("FAIL fifo failed to accept post-drain word");
      errors = errors + 1;
    end
    @(negedge clk);
    in_valid_i = 1'b0;
    clear_i = 1'b1;
    @(posedge clk);
    #1;
    clear_i = 1'b0;
    if (!empty_o || out_valid_o || level_o != {1'b0, {DEPTH_LOG2{1'b0}}}) begin
      $display("FAIL fifo clear empty=%b valid=%b level=%0d", empty_o, out_valid_o, level_o);
      errors = errors + 1;
    end

    if (errors == 0) begin
      $display("ALL STREAM FIFO TESTS PASSED");
    end else begin
      $display("STREAM FIFO TESTS FAILED errors=%0d", errors);
      $fatal;
    end

    $finish;
  end

endmodule

`default_nettype wire
