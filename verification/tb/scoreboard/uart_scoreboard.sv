//=====================================================================
// File        : uart_scoreboard.sv
// Description : Dual-direction, in-order checker.
//
//               TX path :  expected = the parallel transmit command
//                                     (uart_tx_monitor.req_ap)
//                          actual   = the frame decoded off the tx pin
//                                     (uart_tx_monitor.rsp_ap)
//                          checks   : data integrity, frame format,
//                                     generated parity bit, stop bits,
//                                     start bit, no spurious errors.
//
//               RX path :  expected = the frame decoded off the rx pin
//                                     plus the error flags a correct
//                                     receiver must report
//                                     (uart_rx_monitor.req_ap)
//                          actual   = rx_data + DUT error flags
//                                     (uart_rx_monitor.rsp_ap)
//                          checks   : data integrity, parity error,
//                                     framing error, break detect.
//
//               OVERRUN is tracked separately (overrun_seen) because it
//               is a FIFO-level condition, not a per-character property.
//=====================================================================
`ifndef UART_SCOREBOARD_SV
`define UART_SCOREBOARD_SV

`uvm_analysis_imp_decl(_tx_exp)
`uvm_analysis_imp_decl(_tx_act)
`uvm_analysis_imp_decl(_rx_exp)
`uvm_analysis_imp_decl(_rx_act)

