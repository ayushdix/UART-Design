//=====================================================================
// File        : tb_pkg.sv
// Description : Test package.  Keeping the tests out of uart_pkg means
//               the verification IP can be reused unchanged in another
//               project that supplies its own test list.
//               Compile AFTER uart_pkg.sv.
//=====================================================================
`ifndef TB_PKG_SV
`define TB_PKG_SV

`timescale 1ns/1ps

package tb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import uart_pkg::*;

  `include "base_test.sv"
  `include "smoke_test.sv"
  `include "reset_test.sv"
  `include "tx_test.sv"
  `include "rx_test.sv"
  `include "random_test.sv"
  `include "parity_test.sv"
  `include "framing_error_test.sv"
  `include "break_test.sv"
  `include "overrun_test.sv"
  `include "stress_test.sv"

endpackage : tb_pkg

`endif // TB_PKG_SV
