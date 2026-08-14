//=====================================================================
// File        : uart_if.sv
// Description : UART verification interface.  This is the single point of
//               contact between the UVM environment and the DUT.
//
//               Signal ownership (one writer per signal - no contention):
//                 start / tx_data      -> uart_tx_driver   (drv_cb)
//                 rx / rx_read         -> uart_rx_driver   (rx_drv_cb)
//                 reset / cfg signals  -> interface tasks  (do_reset/set_cfg)
//                 everything else      -> DUT outputs
//
//               Clocking blocks:
//                 drv_cb     - TX (parallel) driver
//                 rx_drv_cb  - RX (serial) driver + FIFO reader
//                 mon_cb     - all monitors (input only, #1step sampling)
//
//               Modports:
//                 DRV / RX_DRV / MON / ASSERT
//=====================================================================
`ifndef UART_IF_SV
`define UART_IF_SV

interface uart_if #(
  parameter int DATA_WIDTH = 8,
  parameter int DIV_WIDTH  = 16
) (
  input logic clock
);

  //-------------------------------------------------------------------
  // Signals
  //-------------------------------------------------------------------
  logic                  reset;          // ACTIVE LOW

  // TX parallel side
  logic                  start;
  logic [DATA_WIDTH-1:0] tx_data;
  logic                  busy;
  logic                  done;

  // Serial lines
  logic                  tx;
  logic                  rx;

  // RX parallel side
  logic [DATA_WIDTH-1:0] rx_data;
  logic                  rx_valid;
  logic                  rx_busy;
  logic                  parity_error;
  logic                  framing_error;
  logic                  break_detect;

  // RX FIFO
  logic                  rx_read;
  logic [DATA_WIDTH-1:0] fifo_data;
  logic                  fifo_empty;
  logic                  fifo_full;
  logic                  overrun_error;  // sticky
  logic                  overrun_pulse;  // per character

  // Configuration
  logic                  parity_en;
  logic                  parity_type;    // 0 = EVEN, 1 = ODD
  logic                  stop_bits;      // 0 = 1 stop, 1 = 2 stop
  logic [DIV_WIDTH-1:0]  baud_div;

  // Observation
  logic                  baud_tick;

  //-------------------------------------------------------------------
  // Power-on values for everything that is NOT driven by a clocking
  // block.  Clocking-block driven signals (start/tx_data/rx/rx_read)
  // are initialised by their drivers on the first active edge, while the
  // DUT is still held in reset.
  //-------------------------------------------------------------------
  initial begin
    reset       = 1'b0;
    parity_en   = 1'b0;
    parity_type = 1'b0;
    stop_bits   = 1'b0;
    baud_div    = DIV_WIDTH'(27);   // 50 MHz / 27 / 16 ~= 115200 baud
  end

  //-------------------------------------------------------------------
  // Clocking blocks
  //-------------------------------------------------------------------
  clocking drv_cb @(posedge clock);
    default input #1step output #1ns;
    output start, tx_data;
    input  busy, done, tx;
  endclocking : drv_cb

  clocking rx_drv_cb @(posedge clock);
    default input #1step output #1ns;
    output rx, rx_read;
    input  rx_valid, rx_data, rx_busy, parity_error, framing_error,
           break_detect, overrun_error, overrun_pulse,
           fifo_data, fifo_empty, fifo_full;
  endclocking : rx_drv_cb

  clocking mon_cb @(posedge clock);
    default input #1step;
    input start, tx_data, busy, done, tx, rx,
          rx_data, rx_valid, rx_busy, parity_error, framing_error, break_detect,
          rx_read, fifo_data, fifo_empty, fifo_full, overrun_error, overrun_pulse,
          parity_en, parity_type, stop_bits, baud_div, baud_tick;
  endclocking : mon_cb

  //-------------------------------------------------------------------
  // Utility tasks (single writer for reset and for the config bus)
  //-------------------------------------------------------------------

  // Program the DUT frame format.  Called between frames only.
  task automatic set_cfg(input bit                 p_en,
                         input bit                 p_type,
                         input bit                 s_bits,
                         input logic [DIV_WIDTH-1:0] div);
    @(posedge clock);
    parity_en   <= p_en;
    parity_type <= p_type;
    stop_bits   <= s_bits;
    baud_div    <= div;
    @(posedge clock);
  endtask : set_cfg

  // Assert the active-low reset for 'cycles' clocks.
  task automatic do_reset(input int unsigned cycles);
    @(posedge clock);
    reset <= 1'b0;
    repeat (cycles) @(posedge clock);
    reset <= 1'b1;
    repeat (5) @(posedge clock);
  endtask : do_reset

  // Block until the DUT is out of reset.
  task automatic wait_out_of_reset();
    while (reset !== 1'b1) @(posedge clock);
    @(posedge clock);
  endtask : wait_out_of_reset

  //-------------------------------------------------------------------
  // Modports
  //-------------------------------------------------------------------
  modport DRV (
    clocking drv_cb,
    input    clock, reset,
    import   set_cfg, do_reset, wait_out_of_reset
  );

  modport RX_DRV (
    clocking rx_drv_cb,
    input    clock, reset,
    import   set_cfg, wait_out_of_reset
  );

  modport MON (
    clocking mon_cb,
    input    clock, reset
  );

  modport ASSERT (
    input clock, reset, start, tx_data, busy, done, tx, rx,
          rx_data, rx_valid, rx_busy, parity_error, framing_error, break_detect,
          rx_read, fifo_data, fifo_empty, fifo_full, overrun_error, overrun_pulse,
          parity_en, parity_type, stop_bits, baud_div, baud_tick
  );

endinterface : uart_if

`endif // UART_IF_SV
