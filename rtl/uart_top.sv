//=====================================================================
// File        : uart_top.sv
// Description : UART top level.  Instantiates the baud generator, the
//               transmitter, the receiver and the receive FIFO and
//               exposes the complete programming / status interface that
//               the UVM environment drives and samples.
//
//               Clock       : 50 MHz
//               Baud        : programmable via baud_div (27 -> 115200)
//               Oversample  : 16x
//               Flow control: none
//               Reset       : active low, asynchronous
//=====================================================================
`ifndef UART_TOP_SV
`define UART_TOP_SV

module uart_top #(
  parameter int DATA_WIDTH = 8,
  parameter int OVERSAMPLE = 16,
  parameter int FIFO_DEPTH = 16,
  parameter int DIV_WIDTH  = 16
)(
  input  logic                        clk,
  input  logic                        rst_n,

  // ------------- configuration -------------
  input  logic                        parity_en,
  input  logic                        parity_type,   // 0 = EVEN, 1 = ODD
  input  logic                        stop_bits,     // 0 = 1 stop, 1 = 2 stop
  input  logic [DIV_WIDTH-1:0]        baud_div,

  // ------------- transmit (parallel) -------------
  input  logic                        tx_start,
  input  logic [DATA_WIDTH-1:0]       tx_data,
  output logic                        tx_busy,
  output logic                        tx_done,
  output logic                        tx,

  // ------------- receive (serial) -------------
  input  logic                        rx,

  // ------------- receive (parallel) -------------
  output logic [DATA_WIDTH-1:0]       rx_data,
  output logic                        rx_valid,
  output logic                        rx_busy,
  output logic                        rx_parity_error,
  output logic                        rx_framing_error,
  output logic                        rx_break_detect,

  // ------------- receive FIFO -------------
  input  logic                        rx_read,
  output logic [DATA_WIDTH-1:0]       fifo_data,
  output logic                        fifo_empty,
  output logic                        fifo_full,
  output logic                        overrun_error, // sticky
  output logic                        overrun_pulse, // per-character

  // ------------- observation -------------
  output logic                        baud_tick
);

  localparam int CNT_W = $clog2(FIFO_DEPTH+1);

  logic [CNT_W-1:0] fifo_count;

  // ------------------------------------------------------------------
  // Baud / oversampling tick generator
  // ------------------------------------------------------------------
  baud_generator #(
    .DIV_WIDTH (DIV_WIDTH)
  ) u_baud_gen (
    .clk      (clk),
    .rst_n    (rst_n),
    .enable   (1'b1),
    .baud_div (baud_div),
    .tick     (baud_tick)
  );

  // ------------------------------------------------------------------
  // Transmitter
  // ------------------------------------------------------------------
  uart_tx #(
    .DATA_WIDTH (DATA_WIDTH),
    .OVERSAMPLE (OVERSAMPLE)
  ) u_uart_tx (
    .clk         (clk),
    .rst_n       (rst_n),
    .baud_tick   (baud_tick),
    .start       (tx_start),
    .data_in     (tx_data),
    .parity_en   (parity_en),
    .parity_type (parity_type),
    .stop_bits   (stop_bits),
    .tx          (tx),
    .busy        (tx_busy),
    .done        (tx_done)
  );

  // ------------------------------------------------------------------
  // Receiver
  // ------------------------------------------------------------------
  uart_rx #(
    .DATA_WIDTH (DATA_WIDTH),
    .OVERSAMPLE (OVERSAMPLE)
  ) u_uart_rx (
    .clk           (clk),
    .rst_n         (rst_n),
    .baud_tick     (baud_tick),
    .rx            (rx),
    .parity_en     (parity_en),
    .parity_type   (parity_type),
    .stop_bits     (stop_bits),
    .data_out      (rx_data),
    .valid         (rx_valid),
    .parity_error  (rx_parity_error),
    .framing_error (rx_framing_error),
    .break_detect  (rx_break_detect),
    .busy          (rx_busy)
  );

  // ------------------------------------------------------------------
  // Receive FIFO
  // ------------------------------------------------------------------
  uart_fifo #(
    .WIDTH (DATA_WIDTH),
    .DEPTH (FIFO_DEPTH)
  ) u_rx_fifo (
    .clk      (clk),
    .rst_n    (rst_n),
    .wr_en    (rx_valid),
    .wr_data  (rx_data),
    .rd_en    (rx_read),
    .rd_data  (fifo_data),
    .full     (fifo_full),
    .empty    (fifo_empty),
    .overflow (overrun_error),
    .count    (fifo_count)
  );

  // A character completed while the FIFO had no room for it.
  assign overrun_pulse = rx_valid & fifo_full;

endmodule : uart_top

`endif // UART_TOP_SV
