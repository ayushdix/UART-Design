//=====================================================================
// File        : tb_top.sv
// Description : Static top level.
//                 - 50 MHz clock
//                 - power-on reset (active low)
//                 - uart_if instance
//                 - uart_top DUT
//                 - uart_assertions checker
//                 - virtual interface published to the config_db
//                 - run_test()
//
//               Plusargs:
//                 +UVM_TESTNAME=<test>   which test to run
//                 +WAVES                 record a WLF/waveform database
//                 +TIMEOUT_NS=<n>        global watchdog (default 200 ms)
//=====================================================================
`timescale 1ns/1ps

`ifndef TB_TOP_SV
`define TB_TOP_SV

module tb_top;

  import uvm_pkg::*;
  import uart_pkg::*;
  import tb_pkg::*;
`include "uvm_macros.svh"

  //-------------------------------------------------------------------
  // Parameters
  //-------------------------------------------------------------------
  localparam int DATA_WIDTH   = 8;
  localparam int OVERSAMPLE   = 16;
  localparam int FIFO_DEPTH   = 16;
  localparam int DIV_WIDTH    = 16;
  localparam int CLK_HALF_NS  = 10;      // 50 MHz
  localparam int RESET_CLKS   = 10;

  //-------------------------------------------------------------------
  // Clock
  //-------------------------------------------------------------------
  logic clock;

  initial begin
    clock = 1'b0;
    forever #(CLK_HALF_NS) clock = ~clock;
  end

  //-------------------------------------------------------------------
  // Interface
  //-------------------------------------------------------------------
  uart_if #(
    .DATA_WIDTH (DATA_WIDTH),
    .DIV_WIDTH  (DIV_WIDTH)
  ) vif (
    .clock (clock)
  );

  //-------------------------------------------------------------------
  // Power-on reset (the reset_sequence can pulse it again later)
  //-------------------------------------------------------------------
  initial begin
    vif.do_reset(RESET_CLKS);
  end

  //-------------------------------------------------------------------
  // DUT
  //-------------------------------------------------------------------
  uart_top #(
    .DATA_WIDTH (DATA_WIDTH),
    .OVERSAMPLE (OVERSAMPLE),
    .FIFO_DEPTH (FIFO_DEPTH),
    .DIV_WIDTH  (DIV_WIDTH)
  ) dut (
    .clk              (clock),
    .rst_n            (vif.reset),

    .parity_en        (vif.parity_en),
    .parity_type      (vif.parity_type),
    .stop_bits        (vif.stop_bits),
    .baud_div         (vif.baud_div),

    .tx_start         (vif.start),
    .tx_data          (vif.tx_data),
    .tx_busy          (vif.busy),
    .tx_done          (vif.done),
    .tx               (vif.tx),

    .rx               (vif.rx),

    .rx_data          (vif.rx_data),
    .rx_valid         (vif.rx_valid),
    .rx_busy          (vif.rx_busy),
    .rx_parity_error  (vif.parity_error),
    .rx_framing_error (vif.framing_error),
    .rx_break_detect  (vif.break_detect),

    .rx_read          (vif.rx_read),
    .fifo_data        (vif.fifo_data),
    .fifo_empty       (vif.fifo_empty),
    .fifo_full        (vif.fifo_full),
    .overrun_error    (vif.overrun_error),
    .overrun_pulse    (vif.overrun_pulse),

    .baud_tick        (vif.baud_tick)
  );

  //-------------------------------------------------------------------
  // SVA checker
  //-------------------------------------------------------------------
  uart_assertions #(
    .DATA_WIDTH (DATA_WIDTH),
    .OVERSAMPLE (OVERSAMPLE),
    .DIV_WIDTH  (DIV_WIDTH)
  ) u_uart_sva (
    .clock         (clock),
    .reset         (vif.reset),
    .start         (vif.start),
    .tx_data       (vif.tx_data),
    .busy          (vif.busy),
    .done          (vif.done),
    .tx            (vif.tx),
    .rx            (vif.rx),
    .rx_data       (vif.rx_data),
    .rx_valid      (vif.rx_valid),
    .rx_busy       (vif.rx_busy),
    .parity_error  (vif.parity_error),
    .framing_error (vif.framing_error),
    .break_detect  (vif.break_detect),
    .fifo_full     (vif.fifo_full),
    .fifo_empty    (vif.fifo_empty),
    .overrun_error (vif.overrun_error),
    .overrun_pulse (vif.overrun_pulse),
    .parity_en     (vif.parity_en),
    .parity_type   (vif.parity_type),
    .stop_bits     (vif.stop_bits),
    .baud_div      (vif.baud_div),
    .baud_tick     (vif.baud_tick)
  );

  //-------------------------------------------------------------------
  // Waveforms are recorded by the simulator ("log -r /*" in run.do when
  // WAVES=1), which keeps regression runs fast by default.
  //-------------------------------------------------------------------
  // Global watchdog - a hung simulation must fail, not run forever.
  //-------------------------------------------------------------------
  int unsigned timeout_ns = 200_000_000;     // 200 ms

  initial begin
    void'($value$plusargs("TIMEOUT_NS=%d", timeout_ns));
    #(timeout_ns * 1ns);
    `uvm_fatal("TB_TOP/TIMEOUT",
               $sformatf("global watchdog expired after %0d ns", timeout_ns))
  end

  //-------------------------------------------------------------------
  // UVM start-up
  //-------------------------------------------------------------------
  initial begin
    uvm_config_db #(virtual uart_if)::set(null, "*", "vif", vif);
    run_test();
  end

endmodule : tb_top

`endif // TB_TOP_SV
