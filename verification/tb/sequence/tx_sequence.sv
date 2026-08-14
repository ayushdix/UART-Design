//=====================================================================
// File        : tx_sequence.sv
// Description : Clean transmit traffic.  Sweeps the corner data patterns
//               and every {parity_en, parity_type, stop_bits} format
//               combination so that the format cross is closed without
//               relying on the random seed, then adds random frames.
//               Runs on the TX sequencer.
//=====================================================================
`ifndef TX_SEQUENCE_SV
`define TX_SEQUENCE_SV

class tx_sequence extends base_sequence;

  `uvm_object_utils(tx_sequence)

  bit do_corners = 1'b1;

  constraint c_pkts { soft num_pkts inside {[8:16]}; }

  function new(string name = "tx_sequence");
    super.new(name);
    dir = UART_DIR_TX;
  endfunction : new

  virtual task body();
    bit [7:0] corners[$] = '{8'h00, 8'hFF, 8'hAA, 8'h55};
    bit [15:0] divs[$]   = '{16'd27, 16'd54, 16'd13};

    if (do_corners) begin
      // Corner data values across all three baud settings.
      foreach (corners[i]) begin
        send_frame(corners[i], 1'b0, UART_PARITY_EVEN, UART_STOP_1,
                   divs[i % divs.size()]);
      end
      // Every frame-format combination at the nominal baud rate.
      for (int pe = 0; pe < 2; pe++)
        for (int pt = 0; pt < 2; pt++)
          for (int sb = 0; sb < 2; sb++)
            send_frame($urandom_range(255, 0), bit'(pe),
                       uart_parity_e'(pt), uart_stop_e'(sb), 16'd27);
    end

    repeat (num_pkts) send_random(UART_ERR_NONE);
  endtask : body

endclass : tx_sequence

`endif // TX_SEQUENCE_SV
