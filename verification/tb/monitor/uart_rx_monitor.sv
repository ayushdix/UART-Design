//=====================================================================
// File        : uart_rx_monitor.sv
// Description : Passive observer of the receive path.  Two collectors:
//
//                 req_ap : the SERIAL stimulus - the frame decoded off
//                          the 'rx' pin together with the error flags a
//                          correct receiver is REQUIRED to report
//                          (parity / framing / break).  This is the
//                          reference model input for the scoreboard.
//                 rsp_ap : the PARALLEL response - rx_data plus the
//                          DUT's own error flags, sampled on rx_valid.
//
//               Nothing here looks at the driver: the prediction is made
//               purely from the pin activity, so a broken driver cannot
//               hide a broken DUT.
//=====================================================================
`ifndef UART_RX_MONITOR_SV
`define UART_RX_MONITOR_SV

class uart_rx_monitor extends uvm_monitor;

  `uvm_component_utils(uart_rx_monitor)

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
  // Serial side : decode the stimulus and predict the error flags.
  //-------------------------------------------------------------------
  protected virtual task collect_requests();
    forever decode_rx_frame();
  endtask : collect_requests

  protected virtual task decode_rx_frame();
    uart_transaction tr;
    int unsigned     bc;
    bit              p_en, p_type, s_bits;
    bit [15:0]       div;
    bit [7:0]        d;
    bit              pbit, s1, s2;

    @(negedge vif.rx);
    if (vif.reset !== 1'b1) return;

    p_en   = vif.parity_en;
    p_type = vif.parity_type;
    s_bits = vif.stop_bits;
    div    = vif.baud_div;
    bc     = div * 16;

    tr             = uart_transaction::type_id::create("rx_req");
    tr.dir         = UART_DIR_RX;
    tr.parity_en   = p_en;
    tr.parity_type = uart_parity_e'(p_type);
    tr.stop_bits   = uart_stop_e'  (s_bits);
    tr.baud_div    = div;

    // Middle of the START bit.
    repeat (bc/2) @(posedge vif.clock);
    tr.obs_start_ok = (vif.rx === 1'b0);
    if (!tr.obs_start_ok) begin
      // Glitch shorter than half a bit - the DUT rejects it too, so it
      // must not be published as an expected character.
      return;
    end

    for (int i = 0; i < 8; i++) begin
      repeat (bc) @(posedge vif.clock);
      d[i] = vif.rx;
    end

    pbit = 1'b0;
    if (p_en) begin
      repeat (bc) @(posedge vif.clock);
      pbit = vif.rx;
    end

    repeat (bc) @(posedge vif.clock);
    s1 = vif.rx;
    s2 = 1'b1;
    if (s_bits) begin
      repeat (bc) @(posedge vif.clock);
      s2 = vif.rx;
    end

    tr.data              = d;
    tr.obs_data          = d;
    tr.obs_parity_bit    = pbit;
    tr.obs_stop1         = s1;
    tr.obs_stop2         = s2;
    // ---- reference model: what the DUT must report ----
    tr.obs_parity_error  = p_en && (pbit != tr.expected_parity());
    tr.obs_framing_error = (s1 !== 1'b1) || (s_bits && (s2 !== 1'b1));
    tr.obs_break         = (d == 8'h00) && (s1 === 1'b0) && (!p_en || (pbit === 1'b0));
    tr.decode_ok         = 1'b1;
    tr.stamp             = $time;

    if      (tr.obs_break)         tr.err_kind = UART_ERR_BREAK;
    else if (tr.obs_framing_error) tr.err_kind = UART_ERR_FRAMING;
    else if (tr.obs_parity_error)  tr.err_kind = UART_ERR_PARITY;
    else                           tr.err_kind = UART_ERR_NONE;

    n_req++;
    `uvm_info(get_type_name(),
              $sformatf("REQ %s", tr.convert2string()), UVM_HIGH)
    req_ap.write(tr);
  endtask : decode_rx_frame

  //-------------------------------------------------------------------
  // Parallel side : sample the DUT's received character.
  //-------------------------------------------------------------------
  protected virtual task collect_responses();
    uart_transaction tr;
    forever begin
      @(vif.mon_cb);
      if ((vif.reset === 1'b1) && (vif.mon_cb.rx_valid === 1'b1)) begin
        tr                   = uart_transaction::type_id::create("rx_rsp");
        tr.dir               = UART_DIR_RX;
        tr.parity_en         = vif.mon_cb.parity_en;
        tr.parity_type       = uart_parity_e'(vif.mon_cb.parity_type);
        tr.stop_bits         = uart_stop_e'  (vif.mon_cb.stop_bits);
        tr.baud_div          = vif.mon_cb.baud_div;
        tr.data              = vif.mon_cb.rx_data;
        tr.obs_data          = vif.mon_cb.rx_data;
        tr.obs_parity_error  = vif.mon_cb.parity_error;
        tr.obs_framing_error = vif.mon_cb.framing_error;
        tr.obs_break         = vif.mon_cb.break_detect;
        tr.obs_overrun       = vif.mon_cb.overrun_pulse;
        tr.decode_ok         = 1'b1;
        tr.stamp             = $time;

        if      (tr.obs_break)         tr.err_kind = UART_ERR_BREAK;
        else if (tr.obs_framing_error) tr.err_kind = UART_ERR_FRAMING;
        else if (tr.obs_parity_error)  tr.err_kind = UART_ERR_PARITY;
        else if (tr.obs_overrun)       tr.err_kind = UART_ERR_OVERRUN;
        else                           tr.err_kind = UART_ERR_NONE;

        n_rsp++;
        `uvm_info(get_type_name(),
                  $sformatf("RSP %s", tr.convert2string()), UVM_HIGH)
        rsp_ap.write(tr);
      end
    end
  endtask : collect_responses

  //-------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
              $sformatf("observed %0d RX serial frames / %0d RX characters",
                        n_req, n_rsp), UVM_LOW)
  endfunction : report_phase

endclass : uart_rx_monitor

`endif // UART_RX_MONITOR_SV
