//=====================================================================
// File        : tx_test.sv
// Description : Transmit-path focused test.  Sweeps the corner data
//               patterns, every frame format and all three baud
//               settings, then adds constrained-random frames.  The
//               scoreboard checks the serial stream decoded off the tx
//               pin against the parallel request.
//=====================================================================
`ifndef TX_TEST_SV
`define TX_TEST_SV

class tx_test extends base_test;

  `uvm_component_utils(tx_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_stimulus(uvm_phase phase);
    tx_sequence tx_seq;

    tx_seq = tx_sequence::type_id::create("tx_seq");
    tx_seq.do_corners = 1'b1;
    tx_seq.dir        = UART_DIR_TX;
    void'(tx_seq.randomize() with { num_pkts == 14; });
    run_on_tx(tx_seq);
  endtask : run_stimulus

endclass : tx_test

`endif // TX_TEST_SV
