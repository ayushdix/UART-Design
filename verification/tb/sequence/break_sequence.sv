//=====================================================================
// File        : break_sequence.sv
// Description : Drives BREAK conditions - the serial line is held low
//               for a complete frame time (start + data + parity + stop
//               all zero).  The DUT must assert rx_break_detect together
//               with rx_framing_error and must then wait for the line to
//               return high before hunting for a new start bit.
//               RX direction only.
//=====================================================================
`ifndef BREAK_SEQUENCE_SV
`define BREAK_SEQUENCE_SV

class break_sequence extends base_sequence;

  `uvm_object_utils(break_sequence)

  constraint c_pkts { soft num_pkts inside {[4:8]}; }

  function new(string name = "break_sequence");
    super.new(name);
    dir = UART_DIR_RX;
  endfunction : new

  virtual task body();
    // Directed BREAK for every frame format.
    for (int pe = 0; pe < 2; pe++)
      for (int sb = 0; sb < 2; sb++)
        send_frame(8'h00, bit'(pe), UART_PARITY_EVEN, uart_stop_e'(sb),
                   16'd27, UART_ERR_BREAK);

    // Random BREAKs interleaved with clean traffic (recovery check).
    repeat (num_pkts) begin
      send_random(UART_ERR_BREAK);
      send_random(UART_ERR_NONE);
    end
  endtask : body

endclass : break_sequence

`endif // BREAK_SEQUENCE_SV
