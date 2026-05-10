`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Phase 5.3 AXI wrapper:
//   - AXI4-Lite control/status register file
//   - AXI4-Stream associated-data input
//   - AXI4-Stream payload input
//   - AXI4-Stream payload output
//
// This is intentionally a single-operation-mode wrapper.  The DECRYPT
// parameter selects encrypt/decrypt at elaboration time so synthesis does not
// instantiate both datapaths.
//
// AXI-Lite register map, byte offsets:
//   0x00 CTRL       W: bit0=start, bit1=clear, bit2=result_ack
//   0x04 STATUS     R: bit0=start_ready, bit1=busy, bit2=done_latched,
//                       bit3=result_valid, bit4=auth_ok,
//                       bit8=ad_keep_error, bit9=data_keep_error,
//                       bit16=ad_fifo_empty, bit17=ad_fifo_full,
//                       bit18=data_in_fifo_empty, bit19=data_in_fifo_full,
//                       bit20=data_out_fifo_empty, bit21=data_out_fifo_full
//   0x08 AD_BYTES   RW
//   0x0c MSG_BYTES  RW
//   0x10..0x1c KEY      RW, little 32-bit word lanes
//   0x20..0x2c NONCE    RW, little 32-bit word lanes
//   0x30..0x3c TAG_IN   RW, used by decrypt
//   0x50..0x5c RESULT   R, tag for encrypt, zero for decrypt
//   0x60 LEVELS     R: fifo levels packed into bytes
//
// AXI-Lite notes:
//   This is a compact slave implementation.  AW and W are accepted together;
//   AR is accepted independently.  BRESP/RRESP are always OKAY.

`default_nettype none

