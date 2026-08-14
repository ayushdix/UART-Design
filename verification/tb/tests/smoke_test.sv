//=====================================================================
// File        : smoke_test.sv
// Description : Shortest useful test - a handful of clean 8N1 frames in
//               each direction.  Used as the build-acceptance test: if
//               this fails, nothing else is worth running.
//=====================================================================
`ifndef SMOKE_TEST_SV
`define SMOKE_TEST_SV

class smoke_test extends base_test;

  `uvm_component_utils(smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_stimulus(uvm_phase phase);
    tx_sequence tx_seq;
    rx_sequence rx_seq;

    tx_seq = tx_sequence::type_id::create("tx_seq");
    tx_seq.do_corners = 1'b0;
    tx_seq.dir        = UART_DIR_TX;
    void'(tx_seq.randomize() with { num_pkts == 5; });
    run_on_tx(tx_seq);

    rx_seq = rx_sequence::type_id::create("rx_seq");
    rx_seq.do_corners = 1'b0;
    rx_seq.dir        = UART_DIR_RX;
    void'(rx_seq.randomize() with { num_pkts == 5; });
    run_on_rx(rx_seq);
  endtask : run_stimulus

endclass : smoke_test

`endif // SMOKE_TEST_SV
