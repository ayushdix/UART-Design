//=====================================================================
// File        : random_test.sv
// Description : Constrained-random traffic in both directions including
//               a back-to-back burst.  This is the test that closes most
//               of the random coverage bins.
//=====================================================================
`ifndef RANDOM_TEST_SV
`define RANDOM_TEST_SV

class random_test extends base_test;

  `uvm_component_utils(random_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_stimulus(uvm_phase phase);
    random_sequence tx_seq, rx_seq;

    tx_seq     = random_sequence::type_id::create("rand_tx");
    tx_seq.dir = UART_DIR_TX;
    void'(tx_seq.randomize() with { num_pkts == 18; });
    run_on_tx(tx_seq);

    rx_seq     = random_sequence::type_id::create("rand_rx");
    rx_seq.dir = UART_DIR_RX;
    void'(rx_seq.randomize() with { num_pkts == 18; });
    run_on_rx(rx_seq);
  endtask : run_stimulus

endclass : random_test

`endif // RANDOM_TEST_SV
