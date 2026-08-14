//=====================================================================
// File        : parity_test.sv
// Description : Parity generation and parity checking.
//                 TX side - every EVEN/ODD x 1/2-stop combination is
//                           transmitted and the parity bit on the wire
//                           is recomputed and checked by the scoreboard.
//                 RX side - the same formats are received, then parity
//                           errors are injected on the wire and the DUT
//                           must flag every one of them (and only them).
//=====================================================================
`ifndef PARITY_TEST_SV
`define PARITY_TEST_SV

class parity_test extends base_test;

  `uvm_component_utils(parity_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_stimulus(uvm_phase phase);
    parity_sequence tx_seq, rx_seq;

    // ---- transmit: parity generation ----
    tx_seq               = parity_sequence::type_id::create("par_tx");
    tx_seq.dir           = UART_DIR_TX;
    tx_seq.inject_errors = 1'b0;          // TX cannot corrupt the wire
    void'(tx_seq.randomize() with { num_pkts == 8; });
    run_on_tx(tx_seq);

    // ---- receive: parity checking + error injection ----
    rx_seq               = parity_sequence::type_id::create("par_rx");
    rx_seq.dir           = UART_DIR_RX;
    rx_seq.inject_errors = 1'b1;
    void'(rx_seq.randomize() with { num_pkts == 8; });
    run_on_rx(rx_seq);
  endtask : run_stimulus

  //-------------------------------------------------------------------
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (env.scoreboard.parity_err_seen == 0) begin
      `uvm_error(get_type_name(),
                 {"no parity error was ever reported by the DUT - the ",
                  "injection path is not working"})
    end
  endfunction : check_phase

endclass : parity_test

`endif // PARITY_TEST_SV
