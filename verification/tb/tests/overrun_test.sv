//=====================================================================
// File        : overrun_test.sv
// Description : Receive FIFO overrun.  The FIFO reader in the RX driver
//               is disabled, so after FIFO_DEPTH (16) characters the
//               next character finds the FIFO full.  The DUT must pulse
//               overrun and latch the sticky overrun status, while still
//               delivering every character correctly on rx_data.
//=====================================================================
`ifndef OVERRUN_TEST_SV
`define OVERRUN_TEST_SV

class overrun_test extends base_test;

  `uvm_component_utils(overrun_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //-------------------------------------------------------------------
  virtual function void configure();
    super.configure();
    rx_cfg.enable_fifo_read = 1'b0;   // never drain the FIFO
  endfunction : configure

  //-------------------------------------------------------------------
  virtual task run_stimulus(uvm_phase phase);
    overrun_sequence seq;

    seq     = overrun_sequence::type_id::create("ovr_seq");
    seq.dir = UART_DIR_RX;
    void'(seq.randomize() with { num_pkts == 22; });
    run_on_rx(seq);
  endtask : run_stimulus

  //-------------------------------------------------------------------
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (!env.scoreboard.overrun_seen) begin
      `uvm_error(get_type_name(),
                 "the FIFO was never overrun - overrun detection is untested")
    end
  endfunction : check_phase

endclass : overrun_test

`endif // OVERRUN_TEST_SV
