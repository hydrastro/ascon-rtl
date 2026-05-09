`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0

module tb_ascon_perm_unrolled;

  parameter integer RPC = 1;

  reg          clk;
  reg          rst_n;
  reg          start_i;
  reg  [3:0]   rounds_i;
  reg  [319:0] state_i;

  wire         busy_o;
  wire         done_o;
  wire [319:0] state_o;

  integer errors;
  integer cycles;

  `include "ascon_perm_vectors.vh"

  ascon_perm_unrolled #(
    .ROUNDS_PER_CYCLE(RPC)
  ) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .start_i (start_i),
    .rounds_i(rounds_i),
    .state_i (state_i),
    .busy_o  (busy_o),
    .done_o  (done_o),
    .state_o (state_o)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task reset_dut;
    begin
      rst_n    = 1'b0;
      start_i  = 1'b0;
      rounds_i = 4'd0;
      state_i  = 320'd0;
      repeat (4) @(posedge clk);
      rst_n = 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  task run_perm;
    input [1023:0] name;
    input [3:0]    rounds;
    input [319:0]  in_state;
    input [319:0]  expected;

    integer timed_out;
    begin
      @(negedge clk);
      state_i  = in_state;
      rounds_i = rounds;
      start_i  = 1'b1;
      @(negedge clk);
      start_i  = 1'b0;

      cycles    = 0;
      timed_out = 0;
      while (!done_o && !timed_out) begin
        @(posedge clk);
        #1;
        cycles = cycles + 1;
        if (cycles > 32) begin
          $display("FAIL %-32s timeout", name);
          errors = errors + 1;
          timed_out = 1;
        end
      end

      if (!timed_out) begin
        #1;
        if (state_o !== expected) begin
          $display("FAIL %-32s RPC=%0d rounds=%0d", name, RPC, rounds);
          $display("  got      %080h", state_o);
          $display("  expected %080h", expected);
          errors = errors + 1;
        end else begin
          $display("PASS %-32s RPC=%0d rounds=%0d cycles=%0d", name, RPC, rounds, cycles);
        end
      end

      @(posedge clk);
    end
  endtask

  initial begin
    errors = 0;
    reset_dut();

    run_perm("zero p12",   4'd12, VEC_ZERO_STATE,   VEC_ZERO_P12);
    run_perm("zero p8",    4'd8,  VEC_ZERO_STATE,   VEC_ZERO_P8);
    run_perm("zero p6",    4'd6,  VEC_ZERO_STATE,   VEC_ZERO_P6);
    run_perm("sample p12", 4'd12, VEC_SAMPLE_STATE, VEC_SAMPLE_P12);
    run_perm("sample p8",  4'd8,  VEC_SAMPLE_STATE, VEC_SAMPLE_P8);
    run_perm("sample p6",  4'd6,  VEC_SAMPLE_STATE, VEC_SAMPLE_P6);

    if (errors == 0) begin
      $display("ALL TESTS PASSED for RPC=%0d", RPC);
      $finish;
    end else begin
      $display("TESTS FAILED: %0d error(s) for RPC=%0d", errors, RPC);
      $fatal;
    end
  end

endmodule
