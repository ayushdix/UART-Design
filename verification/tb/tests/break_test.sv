//=====================================================================
// File        : break_test.sv
// Description : Holds the serial line low for a full frame time and
//               checks that the DUT reports break_detect together with
//               framing_error and an all-zero character, then resumes
//               normal reception once the line returns high.
//=====================================================================
`ifndef BREAK_TEST_SV
`define BREAK_TEST_SV

class break_test extends base_test;

  `uvm_component_utils(break_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_stimulus(uvm_phase phase);
    break_sequence seq;

    seq     = break_sequence::type_id::create("brk_seq");
    seq.dir = UART_DIR_RX;
    void'(seq.randomize() with { num_pkts == 5; });
    run_on_rx(seq);
  endtask : run_stimulus

  //-------------------------------------------------------------------
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (env.scoreboard.break_seen == 0) begin
      `uvm_error(get_type_name(),
                 "no BREAK condition was ever reported by the DUT")
    end
  endfunction : check_phase

endclass : break_test

`endif // BREAK_TEST_SV
