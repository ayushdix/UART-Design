//=====================================================================
// File        : reset_test.sv
// Description : Exercises asynchronous reset while traffic is running.
//               A reset is applied before, between and after live
//               transfers; the SVA reset properties check that the DUT
//               parks in a legal state and the scoreboard checks that
//               traffic resumes correctly afterwards.
//=====================================================================
`ifndef RESET_TEST_SV
`define RESET_TEST_SV

class reset_test extends base_test;

  `uvm_component_utils(reset_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_stimulus(uvm_phase phase);
    reset_sequence rst_seq;
    tx_sequence    tx_seq;
    rx_sequence    rx_seq;

    // ---- reset, then transmit ----
    rst_seq = reset_sequence::type_id::create("rst_seq0");
    void'(rst_seq.randomize());
    run_on_tx(rst_seq);

    tx_seq = tx_sequence::type_id::create("tx_seq");
    tx_seq.do_corners = 1'b0;
    tx_seq.dir        = UART_DIR_TX;
    void'(tx_seq.randomize() with { num_pkts == 6; });
    run_on_tx(tx_seq);

    // ---- reset again, then receive ----
    rst_seq = reset_sequence::type_id::create("rst_seq1");
    void'(rst_seq.randomize());
    run_on_tx(rst_seq);

    rx_seq = rx_sequence::type_id::create("rx_seq");
    rx_seq.do_corners = 1'b0;
    rx_seq.dir        = UART_DIR_RX;
    void'(rx_seq.randomize() with { num_pkts == 6; });
    run_on_rx(rx_seq);

    // ---- final reset ----
    rst_seq = reset_sequence::type_id::create("rst_seq2");
    void'(rst_seq.randomize());
    run_on_tx(rst_seq);
  endtask : run_stimulus

endclass : reset_test

`endif // RESET_TEST_SV
