//=====================================================================
// File        : uart_assertions.sv
// Description : SVA checker module.  Instantiated once in tb_top and
//               wired to the uart_if signals.  It provides the
//               cycle-accurate protocol checking that the transaction
//               level scoreboard cannot see, plus cover properties that
//               prove the interesting situations were actually reached.
//
//               'reset' is ACTIVE LOW.  Every property that describes
//               normal operation carries an explicit
//               "disable iff (!reset)"; the reset properties are the
//               ones that must stay live while reset is asserted, so
//               they deliberately carry no disable clause.
//=====================================================================
`ifndef UART_ASSERTIONS_SV
`define UART_ASSERTIONS_SV

module uart_assertions #(
  parameter int DATA_WIDTH = 8,
  parameter int OVERSAMPLE = 16,
  parameter int DIV_WIDTH  = 16
)(
  input logic                  clock,
  input logic                  reset,          // ACTIVE LOW
  input logic                  start,
  input logic [DATA_WIDTH-1:0] tx_data,
  input logic                  busy,
  input logic                  done,
  input logic                  tx,
  input logic                  rx,
  input logic [DATA_WIDTH-1:0] rx_data,
  input logic                  rx_valid,
  input logic                  rx_busy,
  input logic                  parity_error,
  input logic                  framing_error,
  input logic                  break_detect,
  input logic                  fifo_full,
  input logic                  fifo_empty,
  input logic                  overrun_error,
  input logic                  overrun_pulse,
  input logic                  parity_en,
  input logic                  parity_type,
  input logic                  stop_bits,
  input logic [DIV_WIDTH-1:0]  baud_div,
  input logic                  baud_tick
);

  // Longest possible frame: 12 bit times at the slowest divider used by
  // the testbench (54), plus margin.
  localparam int MAX_FRAME_CLK = 54 * OVERSAMPLE * 12 + 64;

  default clocking cb @(posedge clock); endclocking

  //===================================================================
  // 1. Reset behaviour   (live WHILE reset is asserted - no disable)
  //===================================================================
  a_reset_tx_idle : assert property (!reset |-> (tx === 1'b1))
    else $error("[UART_SVA] tx must idle HIGH while reset is asserted");

  a_reset_quiet : assert property
    (!reset |-> ((busy === 1'b0) && (done === 1'b0) &&
                 (rx_valid === 1'b0) && (overrun_error === 1'b0)))
    else $error("[UART_SVA] status flags must be clear while reset is asserted");

  a_reset_fifo_empty : assert property (!reset |-> (fifo_empty === 1'b1))
    else $error("[UART_SVA] rx FIFO must be empty while reset is asserted");

  //===================================================================
  // 2. No X / Z on the observable signals once out of reset
  //===================================================================
  a_no_x_serial : assert property
    (disable iff (!reset) !$isunknown({tx, rx}))
    else $error("[UART_SVA] X/Z detected on a serial line");

  a_no_x_status : assert property
    (disable iff (!reset)
     !$isunknown({busy, done, rx_valid, rx_busy, parity_error,
                  framing_error, break_detect, fifo_full, fifo_empty,
                  overrun_error, overrun_pulse, baud_tick}))
    else $error("[UART_SVA] X/Z detected on a status signal");

  a_no_x_cfg : assert property
    (disable iff (!reset)
     !$isunknown({parity_en, parity_type, stop_bits, baud_div}))
    else $error("[UART_SVA] X/Z detected on the configuration bus");

  a_no_x_rxdata : assert property
    (disable iff (!reset) rx_valid |-> !$isunknown(rx_data))
    else $error("[UART_SVA] X/Z detected on rx_data when rx_valid is high");

  //===================================================================
  // 3. Transmit protocol
  //===================================================================
  // The line idles high whenever the transmitter is not busy.
  a_tx_idle_high : assert property
    (disable iff (!reset) !busy |-> (tx === 1'b1))
    else $error("[UART_SVA] tx is not HIGH while the transmitter is idle");

  // A start request that is accepted must raise busy on the next clock.
  a_start_raises_busy : assert property
    (disable iff (!reset) (start && !busy) |=> busy)
    else $error("[UART_SVA] start accepted but busy did not rise");

  // Accepting a start must pull the line low: that is the START bit.
  a_start_bit_low : assert property
    (disable iff (!reset) (start && !busy) |=> (tx === 1'b0))
    else $error("[UART_SVA] START bit was not driven LOW");

  // done is a single-cycle pulse and coincides with busy dropping.
  a_done_pulse : assert property
    (disable iff (!reset) done |=> !done)
    else $error("[UART_SVA] done is not a single-cycle pulse");

  a_done_not_busy : assert property
    (disable iff (!reset) done |-> !busy)
    else $error("[UART_SVA] done asserted while still busy");

  a_done_after_busy : assert property
    (disable iff (!reset) done |-> $past(busy))
    else $error("[UART_SVA] done asserted without a preceding frame");

  // At the end of a frame the line must have returned to the STOP level.
  a_stop_bit_high : assert property
    (disable iff (!reset) done |-> (tx === 1'b1))
    else $error("[UART_SVA] STOP bit was not HIGH at the end of the frame");

  // Frame length: every started frame terminates within the maximum
  // frame time for the slowest supported baud divider.
  a_frame_terminates : assert property
    (disable iff (!reset) $rose(busy) |-> ##[1:MAX_FRAME_CLK] done)
    else $error("[UART_SVA] transmit frame did not terminate in time");

  //===================================================================
  // 4. Baud / oversampling timing
  //===================================================================
  a_baud_tick_pulse : assert property
    (disable iff (!reset) baud_tick |=> !baud_tick)
    else $error("[UART_SVA] baud_tick must be a single-cycle pulse");

  a_baud_div_legal : assert property
    (disable iff (!reset) baud_div >= 2)
    else $error("[UART_SVA] baud_div must be >= 2");

  // The tick generator is free running: a tick is always followed by
  // another one within one maximum divider period.
  a_baud_tick_live : assert property
    (disable iff (!reset) baud_tick |-> ##[1:256] baud_tick)
    else $error("[UART_SVA] the baud tick generator stopped");

  //===================================================================
  // 5. Receive protocol
  //===================================================================
  a_rx_valid_pulse : assert property
    (disable iff (!reset) rx_valid |=> !rx_valid)
    else $error("[UART_SVA] rx_valid must be a single-cycle pulse");

  a_rx_valid_after_busy : assert property
    (disable iff (!reset) rx_valid |-> $past(rx_busy))
    else $error("[UART_SVA] rx_valid asserted without an active frame");

  // Parity errors can only exist when parity checking is enabled.
  a_parity_err_needs_parity : assert property
    (disable iff (!reset) (rx_valid && parity_error) |-> parity_en)
    else $error("[UART_SVA] parity_error reported with parity disabled");

  // A BREAK is by definition also a framing error.
  a_break_implies_framing : assert property
    (disable iff (!reset) (rx_valid && break_detect) |-> framing_error)
    else $error("[UART_SVA] break_detect without framing_error");

  // A BREAK always delivers an all-zero character.
  a_break_data_zero : assert property
    (disable iff (!reset) (rx_valid && break_detect) |-> (rx_data == '0))
    else $error("[UART_SVA] break_detect with non-zero data");

  //===================================================================
  // 6. FIFO / overrun
  //===================================================================
  a_fifo_flags_exclusive : assert property
    (disable iff (!reset) !(fifo_full && fifo_empty))
    else $error("[UART_SVA] FIFO reports full and empty at the same time");

  a_overrun_needs_full : assert property
    (disable iff (!reset) overrun_pulse |-> fifo_full)
    else $error("[UART_SVA] overrun pulsed while the FIFO had room");

  a_overrun_needs_valid : assert property
    (disable iff (!reset) overrun_pulse |-> rx_valid)
    else $error("[UART_SVA] overrun pulsed without a completed character");

  a_overrun_sticky : assert property
    (disable iff (!reset) overrun_error |=> overrun_error)
    else $error("[UART_SVA] the sticky overrun status cleared itself");

  //===================================================================
  // 7. Cover properties - proof the interesting cases were reached
  //===================================================================
  c_tx_frame        : cover property (disable iff (!reset)
                        $rose(busy) ##[1:MAX_FRAME_CLK] done);
  c_rx_char         : cover property (disable iff (!reset)
                        rx_valid && !parity_error &&
                        !framing_error && !break_detect);
  c_rx_parity_err   : cover property (disable iff (!reset)
                        rx_valid && parity_error);
  c_rx_framing_err  : cover property (disable iff (!reset)
                        rx_valid && framing_error && !break_detect);
  c_rx_break        : cover property (disable iff (!reset)
                        rx_valid && break_detect);
  c_rx_overrun      : cover property (disable iff (!reset) overrun_pulse);
  c_parity_enabled  : cover property (disable iff (!reset)
                        rx_valid && parity_en);
  c_two_stop_bits   : cover property (disable iff (!reset)
                        rx_valid && stop_bits);
  c_back_to_back_tx : cover property (disable iff (!reset)
                        done ##[1:MAX_FRAME_CLK] $rose(busy));
  c_fifo_full       : cover property (disable iff (!reset) $rose(fifo_full));

endmodule : uart_assertions

`endif // UART_ASSERTIONS_SV