module ascon_aead128_axi #(
  parameter integer DECRYPT             = 0,
  parameter integer ROUNDS_PER_CYCLE    = 1,
  parameter integer AD_FIFO_DEPTH_LOG2   = 2,
  parameter integer IN_FIFO_DEPTH_LOG2   = 2,
  parameter integer OUT_FIFO_DEPTH_LOG2  = 2
) (
  input  wire         clk,
  input  wire         rst_n,

  input  wire [31:0]  s_axil_awaddr_i,
  input  wire         s_axil_awvalid_i,
  output wire         s_axil_awready_o,

  input  wire [31:0]  s_axil_wdata_i,
  input  wire [3:0]   s_axil_wstrb_i,
  input  wire         s_axil_wvalid_i,
  output wire         s_axil_wready_o,

  output wire [1:0]   s_axil_bresp_o,
  output wire         s_axil_bvalid_o,
  input  wire         s_axil_bready_i,

  input  wire [31:0]  s_axil_araddr_i,
  input  wire         s_axil_arvalid_i,
  output wire         s_axil_arready_o,

  output wire [31:0]  s_axil_rdata_o,
  output wire [1:0]   s_axil_rresp_o,
  output wire         s_axil_rvalid_o,
  input  wire         s_axil_rready_i,

  input  wire         s_axis_ad_tvalid_i,
  output wire         s_axis_ad_tready_o,
  input  wire [127:0] s_axis_ad_tdata_i,
  input  wire [15:0]  s_axis_ad_tkeep_i,
  input  wire         s_axis_ad_tlast_i,

  input  wire         s_axis_data_tvalid_i,
  output wire         s_axis_data_tready_o,
  input  wire [127:0] s_axis_data_tdata_i,
  input  wire [15:0]  s_axis_data_tkeep_i,
  input  wire         s_axis_data_tlast_i,

  output wire         m_axis_data_tvalid_o,
  input  wire         m_axis_data_tready_i,
  output wire [127:0] m_axis_data_tdata_o,
  output wire [15:0]  m_axis_data_tkeep_o,
  output wire         m_axis_data_tlast_o
);

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
  localparam [7:0] ADDR_TAGIN0    = 8'h30;
  localparam [7:0] ADDR_TAGIN1    = 8'h34;
  localparam [7:0] ADDR_TAGIN2    = 8'h38;
  localparam [7:0] ADDR_TAGIN3    = 8'h3c;
  localparam [7:0] ADDR_RESULT0   = 8'h50;
  localparam [7:0] ADDR_RESULT1   = 8'h54;
  localparam [7:0] ADDR_RESULT2   = 8'h58;
  localparam [7:0] ADDR_RESULT3   = 8'h5c;
  localparam [7:0] ADDR_LEVELS    = 8'h60;

  reg [31:0] ad_bytes_q;
  reg [31:0] msg_bytes_q;
  reg [127:0] key_q;
  reg [127:0] nonce_q;
  reg [127:0] tag_in_q;

  reg start_pulse_q;
  reg clear_pulse_q;
  reg result_ack_pulse_q;

  reg bvalid_q;
  reg rvalid_q;
  reg [31:0] rdata_q;

  reg result_hold_q;
  reg [127:0] result_tag_q;
  reg result_auth_ok_q;
  reg done_latched_q;
  reg ad_keep_error_q;
  reg data_keep_error_q;

  wire start_ready_w;
  wire busy_w;
  wire done_w;

  wire axis_result_valid_w;
  wire axis_result_ready_w;
  wire [127:0] axis_result_tag_w;
  wire axis_result_auth_ok_w;

  wire ad_keep_error_w;
  wire data_keep_error_w;

  wire ad_fifo_empty_w;
  wire ad_fifo_full_w;
  wire [AD_FIFO_DEPTH_LOG2:0] ad_fifo_level_w;
  wire data_in_fifo_empty_w;
  wire data_in_fifo_full_w;
  wire [IN_FIFO_DEPTH_LOG2:0] data_in_fifo_level_w;
  wire data_out_fifo_empty_w;
  wire data_out_fifo_full_w;
  wire [OUT_FIFO_DEPTH_LOG2:0] data_out_fifo_level_w;

  wire axil_write_fire_w = s_axil_awvalid_i && s_axil_wvalid_i && s_axil_awready_o && s_axil_wready_o;
  wire axil_read_fire_w  = s_axil_arvalid_i && s_axil_arready_o;

  assign s_axil_awready_o = !bvalid_q;
  assign s_axil_wready_o  = !bvalid_q;
  assign s_axil_bresp_o   = 2'b00;
  assign s_axil_bvalid_o  = bvalid_q;

  assign s_axil_arready_o = !rvalid_q;
  assign s_axil_rresp_o   = 2'b00;
  assign s_axil_rvalid_o  = rvalid_q;
  assign s_axil_rdata_o   = rdata_q;

  assign axis_result_ready_w = !result_hold_q;

  wire result_capture_w = axis_result_valid_w && axis_result_ready_w;

  function [31:0] apply_wstrb32;
    input [31:0] old_v;
    input [31:0] new_v;
    input [3:0]  strobe;
    integer i;
    begin
      apply_wstrb32 = old_v;
      for (i = 0; i < 4; i = i + 1) begin
        if (strobe[i]) begin
          apply_wstrb32[(8*i)+:8] = new_v[(8*i)+:8];
        end
      end
    end
  endfunction

  function [31:0] status_word;
    begin
      status_word = 32'd0;
      status_word[0]  = start_ready_w;
      status_word[1]  = busy_w;
      status_word[2]  = done_latched_q;
      status_word[3]  = result_hold_q;
      status_word[4]  = result_auth_ok_q;
      status_word[8]  = ad_keep_error_q;
      status_word[9]  = data_keep_error_q;
      status_word[16] = ad_fifo_empty_w;
      status_word[17] = ad_fifo_full_w;
      status_word[18] = data_in_fifo_empty_w;
      status_word[19] = data_in_fifo_full_w;
      status_word[20] = data_out_fifo_empty_w;
      status_word[21] = data_out_fifo_full_w;
    end
  endfunction

  function [31:0] levels_word;
    begin
      levels_word = 32'd0;
      levels_word[7:0]   = {{(7-AD_FIFO_DEPTH_LOG2){1'b0}}, ad_fifo_level_w};
      levels_word[15:8]  = {{(7-IN_FIFO_DEPTH_LOG2){1'b0}}, data_in_fifo_level_w};
      levels_word[23:16] = {{(7-OUT_FIFO_DEPTH_LOG2){1'b0}}, data_out_fifo_level_w};
    end
  endfunction

  function [31:0] read_mux;
    input [7:0] addr;
    begin
      case (addr)
        ADDR_CTRL:      read_mux = 32'd0;
        ADDR_STATUS:    read_mux = status_word();
        ADDR_AD_BYTES:  read_mux = ad_bytes_q;
        ADDR_MSG_BYTES: read_mux = msg_bytes_q;
        ADDR_KEY0:      read_mux = key_q[31:0];
        ADDR_KEY1:      read_mux = key_q[63:32];
        ADDR_KEY2:      read_mux = key_q[95:64];
        ADDR_KEY3:      read_mux = key_q[127:96];
        ADDR_NONCE0:    read_mux = nonce_q[31:0];
        ADDR_NONCE1:    read_mux = nonce_q[63:32];
        ADDR_NONCE2:    read_mux = nonce_q[95:64];
        ADDR_NONCE3:    read_mux = nonce_q[127:96];
        ADDR_TAGIN0:    read_mux = tag_in_q[31:0];
        ADDR_TAGIN1:    read_mux = tag_in_q[63:32];
        ADDR_TAGIN2:    read_mux = tag_in_q[95:64];
        ADDR_TAGIN3:    read_mux = tag_in_q[127:96];
        ADDR_RESULT0:   read_mux = result_tag_q[31:0];
        ADDR_RESULT1:   read_mux = result_tag_q[63:32];
        ADDR_RESULT2:   read_mux = result_tag_q[95:64];
        ADDR_RESULT3:   read_mux = result_tag_q[127:96];
        ADDR_LEVELS:    read_mux = levels_word();
        default:        read_mux = 32'd0;
      endcase
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ad_bytes_q <= 32'd0;
      msg_bytes_q <= 32'd0;
      key_q <= 128'd0;
      nonce_q <= 128'd0;
      tag_in_q <= 128'd0;

      start_pulse_q <= 1'b0;
      clear_pulse_q <= 1'b0;
      result_ack_pulse_q <= 1'b0;

      bvalid_q <= 1'b0;
      rvalid_q <= 1'b0;
      rdata_q <= 32'd0;

      result_hold_q <= 1'b0;
      result_tag_q <= 128'd0;
      result_auth_ok_q <= 1'b0;
      done_latched_q <= 1'b0;
      ad_keep_error_q <= 1'b0;
      data_keep_error_q <= 1'b0;
    end else begin
      start_pulse_q <= 1'b0;
      clear_pulse_q <= 1'b0;
      result_ack_pulse_q <= 1'b0;

      if (bvalid_q && s_axil_bready_i) begin
        bvalid_q <= 1'b0;
      end

      if (rvalid_q && s_axil_rready_i) begin
        rvalid_q <= 1'b0;
      end

      if (done_w) begin
        done_latched_q <= 1'b1;
      end

      if (ad_keep_error_w) begin
        ad_keep_error_q <= 1'b1;
      end

      if (data_keep_error_w) begin
        data_keep_error_q <= 1'b1;
      end

      if (result_capture_w) begin
        result_hold_q <= 1'b1;
        result_tag_q <= axis_result_tag_w;
        result_auth_ok_q <= axis_result_auth_ok_w;
      end

      if (axil_write_fire_w) begin
        bvalid_q <= 1'b1;

        case (s_axil_awaddr_i[7:0])
          ADDR_CTRL: begin
            start_pulse_q <= s_axil_wdata_i[0];
            clear_pulse_q <= s_axil_wdata_i[1];
            result_ack_pulse_q <= s_axil_wdata_i[2];

            if (s_axil_wdata_i[1]) begin
              done_latched_q <= 1'b0;
              result_hold_q <= 1'b0;
              result_tag_q <= 128'd0;
              result_auth_ok_q <= 1'b0;
              ad_keep_error_q <= 1'b0;
              data_keep_error_q <= 1'b0;
            end

            if (s_axil_wdata_i[2]) begin
              result_hold_q <= 1'b0;
              result_tag_q <= 128'd0;
              result_auth_ok_q <= 1'b0;
              done_latched_q <= 1'b0;
            end
          end

          ADDR_AD_BYTES:  ad_bytes_q <= apply_wstrb32(ad_bytes_q, s_axil_wdata_i, s_axil_wstrb_i);
          ADDR_MSG_BYTES: msg_bytes_q <= apply_wstrb32(msg_bytes_q, s_axil_wdata_i, s_axil_wstrb_i);

          ADDR_KEY0: key_q[31:0]    <= apply_wstrb32(key_q[31:0], s_axil_wdata_i, s_axil_wstrb_i);
          ADDR_KEY1: key_q[63:32]   <= apply_wstrb32(key_q[63:32], s_axil_wdata_i, s_axil_wstrb_i);
          ADDR_KEY2: key_q[95:64]   <= apply_wstrb32(key_q[95:64], s_axil_wdata_i, s_axil_wstrb_i);
          ADDR_KEY3: key_q[127:96]  <= apply_wstrb32(key_q[127:96], s_axil_wdata_i, s_axil_wstrb_i);

          ADDR_NONCE0: nonce_q[31:0]   <= apply_wstrb32(nonce_q[31:0], s_axil_wdata_i, s_axil_wstrb_i);
          ADDR_NONCE1: nonce_q[63:32]  <= apply_wstrb32(nonce_q[63:32], s_axil_wdata_i, s_axil_wstrb_i);
          ADDR_NONCE2: nonce_q[95:64]  <= apply_wstrb32(nonce_q[95:64], s_axil_wdata_i, s_axil_wstrb_i);
          ADDR_NONCE3: nonce_q[127:96] <= apply_wstrb32(nonce_q[127:96], s_axil_wdata_i, s_axil_wstrb_i);

          ADDR_TAGIN0: tag_in_q[31:0]   <= apply_wstrb32(tag_in_q[31:0], s_axil_wdata_i, s_axil_wstrb_i);
          ADDR_TAGIN1: tag_in_q[63:32]  <= apply_wstrb32(tag_in_q[63:32], s_axil_wdata_i, s_axil_wstrb_i);
          ADDR_TAGIN2: tag_in_q[95:64]  <= apply_wstrb32(tag_in_q[95:64], s_axil_wdata_i, s_axil_wstrb_i);
          ADDR_TAGIN3: tag_in_q[127:96] <= apply_wstrb32(tag_in_q[127:96], s_axil_wdata_i, s_axil_wstrb_i);

          default: begin
          end
        endcase
      end

      if (axil_read_fire_w) begin
        rvalid_q <= 1'b1;
        rdata_q <= read_mux(s_axil_araddr_i[7:0]);
      end
    end
  end

  ascon_aead128_axis #(
    .DECRYPT             (DECRYPT),
    .ROUNDS_PER_CYCLE    (ROUNDS_PER_CYCLE),
    .AD_FIFO_DEPTH_LOG2   (AD_FIFO_DEPTH_LOG2),
    .IN_FIFO_DEPTH_LOG2   (IN_FIFO_DEPTH_LOG2),
    .OUT_FIFO_DEPTH_LOG2  (OUT_FIFO_DEPTH_LOG2)
  ) u_axis_core (
    .clk                       (clk),
    .rst_n                     (rst_n),
    .clear_i                   (clear_pulse_q),

    .start_i                   (start_pulse_q),
    .start_ready_o             (start_ready_w),
    .key_i                     (key_q),
    .nonce_i                   (nonce_q),
    .ad_bytes_i                (ad_bytes_q),
    .msg_bytes_i               (msg_bytes_q),
    .tag_i                     (tag_in_q),

    .busy_o                    (busy_w),
    .done_o                    (done_w),

    .s_axis_ad_tvalid_i        (s_axis_ad_tvalid_i),
    .s_axis_ad_tready_o        (s_axis_ad_tready_o),
    .s_axis_ad_tdata_i         (s_axis_ad_tdata_i),
    .s_axis_ad_tkeep_i         (s_axis_ad_tkeep_i),
    .s_axis_ad_tlast_i         (s_axis_ad_tlast_i),
    .s_axis_ad_keep_error_o    (ad_keep_error_w),

    .s_axis_data_tvalid_i      (s_axis_data_tvalid_i),
    .s_axis_data_tready_o      (s_axis_data_tready_o),
    .s_axis_data_tdata_i       (s_axis_data_tdata_i),
    .s_axis_data_tkeep_i       (s_axis_data_tkeep_i),
    .s_axis_data_tlast_i       (s_axis_data_tlast_i),
    .s_axis_data_keep_error_o  (data_keep_error_w),

    .m_axis_data_tvalid_o      (m_axis_data_tvalid_o),
    .m_axis_data_tready_i      (m_axis_data_tready_i),
    .m_axis_data_tdata_o       (m_axis_data_tdata_o),
    .m_axis_data_tkeep_o       (m_axis_data_tkeep_o),
    .m_axis_data_tlast_o       (m_axis_data_tlast_o),

    .result_valid_o            (axis_result_valid_w),
    .result_ready_i            (axis_result_ready_w),
    .result_tag_o              (axis_result_tag_w),
    .result_auth_ok_o          (axis_result_auth_ok_w),

    .ad_fifo_empty_o           (ad_fifo_empty_w),
    .ad_fifo_full_o            (ad_fifo_full_w),
    .ad_fifo_level_o           (ad_fifo_level_w),

    .data_in_fifo_empty_o      (data_in_fifo_empty_w),
    .data_in_fifo_full_o       (data_in_fifo_full_w),
    .data_in_fifo_level_o      (data_in_fifo_level_w),

    .data_out_fifo_empty_o     (data_out_fifo_empty_w),
    .data_out_fifo_full_o      (data_out_fifo_full_w),
    .data_out_fifo_level_o     (data_out_fifo_level_w)
  );

endmodule

`default_nettype wire