class uart_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(uart_scoreboard)

  uvm_analysis_imp_tx_exp #(uart_transaction, uart_scoreboard) tx_exp_imp;
  uvm_analysis_imp_tx_act #(uart_transaction, uart_scoreboard) tx_act_imp;
  uvm_analysis_imp_rx_exp #(uart_transaction, uart_scoreboard) rx_exp_imp;
  uvm_analysis_imp_rx_act #(uart_transaction, uart_scoreboard) rx_act_imp;

  protected uart_transaction tx_exp_q[$];
  protected uart_transaction rx_exp_q[$];

  // ---- statistics ----
  int unsigned tx_compared, tx_matched, tx_mismatched;
  int unsigned rx_compared, rx_matched, rx_mismatched;
  int unsigned parity_err_seen, framing_err_seen, break_seen;
  bit          overrun_seen;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    tx_exp_imp = new("tx_exp_imp", this);
    tx_act_imp = new("tx_act_imp", this);
    rx_exp_imp = new("rx_exp_imp", this);
    rx_act_imp = new("rx_act_imp", this);
  endfunction : new

  //===================================================================
  // TX path
  //===================================================================
  virtual function void write_tx_exp(uart_transaction t);
    uart_transaction c;
    c = uart_transaction::type_id::create("tx_exp");
    c.copy(t);
    tx_exp_q.push_back(c);
  endfunction : write_tx_exp

  virtual function void write_tx_act(uart_transaction act);
    uart_transaction exp;
    bit              ok = 1'b1;
    string           why = "";

    if (tx_exp_q.size() == 0) begin
      `uvm_error("SB/TX/UNEXP",
                 $sformatf("serial TX frame with no pending request: %s",
                           act.convert2string()))
      return;
    end

    exp = tx_exp_q.pop_front();
    tx_compared++;

    if (!act.decode_ok) begin
      ok = 1'b0; why = {why, "frame decode failed (bad start bit); "};
    end
    if (act.obs_data !== exp.data) begin
      ok = 1'b0;
      why = {why, $sformatf("data exp=0x%02h act=0x%02h; ",
                            exp.data, act.obs_data)};
    end
    if (act.parity_en !== exp.parity_en ||
        act.parity_type !== exp.parity_type ||
        act.stop_bits !== exp.stop_bits ||
        act.baud_div !== exp.baud_div) begin
      ok = 1'b0;
      why = {why, $sformatf("format exp(pe=%0d pt=%s sb=%s div=%0d) act(pe=%0d pt=%s sb=%s div=%0d); ",
                            exp.parity_en, exp.parity_type.name(),
                            exp.stop_bits.name(), exp.baud_div,
                            act.parity_en, act.parity_type.name(),
                            act.stop_bits.name(), act.baud_div)};
    end
    if (exp.parity_en && act.obs_parity_error) begin
      ok = 1'b0;
      why = {why, $sformatf("transmitted parity bit wrong (got %0d, expected %0d); ",
                            act.obs_parity_bit, act.expected_parity())};
    end
    if (act.obs_framing_error) begin
      ok = 1'b0;
      why = {why, $sformatf("stop bit(s) not high (s1=%0d s2=%0d); ",
                            act.obs_stop1, act.obs_stop2)};
    end

    if (ok) begin
      tx_matched++;
      `uvm_info("SB/TX/PASS",
                $sformatf("[%0d] data=0x%02h %s", tx_compared, exp.data,
                          exp.convert2string()), UVM_HIGH)
    end
    else begin
      tx_mismatched++;
      `uvm_error("SB/TX/FAIL",
                 $sformatf("TX mismatch #%0d: %s\n  expected: %s\n  actual  : %s",
                           tx_compared, why, exp.convert2string(),
                           act.convert2string()))
    end
  endfunction : write_tx_act

  //===================================================================
  // RX path
  //===================================================================
  virtual function void write_rx_exp(uart_transaction t);
    uart_transaction c;
    c = uart_transaction::type_id::create("rx_exp");
    c.copy(t);
    rx_exp_q.push_back(c);
  endfunction : write_rx_exp

  virtual function void write_rx_act(uart_transaction act);
    uart_transaction exp;
    bit              ok = 1'b1;
    string           why = "";

    if (rx_exp_q.size() == 0) begin
      `uvm_error("SB/RX/UNEXP",
                 $sformatf("DUT reported a character that was never driven: %s",
                           act.convert2string()))
      return;
    end

    exp = rx_exp_q.pop_front();
    rx_compared++;

    if (act.obs_data !== exp.obs_data) begin
      ok = 1'b0;
      why = {why, $sformatf("data exp=0x%02h act=0x%02h; ",
                            exp.obs_data, act.obs_data)};
    end
    if (act.obs_parity_error !== exp.obs_parity_error) begin
      ok = 1'b0;
      why = {why, $sformatf("parity_error exp=%0d act=%0d; ",
                            exp.obs_parity_error, act.obs_parity_error)};
    end
    if (act.obs_framing_error !== exp.obs_framing_error) begin
      ok = 1'b0;
      why = {why, $sformatf("framing_error exp=%0d act=%0d; ",
                            exp.obs_framing_error, act.obs_framing_error)};
    end
    if (act.obs_break !== exp.obs_break) begin
      ok = 1'b0;
      why = {why, $sformatf("break_detect exp=%0d act=%0d; ",
                            exp.obs_break, act.obs_break)};
    end

    if (act.obs_parity_error)  parity_err_seen++;
    if (act.obs_framing_error) framing_err_seen++;
    if (act.obs_break)         break_seen++;
    if (act.obs_overrun)       overrun_seen = 1'b1;

    if (ok) begin
      rx_matched++;
      `uvm_info("SB/RX/PASS",
                $sformatf("[%0d] %s", rx_compared, act.convert2string()), UVM_HIGH)
    end
    else begin
      rx_mismatched++;
      `uvm_error("SB/RX/FAIL",
                 $sformatf("RX mismatch #%0d: %s\n  expected: %s\n  actual  : %s",
                           rx_compared, why, exp.convert2string(),
                           act.convert2string()))
    end
  endfunction : write_rx_act

  //===================================================================
  virtual function int unsigned pending();
    return tx_exp_q.size() + rx_exp_q.size();
  endfunction : pending

  virtual function int unsigned total_compared();
    return tx_compared + rx_compared;
  endfunction : total_compared

  //===================================================================
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    if (tx_exp_q.size() != 0) begin
      `uvm_error("SB/TX/LEFTOVER",
                 $sformatf("%0d transmit request(s) never appeared on the tx pin",
                           tx_exp_q.size()))
    end
    if (rx_exp_q.size() != 0) begin
      `uvm_error("SB/RX/LEFTOVER",
                 $sformatf("%0d driven character(s) were never reported by the DUT",
                           rx_exp_q.size()))
    end
    if (total_compared() == 0) begin
      `uvm_error("SB/NO_TRAFFIC",
                 "the scoreboard compared zero frames - the test did nothing")
    end
  endfunction : check_phase

  //===================================================================
  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SB/REPORT", $sformatf({"\n",
      "  ==================== UART SCOREBOARD ====================\n",
      "   TX frames compared : %0d   (match %0d / mismatch %0d)\n",
      "   RX frames compared : %0d   (match %0d / mismatch %0d)\n",
      "   parity errors seen : %0d\n",
      "   framing errors seen: %0d\n",
      "   breaks seen        : %0d\n",
      "   overrun seen       : %0d\n",
      "  ========================================================="},
      tx_compared, tx_matched, tx_mismatched,
      rx_compared, rx_matched, rx_mismatched,
      parity_err_seen, framing_err_seen, break_seen, overrun_seen), UVM_LOW)
  endfunction : report_phase

endclass : uart_scoreboard

`endif // UART_SCOREBOARD_SV
