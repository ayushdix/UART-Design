//=====================================================================
// File        : rx_sequence.sv
// Description : Clean receive traffic.  The RX driver bit-bangs each
//               frame onto the serial rx line and pops the RX FIFO after
//               every character.  Same corner/format sweep as the TX
//               sequence so both directions close the same cover bins.
//               Runs on the RX sequencer.
//=====================================================================
`ifndef RX_SEQUENCE_SV
`define RX_SEQUENCE_SV

class rx_sequence extends base_sequence;

  `uvm_object_utils(rx_sequence)

  bit do_corners = 1'b1;

  constraint c_pkts { soft num_pkts inside {[8:16]}; }

  function new(string name = "rx_sequence");
    super.new(name);
    dir = UART_DIR_RX;
  endfunction : new

  virtual task body();
    bit [7:0]  corners[$] = '{8'h00, 8'hFF, 8'hAA, 8'h55};
    bit [15:0] divs[$]    = '{16'd27, 16'd54, 16'd13};

    if (do_corners) begin
      foreach (corners[i]) begin
        send_frame(corners[i], 1'b0, UART_PARITY_EVEN, UART_STOP_1,
                   divs[i % divs.size()]);
      end
      for (int pe = 0; pe < 2; pe++)
        for (int pt = 0; pt < 2; pt++)
          for (int sb = 0; sb < 2; sb++)
            send_frame($urandom_range(255, 0), bit'(pe),
                       uart_parity_e'(pt), uart_stop_e'(sb), 16'd27);
    end

    repeat (num_pkts) send_random(UART_ERR_NONE);
  endtask : body

endclass : rx_sequence

`endif // RX_SEQUENCE_SV
