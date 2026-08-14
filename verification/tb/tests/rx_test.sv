//=====================================================================
// File        : rx_test.sv
// Description : Receive-path focused test.  The RX driver bit-bangs the
//               corner data patterns, every frame format and all three
//               baud settings onto the serial line; the scoreboard
//               checks rx_data and the error flags against the frame the
//               RX monitor decoded independently from the same pin.
//=====================================================================
`ifndef RX_TEST_SV
`define RX_TEST_SV

class rx_test extends base_test;

  `uvm_component_utils(rx_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_stimulus(uvm_phase phase);
    rx_sequence rx_seq;

    rx_seq = rx_sequence::type_id::create("rx_seq");
    rx_seq.do_corners = 1'b1;
    rx_seq.dir        = UART_DIR_RX;
    void'(rx_seq.randomize() with { num_pkts == 14; });
    run_on_rx(rx_seq);
  endtask : run_stimulus

endclass : rx_test

`endif // RX_TEST_SV
