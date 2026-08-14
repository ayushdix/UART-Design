//=====================================================================
// File        : uart_tx_monitor.sv
// Description : Passive observer of the transmit path.  It runs two
//               independent collectors:
//
//                 req_ap : the PARALLEL request - what the DUT was asked
//                          to send (tx_data + the programmed format,
//                          captured on the cycle 'start' is accepted).
//                 rsp_ap : the SERIAL response - the frame actually
//                          decoded off the 'tx' pin, with an independent
//                          parity / stop-bit check.
//
//               The scoreboard compares one against the other; the
//               coverage collector and the subscriber listen on rsp_ap.
//=====================================================================
`ifndef UART_TX_MONITOR_SV
`define UART_TX_MONITOR_SV

class uart_tx_monitor extends uvm_monitor;

  `uvm_component_utils(uart_tx_monitor)

  uart_config     cfg;
  virtual uart_if vif;

  uvm_analysis_port #(uart_transaction) req_ap;
  uvm_analysis_port #(uart_transaction) rsp_ap;

  int unsigned n_req, n_rsp;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    req_ap = new("req_ap", this);
    rsp_ap = new("rsp_ap", this);
  endfunction : new

  //-------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(uart_config)::get(this, "", "cfg", cfg)) begin
      cfg = uart_config::type_id::create("cfg");
    end
    if (cfg.vif != null) begin
      vif = cfg.vif;
    end
    else if (!uvm_config_db #(virtual uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "virtual uart_if not found in the config_db")
    end
  endfunction : build_phase

  //-------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    fork
      collect_requests();
      collect_responses();
    join
  endtask : run_phase

  //-------------------------------------------------------------------
  // Parallel side : sample the accepted transmit command.
  //-------------------------------------------------------------------
  protected virtual task collect_requests();
    uart_transaction tr;
    forever begin
      @(vif.mon_cb);
      if ((vif.reset === 1'b1) &&
          (vif.mon_cb.start === 1'b1) && (vif.mon_cb.busy === 1'b0)) begin
        tr             = uart_transaction::type_id::create("tx_req");
        tr.dir         = UART_DIR_TX;
        tr.data        = vif.mon_cb.tx_data;
        tr.parity_en   = vif.mon_cb.parity_en;
        tr.parity_type = uart_parity_e'(vif.mon_cb.parity_type);
        tr.stop_bits   = uart_stop_e'  (vif.mon_cb.stop_bits);
        tr.baud_div    = vif.mon_cb.baud_div;
        tr.err_kind    = UART_ERR_NONE;
        tr.stamp       = $time;
        n_req++;
        `uvm_info(get_type_name(),
                  $sformatf("REQ %s", tr.convert2string()), UVM_HIGH)
        req_ap.write(tr);
      end
    end
  endtask : collect_requests

  //-------------------------------------------------------------------
  // Serial side : decode every frame that appears on the tx pin.
  //-------------------------------------------------------------------
  protected virtual task collect_responses();
    forever decode_tx_frame();
  endtask : collect_responses

  protected virtual task decode_tx_frame();
    uart_transaction tr;
    int unsigned     bc;
    bit              p_en, p_type, s_bits;
    bit [15:0]       div;
    bit [7:0]        d;
    bit              pbit, s1, s2;

    @(negedge vif.tx);
    if (vif.reset !== 1'b1) return;

    // Latch the format that is programmed for this frame.
    p_en   = vif.parity_en;
    p_type = vif.parity_type;
    s_bits = vif.stop_bits;
    div    = vif.baud_div;
    bc     = div * 16;

    tr             = uart_transaction::type_id::create("tx_rsp");
    tr.dir         = UART_DIR_TX;
    tr.parity_en   = p_en;
    tr.parity_type = uart_parity_e'(p_type);
    tr.stop_bits   = uart_stop_e'  (s_bits);
    tr.baud_div    = div;
    tr.err_kind    = UART_ERR_NONE;

    // Move to the middle of the START bit.
    repeat (bc/2) @(posedge vif.clock);
    tr.obs_start_ok = (vif.tx === 1'b0);
    if (!tr.obs_start_ok) begin
      tr.decode_ok = 1'b0;
      n_rsp++;
      rsp_ap.write(tr);
      return;
    end

    // DATA bits, LSB first.
    for (int i = 0; i < 8; i++) begin
      repeat (bc) @(posedge vif.clock);
      d[i] = vif.tx;
    end

    // PARITY.
    pbit = 1'b0;
    if (p_en) begin
      repeat (bc) @(posedge vif.clock);
      pbit = vif.tx;
    end

    // STOP bit(s).
    repeat (bc) @(posedge vif.clock);
    s1 = vif.tx;
    s2 = 1'b1;
    if (s_bits) begin
      repeat (bc) @(posedge vif.clock);
      s2 = vif.tx;
    end

    tr.data              = d;
    tr.obs_data          = d;
    tr.obs_parity_bit    = pbit;
    tr.obs_stop1         = s1;
    tr.obs_stop2         = s2;
    tr.obs_parity_error  = p_en && (pbit != tr.expected_parity());
    tr.obs_framing_error = (s1 !== 1'b1) || (s_bits && (s2 !== 1'b1));
    tr.obs_break         = (d == 8'h00) && (s1 === 1'b0) && (!p_en || (pbit === 1'b0));
    tr.obs_overrun       = 1'b0;
    tr.decode_ok         = 1'b1;
    tr.stamp             = $time;

    n_rsp++;
    `uvm_info(get_type_name(),
              $sformatf("RSP %s", tr.convert2string()), UVM_HIGH)
    rsp_ap.write(tr);
  endtask : decode_tx_frame

  //-------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
              $sformatf("observed %0d TX requests / %0d TX serial frames",
                        n_req, n_rsp), UVM_LOW)
  endfunction : report_phase

endclass : uart_tx_monitor

`endif // UART_TX_MONITOR_SV
