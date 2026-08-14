//=====================================================================
// File        : uart_pkg.sv
// Description : The UART verification component package.  Everything
//               that is reusable (config, item, sequence library, agents,
//               scoreboard, coverage, environment) lives here.  Tests
//               live in tb_pkg so that a different project can import
//               uart_pkg and supply its own tests.
//
//               Compile order matters: uart_if.sv must already be in the
//               library because this package declares "virtual uart_if".
//
//               Include order inside the package follows the dependency
//               chain: types -> config -> item -> sequences -> sequencer
//               -> drivers -> monitors -> agents -> analysis components
//               -> environment.
//=====================================================================
`ifndef UART_PKG_SV
`define UART_PKG_SV

`timescale 1ns/1ps

package uart_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  //-------------------------------------------------------------------
  // Shared enumerations
  //-------------------------------------------------------------------
  typedef enum bit {
    UART_PARITY_EVEN = 1'b0,
    UART_PARITY_ODD  = 1'b1
  } uart_parity_e;

  typedef enum bit {
    UART_STOP_1 = 1'b0,
    UART_STOP_2 = 1'b1
  } uart_stop_e;

  typedef enum bit {
    UART_DIR_TX = 1'b0,
    UART_DIR_RX = 1'b1
  } uart_dir_e;

  typedef enum bit [2:0] {
    UART_ERR_NONE    = 3'd0,
    UART_ERR_PARITY  = 3'd1,
    UART_ERR_FRAMING = 3'd2,
    UART_ERR_BREAK   = 3'd3,
    UART_ERR_OVERRUN = 3'd4
  } uart_err_e;

  //-------------------------------------------------------------------
  // Configuration and transaction
  //-------------------------------------------------------------------
  `include "uart_config.sv"
  `include "uart_transaction.sv"

  //-------------------------------------------------------------------
  // Sequence library
  //-------------------------------------------------------------------
  `include "base_sequence.sv"
  `include "reset_sequence.sv"
  `include "tx_sequence.sv"
  `include "rx_sequence.sv"
  `include "random_sequence.sv"
  `include "parity_sequence.sv"
  `include "framing_error_sequence.sv"
  `include "break_sequence.sv"
  `include "overrun_sequence.sv"

  //-------------------------------------------------------------------
  // Agent building blocks
  //-------------------------------------------------------------------
  `include "uart_sequencer.sv"
  `include "uart_driver.sv"
  `include "uart_tx_driver.sv"
  `include "uart_rx_driver.sv"
  `include "uart_tx_monitor.sv"
  `include "uart_rx_monitor.sv"
  `include "uart_tx_agent.sv"
  `include "uart_rx_agent.sv"

  //-------------------------------------------------------------------
  // Analysis components and environment
  //-------------------------------------------------------------------
  `include "uart_scoreboard.sv"
  `include "uart_coverage.sv"
  `include "uart_subscriber.sv"
  `include "uart_env.sv"

endpackage : uart_pkg

`endif // UART_PKG_SV
