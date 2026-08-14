//=====================================================================
// File        : random_sequence.sv
// Description : Constrained-random traffic with back-to-back frames.
//               Everything (data, parity mode, stop bits, baud divider,
//               inter-packet gap) is randomised.  Direction is chosen by
//               the test before start() so that the same class can drive
//               either agent.  Used by random_test and stress_test.
//=====================================================================
`ifndef RANDOM_SEQUENCE_SV
`define RANDOM_SEQUENCE_SV

class random_sequence extends base_sequence;

  `uvm_object_utils(random_sequence)

  // 1 = zero-gap back-to-back frames for part of the burst
  bit enable_back_to_back = 1'b1;

  constraint c_pkts { soft num_pkts inside {[10:25]}; }

  function new(string name = "random_sequence");
    super.new(name);
  endfunction : new

  virtual task body();
    uart_transaction tr;

    repeat (num_pkts) begin
      tr = uart_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with { err_kind == UART_ERR_NONE;
                                 dir      == local::dir;
                                 do_reset == 1'b0; }) begin
        `uvm_fatal(get_type_name(), "random item randomization failed")
      end
      finish_item(tr);
    end

    // A short burst of minimum-gap frames (back-to-back stress).
    if (enable_back_to_back) begin
      repeat (5) begin
        tr = uart_transaction::type_id::create("b2b");
        start_item(tr);
        if (!tr.randomize() with { err_kind  == UART_ERR_NONE;
                                   dir       == local::dir;
                                   do_reset  == 1'b0;
                                   baud_div  == 16'd27;
                                   ipg_bits  == 1; }) begin
          `uvm_fatal(get_type_name(), "back-to-back randomization failed")
        end
        finish_item(tr);
      end
    end
  endtask : body

endclass : random_sequence

`endif // RANDOM_SEQUENCE_SV
