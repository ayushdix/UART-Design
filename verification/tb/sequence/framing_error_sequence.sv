//=====================================================================
// File        : framing_error_sequence.sv
// Description : Drives frames whose STOP bit is held low.  The RX driver
//               corrupts the stop bit on the wire, the RX monitor
//               predicts framing_error and the scoreboard verifies that
//               the DUT raised rx_framing_error for exactly those
//               characters.  RX direction only.
//=====================================================================
`ifndef FRAMING_ERROR_SEQUENCE_SV
`define FRAMING_ERROR_SEQUENCE_SV

class framing_error_sequence extends base_sequence;

  `uvm_object_utils(framing_error_sequence)

  constraint c_pkts { soft num_pkts inside {[8:14]}; }

  function new(string name = "framing_error_sequence");
    super.new(name);
    dir = UART_DIR_RX;
  endfunction : new

  //-------------------------------------------------------------------
  // 2-stop-bit frame in which only the SECOND stop bit is corrupted.
  // The first stop bit is good, so this is the only stimulus that
  // exercises the second half of the receiver's framing_error term
  // (framing_error = !stop1 || (two_stop && !stop2)).
  //-------------------------------------------------------------------
  protected virtual task send_stop2_error(input bit p_en);
    uart_transaction tr;
    tr = uart_transaction::type_id::create("frm_stop2");
    start_item(tr);
    if (!tr.randomize() with { err_kind      == UART_ERR_FRAMING;
                               stop_bits     == UART_STOP_2;
                               corrupt_stop2 == 1'b1;
                               parity_en     == p_en;
                               baud_div      == 16'd27;
                               dir           == local::dir;
                               do_reset      == 1'b0; }) begin
      `uvm_fatal(get_type_name(), "stop2 framing item randomization failed")
    end
    finish_item(tr);
  endtask : send_stop2_error

  virtual task body();
    // Directed: bad stop bit for both stop-bit settings, with and
    // without parity.
    for (int pe = 0; pe < 2; pe++)
      for (int sb = 0; sb < 2; sb++)
        send_frame(8'h3C, bit'(pe), UART_PARITY_EVEN, uart_stop_e'(sb),
                   16'd27, UART_ERR_FRAMING);

    // Directed: only the SECOND stop bit corrupted.
    send_stop2_error(1'b0);
    send_stop2_error(1'b1);

    // Random framing errors (corrupt_stop2 is free to randomise).
    repeat (num_pkts) send_random(UART_ERR_FRAMING);

    // Clean frames afterwards prove the receiver recovers.
    repeat (4) send_random(UART_ERR_NONE);
  endtask : body

endclass : framing_error_sequence

`endif // FRAMING_ERROR_SEQUENCE_SV
