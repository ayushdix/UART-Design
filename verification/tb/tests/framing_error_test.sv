//=====================================================================
// File        : framing_error_test.sv
// Description : Drives frames whose STOP bit is held low and checks that
//               the DUT raises rx_framing_error for exactly those
//               characters, still delivers the data byte, and recovers
//               cleanly for the frames that follow.
//=====================================================================
`ifndef FRAMING_ERROR_TEST_SV
`define FRAMING_ERROR_TEST_SV

class framing_error_test extends base_test;

  `uvm_component_utils(framing_error_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_stimulus(uvm_phase phase);
    framing_error_sequence seq;

    seq     = framing_error_sequence::type_id::create("frm_seq");
    seq.dir = UART_DIR_RX;
    void'(seq.randomize() with { num_pkts == 10; });
    run_on_rx(seq);
  endtask : run_stimulus

  //-------------------------------------------------------------------
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (env.scoreboard.framing_err_seen == 0) begin
      `uvm_error(get_type_name(),
                 "no framing error was ever reported by the DUT")
    end
  endfunction : check_phase

endclass : framing_error_test

`endif // FRAMING_ERROR_TEST_SV
