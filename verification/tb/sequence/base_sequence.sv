//=====================================================================
// File        : base_sequence.sv
// Description : Root of the UART sequence library.  Holds the knobs that
//               every derived sequence shares (packet count, direction)
//               and a small helper used to emit a fully specified frame.
//               Tests configure the knobs before calling start().
//=====================================================================
`ifndef BASE_SEQUENCE_SV
`define BASE_SEQUENCE_SV

class base_sequence extends uvm_sequence #(uart_transaction);

  `uvm_object_utils(base_sequence)

  rand int unsigned num_pkts;
  uart_dir_e        dir = UART_DIR_TX;

  constraint c_num_pkts { soft num_pkts inside {[5:20]}; }

  function new(string name = "base_sequence");
    super.new(name);
  endfunction : new

  virtual task pre_body();
    `uvm_info(get_type_name(),
              $sformatf("START dir=%s num_pkts=%0d", dir.name(), num_pkts),
              UVM_LOW)
  endtask : pre_body

  virtual task post_body();
    `uvm_info(get_type_name(), "DONE", UVM_LOW)
  endtask : post_body

  //-------------------------------------------------------------------
  // Emit one completely specified frame.  Used by the directed
  // sequences so that corner-case data/format combinations are always
  // hit regardless of the random seed.
  //-------------------------------------------------------------------
  virtual task send_frame(input bit [7:0]     d,
                          input bit           p_en,
                          input uart_parity_e p_type,
                          input uart_stop_e   s_bits,
                          input bit [15:0]    div,
                          input uart_err_e    e = UART_ERR_NONE);
    uart_transaction tr;
    tr = uart_transaction::type_id::create("tr");
    start_item(tr);
    if (!tr.randomize() with { data        == d;
                               parity_en   == p_en;
                               parity_type == p_type;
                               stop_bits   == s_bits;
                               baud_div    == div;
                               err_kind    == e;
                               dir         == local::dir;
                               do_reset    == 1'b0; }) begin
      `uvm_fatal(get_type_name(), "send_frame(): randomization failed")
    end
    finish_item(tr);
  endtask : send_frame

  //-------------------------------------------------------------------
  // Emit one random frame of a given error flavour.
  //-------------------------------------------------------------------
  virtual task send_random(input uart_err_e e = UART_ERR_NONE,
                           input bit        force_parity = 1'b0);
    uart_transaction tr;
    tr = uart_transaction::type_id::create("tr");
    start_item(tr);
    if (!tr.randomize() with { err_kind == e;
                               dir      == local::dir;
                               do_reset == 1'b0;
                               if (force_parity) parity_en == 1'b1; }) begin
      `uvm_fatal(get_type_name(), "send_random(): randomization failed")
    end
    finish_item(tr);
  endtask : send_random

  //-------------------------------------------------------------------
  virtual task body();
    repeat (num_pkts) send_random(UART_ERR_NONE);
  endtask : body

endclass : base_sequence

`endif // BASE_SEQUENCE_SV
