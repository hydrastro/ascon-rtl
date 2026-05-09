// SPDX-License-Identifier: Apache-2.0
//
// Small single-clock ready/valid FIFO for ASCON stream wrappers.
//
// This FIFO is intentionally generic: wrappers can use it for AD blocks,
// payload blocks, tags, descriptors, or status words. It is register-based,
// supports one enqueue and one dequeue in the same cycle, and keeps in_ready_o
// asserted when full if the output side is also consuming a word.

`default_nettype none

module ascon_stream_fifo #(
  parameter integer WIDTH      = 128,
  parameter integer DEPTH_LOG2 = 2
) (
  input  wire             clk,
  input  wire             rst_n,

  input  wire             clear_i,

  input  wire             in_valid_i,
  output wire             in_ready_o,
  input  wire [WIDTH-1:0] in_data_i,

  output wire             out_valid_o,
  input  wire             out_ready_i,
  output wire [WIDTH-1:0] out_data_o,

  output wire             empty_o,
  output wire             full_o,
  output wire [DEPTH_LOG2:0] level_o
);

  localparam integer DEPTH = (1 << DEPTH_LOG2);
  localparam [DEPTH_LOG2:0] DEPTH_COUNT = (1 << DEPTH_LOG2);

  reg [WIDTH-1:0] mem_q [0:DEPTH-1];
  reg [DEPTH_LOG2-1:0] rd_ptr_q;
  reg [DEPTH_LOG2-1:0] wr_ptr_q;
  reg [DEPTH_LOG2:0]   count_q;

  wire empty_w = (count_q == {1'b0, {DEPTH_LOG2{1'b0}}});
  wire full_w  = (count_q == DEPTH_COUNT);

  wire out_fire_w = out_valid_o && out_ready_i;
  wire in_fire_w  = in_valid_i && in_ready_o;

  assign empty_o     = empty_w;
  assign full_o      = full_w;
  assign level_o     = count_q;
  assign out_valid_o = !empty_w;
  assign in_ready_o  = !full_w || out_fire_w;
  assign out_data_o  = mem_q[rd_ptr_q];

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr_q <= {DEPTH_LOG2{1'b0}};
      wr_ptr_q <= {DEPTH_LOG2{1'b0}};
      count_q  <= {1'b0, {DEPTH_LOG2{1'b0}}};
      for (i = 0; i < DEPTH; i = i + 1) begin
        mem_q[i] <= {WIDTH{1'b0}};
      end
    end else if (clear_i) begin
      rd_ptr_q <= {DEPTH_LOG2{1'b0}};
      wr_ptr_q <= {DEPTH_LOG2{1'b0}};
      count_q  <= {1'b0, {DEPTH_LOG2{1'b0}}};
    end else begin
      if (in_fire_w) begin
        mem_q[wr_ptr_q] <= in_data_i;
        wr_ptr_q <= wr_ptr_q + {{(DEPTH_LOG2-1){1'b0}}, 1'b1};
      end

      if (out_fire_w) begin
        rd_ptr_q <= rd_ptr_q + {{(DEPTH_LOG2-1){1'b0}}, 1'b1};
      end

      case ({in_fire_w, out_fire_w})
        2'b10: count_q <= count_q + {{DEPTH_LOG2{1'b0}}, 1'b1};
        2'b01: count_q <= count_q - {{DEPTH_LOG2{1'b0}}, 1'b1};
        default: count_q <= count_q;
      endcase
    end
  end

endmodule

`default_nettype wire
