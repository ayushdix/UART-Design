//=====================================================================
// File        : uart_fifo.sv
// Description : Synchronous receive FIFO used to buffer characters that
//               have been assembled by uart_rx.  Its 'full' flag is what
//               makes the OVERRUN condition observable: if a new
//               character completes while the FIFO is full the character
//               is dropped and the overrun status is raised by uart_top.
//=====================================================================
`ifndef UART_FIFO_SV
`define UART_FIFO_SV

module uart_fifo #(
  parameter int WIDTH = 8,
  parameter int DEPTH = 16
)(
  input  logic                        clk,
  input  logic                        rst_n,     // active low
  input  logic                        wr_en,
  input  logic [WIDTH-1:0]            wr_data,
  input  logic                        rd_en,
  output logic [WIDTH-1:0]            rd_data,
  output logic                        full,
  output logic                        empty,
  output logic                        overflow,  // sticky: write while full
  output logic [$clog2(DEPTH+1)-1:0]  count
);

  localparam int PTR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam int CNT_W = $clog2(DEPTH+1);

  logic [WIDTH-1:0] mem [DEPTH];
  logic [PTR_W-1:0] wr_ptr, rd_ptr;

  assign full  = (count == CNT_W'(DEPTH));
  assign empty = (count == '0);

  wire do_wr = wr_en && !full;
  wire do_rd = rd_en && !empty;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr   <= '0;
      rd_ptr   <= '0;
      count    <= '0;
      rd_data  <= '0;
      overflow <= 1'b0;
    end
    else begin
      if (do_wr) begin
        mem[wr_ptr] <= wr_data;
        wr_ptr      <= (wr_ptr == PTR_W'(DEPTH-1)) ? '0 : (wr_ptr + 1'b1);
      end

      if (do_rd) begin
        rd_data <= mem[rd_ptr];
        rd_ptr  <= (rd_ptr == PTR_W'(DEPTH-1)) ? '0 : (rd_ptr + 1'b1);
      end

      case ({do_wr, do_rd})
        2'b10   : count <= count + 1'b1;
        2'b01   : count <= count - 1'b1;
        default : count <= count;
      endcase

      if (wr_en && full) overflow <= 1'b1;
    end
  end

endmodule : uart_fifo

`endif // UART_FIFO_SV
