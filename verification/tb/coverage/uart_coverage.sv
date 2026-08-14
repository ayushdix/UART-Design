//=====================================================================
// File        : uart_coverage.sv
// Description : Functional coverage collector.  It listens on the
//               *observed* analysis ports of BOTH monitors (tx rsp_ap
//               and rx rsp_ap) so that every bin is sampled from real
//               DUT activity rather than from stimulus intent.
//
//               Every bin in this model is reachable; the unreachable
//               corners (e.g. an injected parity error on the transmit
//               path, which the TX agent cannot produce) are removed
//               with ignore_bins so that 100% is an attainable target.
//               Coverage is intended to be MERGED across the full
//               regression - see coverage.do / "make regress".
//=====================================================================
`ifndef UART_COVERAGE_SV
`define UART_COVERAGE_SV

class uart_coverage extends uvm_component;

  `uvm_component_utils(uart_coverage)

  uvm_analysis_imp #(uart_transaction, uart_coverage) analysis_export;

  uart_config  cfg;
  int unsigned n_sampled;

  //-------------------------------------------------------------------
  covergroup uart_cg with function sample(uart_transaction tr);
    option.per_instance = 1;
    option.name         = "uart_functional_cg";
    option.at_least     = 1;

    // ---------------- data ----------------
    cp_data : coverpoint tr.obs_data {
      bins zero      = {8'h00};
      bins all_ones  = {8'hFF};
      bins alt_aa    = {8'hAA};
      bins alt_55    = {8'h55};
      bins low       = {[8'h01:8'h3F]};
      bins mid_low   = {[8'h40:8'h7F]};
      bins mid_high  = {[8'h80:8'hBF]};
      bins high      = {[8'hC0:8'hFE]};
    }

    // ---------------- frame format ----------------
    cp_parity_en : coverpoint tr.parity_en {
      bins parity_none = {1'b0};
      bins parity_on   = {1'b1};
    }

    cp_parity_type : coverpoint tr.parity_type {
      bins even = {UART_PARITY_EVEN};
      bins odd  = {UART_PARITY_ODD};
    }

    cp_stop : coverpoint tr.stop_bits {
      bins one_stop = {UART_STOP_1};
      bins two_stop = {UART_STOP_2};
    }

    cp_baud : coverpoint tr.baud_div {
      bins baud_230400 = {16'd13};
      bins baud_115200 = {16'd27};
      bins baud_57600  = {16'd54};
    }

    cp_frame_len : coverpoint tr.frame_bits() {
      bins len10 = {10};   // start + 8 data + 1 stop
      bins len11 = {11};   // + parity  OR  + 2nd stop
      bins len12 = {12};   // + parity  AND + 2nd stop
    }

    // ---------------- direction / errors ----------------
    cp_dir : coverpoint tr.dir {
      bins tx = {UART_DIR_TX};
      bins rx = {UART_DIR_RX};
    }

    cp_err : coverpoint tr.err_kind {
      bins clean    = {UART_ERR_NONE};
      bins parity   = {UART_ERR_PARITY};
      bins framing  = {UART_ERR_FRAMING};
      bins brk      = {UART_ERR_BREAK};
      bins overrun  = {UART_ERR_OVERRUN};
    }

    // ---------------- crosses ----------------
    x_format : cross cp_parity_en, cp_parity_type, cp_stop;

    x_dir_baud : cross cp_dir, cp_baud;

    x_dir_data : cross cp_dir, cp_data;

    x_dir_err : cross cp_dir, cp_err {
      // The transmit agent drives the parallel side, so it can never
      // inject a wire-level error.
      ignore_bins tx_cannot_err =
        binsof(cp_dir.tx) &&
        (binsof(cp_err.parity)  || binsof(cp_err.framing) ||
         binsof(cp_err.brk)     || binsof(cp_err.overrun));
    }

    x_format_baud : cross cp_parity_en, cp_stop, cp_baud;
  endgroup : uart_cg

  //-------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
    uart_cg         = new();
  endfunction : new

  //-------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db #(uart_config)::get(this, "", "cfg", cfg));
  endfunction : build_phase

  //-------------------------------------------------------------------
  virtual function void write(uart_transaction t);
    if (t == null) return;
    uart_cg.sample(t);
    n_sampled++;
  endfunction : write

  //-------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    `uvm_info("COV/REPORT", $sformatf({"\n",
      "  ==================== FUNCTIONAL COVERAGE ================\n",
      "   samples            : %0d\n",
      "   uart_functional_cg : %0.2f %%\n",
      "  ========================================================="},
      n_sampled, uart_cg.get_inst_coverage()), UVM_LOW)
  endfunction : report_phase

endclass : uart_coverage

`endif // UART_COVERAGE_SV
