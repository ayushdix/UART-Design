//=====================================================================
// File        : reset_sequence.sv
// Description : Issues an in-simulation reset.  The item carries
//               do_reset=1; the TX driver (the owner of the reset
//               signal) translates it into vif.do_reset(cycles).
//               Always run on the TX sequencer.
//=====================================================================
`ifndef RESET_SEQUENCE_SV
`define RESET_SEQUENCE_SV

class reset_sequence extends base_sequence;

  `uvm_object_utils(reset_sequence)

  rand int unsigned n_cycles;

  constraint c_cycles { n_cycles inside {[5:20]}; }
  constraint c_pkts   { num_pkts == 1; }

  function new(string name = "reset_sequence");
    super.new(name);
    dir = UART_DIR_TX;
  endfunction : new

  virtual task body();
    uart_transaction tr;
    repeat (num_pkts) begin
      tr = uart_transaction::type_id::create("rst_tr");
      start_item(tr);
      if (!tr.randomize() with { do_reset     == 1'b1;
                                 reset_cycles == local::n_cycles;
                                 err_kind     == UART_ERR_NONE;
                                 dir          == local::dir; }) begin
        `uvm_fatal(get_type_name(), "reset item randomization failed")
      end
      finish_item(tr);
      `uvm_info(get_type_name(),
                $sformatf("reset applied for %0d clocks", n_cycles), UVM_LOW)
    end
  endtask : body

endclass : reset_sequence

`endif // RESET_SEQUENCE_SV
