//=====================================================================
// File        : overrun_sequence.sv
// Description : Fills the receive FIFO and keeps going.  Items tagged
//               UART_ERR_OVERRUN tell the RX driver NOT to pop the FIFO,
//               so after FIFO_DEPTH characters the next character finds
//               the FIFO full and the DUT must raise overrun_error.
//               The baud divider is pinned to the nominal value to keep
//               the (necessarily long) burst affordable.
//               RX direction only.
//=====================================================================
`ifndef OVERRUN_SEQUENCE_SV
`define OVERRUN_SEQUENCE_SV

class overrun_sequence extends base_sequence;

  `uvm_object_utils(overrun_sequence)

  // Must exceed the DUT FIFO depth (16) by a comfortable margin.
  constraint c_pkts { num_pkts inside {[20:24]}; }

  function new(string name = "overrun_sequence");
    super.new(name);
    dir = UART_DIR_RX;
  endfunction : new

  virtual task body();
    uart_transaction tr;

    repeat (num_pkts) begin
      tr = uart_transaction::type_id::create("ovr_tr");
      start_item(tr);
      if (!tr.randomize() with { err_kind  == UART_ERR_OVERRUN;
                                 dir       == local::dir;
                                 do_reset  == 1'b0;
                                 parity_en == 1'b0;
                                 stop_bits == UART_STOP_1;
                                 baud_div  == 16'd27;
                                 ipg_bits  == 1; }) begin
        `uvm_fatal(get_type_name(), "overrun item randomization failed")
      end
      finish_item(tr);
    end
  endtask : body

endclass : overrun_sequence

`endif // OVERRUN_SEQUENCE_SV
