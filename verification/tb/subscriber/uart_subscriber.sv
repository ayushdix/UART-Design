//=====================================================================
// File        : uart_subscriber.sv
// Description : Lightweight traffic analyser.  It subscribes to the same
//               observed streams as the coverage collector and keeps
//               per-direction / per-error-kind statistics plus a running
//               histogram of the frame formats that were exercised.
//               Printed at report_phase, it is the quickest way to see
//               whether a test actually produced the traffic it claims.
//=====================================================================
`ifndef UART_SUBSCRIBER_SV
`define UART_SUBSCRIBER_SV

class uart_subscriber extends uvm_subscriber #(uart_transaction);

  `uvm_component_utils(uart_subscriber)

  int unsigned n_total;
  int unsigned n_by_dir [uart_dir_e];
  int unsigned n_by_err [uart_err_e];
  int unsigned n_by_baud[bit [15:0]];
  int unsigned n_parity_on;
  int unsigned n_two_stop;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //-------------------------------------------------------------------
  virtual function void write(uart_transaction t);
    if (t == null) return;
    n_total++;

    // Seed the entry before incrementing - reading a missing associative
    // array key is legal but noisy in most simulators.
    if (!n_by_dir .exists(t.dir))      n_by_dir [t.dir]      = 0;
    if (!n_by_err .exists(t.err_kind)) n_by_err [t.err_kind] = 0;
    if (!n_by_baud.exists(t.baud_div)) n_by_baud[t.baud_div] = 0;

    n_by_dir [t.dir]++;
    n_by_err [t.err_kind]++;
    n_by_baud[t.baud_div]++;

    if (t.parity_en)                    n_parity_on++;
    if (t.stop_bits == UART_STOP_2)     n_two_stop++;
  endfunction : write

  //-------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    string s;

    s = "\n  ==================== TRAFFIC SUMMARY ====================\n";
    s = {s, $sformatf("   total frames observed : %0d\n", n_total)};

    foreach (n_by_dir[d])
      s = {s, $sformatf("   direction %-12s: %0d\n", d.name(), n_by_dir[d])};

    foreach (n_by_err[e])
      s = {s, $sformatf("   err_kind  %-12s: %0d\n", e.name(), n_by_err[e])};

    foreach (n_by_baud[b])
      s = {s, $sformatf("   baud_div  %-12d: %0d\n", b, n_by_baud[b])};

    s = {s, $sformatf("   parity enabled frames : %0d\n", n_parity_on)};
    s = {s, $sformatf("   two-stop-bit frames   : %0d\n", n_two_stop)};
    s = {s,   "  ========================================================="};

    `uvm_info("SUB/REPORT", s, UVM_LOW)
  endfunction : report_phase

endclass : uart_subscriber

`endif // UART_SUBSCRIBER_SV
