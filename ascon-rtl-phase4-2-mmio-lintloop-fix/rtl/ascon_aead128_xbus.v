`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Phase 4.2 NEORV32 XBUS/Wishbone-style wrapper around the generic MMIO32
// Ascon-AEAD128 register interface.
//
// This module is intentionally thin: all cryptographic state, FIFOs and the
// register map live in ascon_aead128_mmio32.  This wrapper only performs
// address-window decode and converts the NEORV32 XBUS-style handshake into the
// one-transfer-at-a-time mmio32 valid/ready handshake.
//
// Addressing:
//   A transfer is selected when (xbus_adr_i & ADDR_MASK) == BASE_ADDR.
//   The low 8 address bits are forwarded to ascon_aead128_mmio32.
//   The MMIO register map therefore occupies 256 bytes inside the selected
//   address window.
//
// Protocol contract:
//   - single 32-bit accesses are supported;
//   - writes with xbus_sel_i != 4'b1111 are accepted by the bus wrapper but are
//     not committed by the MMIO core except where the core itself supports the
//     strobe;
//   - xbus_ack_o is asserted for one clock when the underlying MMIO transfer
//     completes;
//   - xbus_err_o is asserted for one clock on an address miss when ERROR_ON_MISS
//     is non-zero, otherwise misses are simply ignored.

`default_nettype none

module ascon_aead128_xbus #(
  parameter integer DECRYPT             = 0,
  parameter integer ROUNDS_PER_CYCLE    = 1,
  parameter integer AD_FIFO_DEPTH_LOG2   = 2,
  parameter integer IN_FIFO_DEPTH_LOG2   = 2,
  parameter integer OUT_FIFO_DEPTH_LOG2  = 2,
  parameter [31:0]  BASE_ADDR           = 32'hF000_0000,
  parameter [31:0]  ADDR_MASK           = 32'hFFFF_FF00,
  parameter integer ERROR_ON_MISS       = 0
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire [31:0] xbus_adr_i,
  input  wire [31:0] xbus_dat_i,
  output reg  [31:0] xbus_dat_o,
  input  wire        xbus_we_i,
  input  wire [3:0]  xbus_sel_i,
  input  wire        xbus_stb_i,
  input  wire        xbus_cyc_i,
  output reg         xbus_ack_o,
  output reg         xbus_err_o,

  output wire        irq_o
);

  wire selected_w = ((xbus_adr_i & ADDR_MASK) == BASE_ADDR);
  wire request_w  = xbus_cyc_i && xbus_stb_i;
  wire hit_w      = request_w && selected_w;
  wire miss_w     = request_w && !selected_w;

  reg        reg_valid_q;
  reg        reg_write_q;
  reg [7:0]  reg_addr_q;
  reg [31:0] reg_wdata_q;
  reg [3:0]  reg_wstrb_q;
  wire       reg_ready_w;
  wire [31:0] reg_rdata_w;

  reg pending_q;

  wire launch_w = hit_w && !pending_q && !reg_valid_q;
  wire complete_w = reg_valid_q && reg_ready_w;

  ascon_aead128_mmio32 #(
    .DECRYPT            (DECRYPT),
    .ROUNDS_PER_CYCLE   (ROUNDS_PER_CYCLE),
    .AD_FIFO_DEPTH_LOG2  (AD_FIFO_DEPTH_LOG2),
    .IN_FIFO_DEPTH_LOG2  (IN_FIFO_DEPTH_LOG2),
    .OUT_FIFO_DEPTH_LOG2 (OUT_FIFO_DEPTH_LOG2)
  ) u_mmio (
    .clk          (clk),
    .rst_n        (rst_n),
    .reg_valid_i  (reg_valid_q),
    .reg_ready_o  (reg_ready_w),
    .reg_write_i  (reg_write_q),
    .reg_addr_i   (reg_addr_q),
    .reg_wdata_i  (reg_wdata_q),
    .reg_wstrb_i  (reg_wstrb_q),
    .reg_rdata_o  (reg_rdata_w),
    .irq_o        (irq_o)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_valid_q <= 1'b0;
      reg_write_q <= 1'b0;
      reg_addr_q  <= 8'd0;
      reg_wdata_q <= 32'd0;
      reg_wstrb_q <= 4'd0;
      pending_q   <= 1'b0;
      xbus_dat_o  <= 32'd0;
      xbus_ack_o  <= 1'b0;
      xbus_err_o  <= 1'b0;
    end else begin
      xbus_ack_o <= 1'b0;
      xbus_err_o <= 1'b0;

      if (complete_w) begin
        xbus_dat_o  <= reg_rdata_w;
        xbus_ack_o  <= 1'b1;
        reg_valid_q <= 1'b0;
        pending_q   <= 1'b0;
      end

      if (miss_w && !pending_q && !reg_valid_q && (ERROR_ON_MISS != 0)) begin
        xbus_err_o <= 1'b1;
      end

      if (launch_w) begin
        reg_valid_q <= 1'b1;
        reg_write_q <= xbus_we_i;
        reg_addr_q  <= xbus_adr_i[7:0];
        reg_wdata_q <= xbus_dat_i;
        reg_wstrb_q <= xbus_sel_i;
        pending_q   <= 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
