//=====================================================================
// File        : stress_test.sv
// Description : Long constrained-random regression: alternating bursts
//               of transmit and receive traffic with back-to-back frames
//               and mid-stream resets.  This is the test that is
//               expected to be run with several seeds.
//=====================================================================
`ifndef STRESS_TEST_SV
`define STRESS_TEST_SV

class stress_test extends base_test;

  `uvm_component_utils(stress_test)

  int unsigned n_rounds = 2;
  int unsigned burst    = 20;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_stimulus(uvm_phase phase);
    random_sequence tx_seq, rx_seq;
    reset_sequence  rst_seq;

    for (int r = 0; r < n_rounds; r++) begin
      `uvm_info(get_type_name(), $sformatf("stress round %0d/%0d",
                                           r+1, n_rounds), UVM_LOW)

      tx_seq     = random_sequence::type_id::create($sformatf("stress_tx%0d", r));
      tx_seq.dir = UART_DIR_TX;
      void'(tx_seq.randomize() with { num_pkts == burst; });
      run_on_tx(tx_seq);

      rx_seq     = random_sequence::type_id::create($sformatf("stress_rx%0d", r));
      rx_seq.dir = UART_DIR_RX;
      void'(rx_seq.randomize() with { num_pkts == burst; });
      run_on_rx(rx_seq);

      if (r != (n_rounds - 1)) begin
        rst_seq = reset_sequence::type_id::create($sformatf("stress_rst%0d", r));
        void'(rst_seq.randomize());
        run_on_tx(rst_seq);
      end
    end
  endtask : run_stimulus

endclass : stress_test

`endif // STRESS_TEST_SV
