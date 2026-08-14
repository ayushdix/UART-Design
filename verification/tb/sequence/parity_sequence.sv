//=====================================================================
// File        : parity_sequence.sv
// Description : Parity focused traffic.
//                 - every {EVEN, ODD} x {1 stop, 2 stop} combination
//                 - random parity-enabled frames
//                 - optional parity ERROR injection (RX direction only:
//                   the RX driver flips the parity bit on the wire, the
//                   RX monitor predicts parity_error and the scoreboard
//                   checks that the DUT flagged it).
//=====================================================================
`ifndef PARITY_SEQUENCE_SV
`define PARITY_SEQUENCE_SV

class parity_sequence extends base_sequence;

  `uvm_object_utils(parity_sequence)

  bit inject_errors = 1'b0;      // set by parity_test for the RX agent

  constraint c_pkts { soft num_pkts inside {[8:14]}; }

  function new(string name = "parity_sequence");
    super.new(name);
  endfunction : new

  virtual task body();
    // Directed sweep of the parity formats.
    for (int pt = 0; pt < 2; pt++)
      for (int sb = 0; sb < 2; sb++) begin
        send_frame(8'h00, 1'b1, uart_parity_e'(pt), uart_stop_e'(sb), 16'd27);
        send_frame(8'hFF, 1'b1, uart_parity_e'(pt), uart_stop_e'(sb), 16'd27);
        send_frame(8'h55, 1'b1, uart_parity_e'(pt), uart_stop_e'(sb), 16'd54);
        send_frame(8'hA5, 1'b1, uart_parity_e'(pt), uart_stop_e'(sb), 16'd13);
      end

    // Random parity-enabled frames.
    repeat (num_pkts) send_random(UART_ERR_NONE, 1'b1);

    // Parity error injection.
    if (inject_errors) begin
      repeat (num_pkts) send_random(UART_ERR_PARITY, 1'b1);
    end
  endtask : body

endclass : parity_sequence

`endif // PARITY_SEQUENCE_SV
