//=====================================================================
// File        : base_test.sv
// Description : Root test.  Builds the environment, creates and
//               publishes the two agent configuration objects, hands the
//               virtual interface down through the config_db and runs
//               the objection / drain protocol.  Derived tests only need
//               to override configure() and/or run_stimulus().
//
//               NOTE ON STIMULUS ORDERING
//               The DUT has a single shared format register bank
//               (parity_en / parity_type / stop_bits / baud_div).  Both
//               drivers reprogram it per frame, so TX and RX stimulus is
//               always run SEQUENTIALLY, never in parallel.  Every test
//               in this library respects that.
//=====================================================================
`ifndef BASE_TEST_SV
`define BASE_TEST_SV

class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  uart_env        env;
  uart_config     tx_cfg;
  uart_config     rx_cfg;
  virtual uart_if vif;

  // Time allowed after the last sequence for in-flight frames to be
  // observed and scoreboarded.
  int unsigned    drain_ns = 20_000;   // 20 us = 1000 clocks @ 50 MHz

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //-------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(virtual uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(),
                 "virtual uart_if not found - did tb_top set it in the config_db?")
    end

    tx_cfg                  = uart_config::type_id::create("tx_cfg");
    tx_cfg.agent_dir        = UART_DIR_TX;
    tx_cfg.is_active        = UVM_ACTIVE;
    tx_cfg.vif              = vif;

    rx_cfg                  = uart_config::type_id::create("rx_cfg");
    rx_cfg.agent_dir        = UART_DIR_RX;
    rx_cfg.is_active        = UVM_ACTIVE;
    rx_cfg.vif              = vif;

    configure();   // test specific tweaks

    uvm_config_db #(uart_config)::set(this, "env", "tx_cfg", tx_cfg);
    uvm_config_db #(uart_config)::set(this, "env", "rx_cfg", rx_cfg);
    uvm_config_db #(virtual uart_if)::set(this, "env*", "vif", vif);

    env = uart_env::type_id::create("env", this);
  endfunction : build_phase

  //-------------------------------------------------------------------
  // Hook for derived tests to alter the agent configuration.
  //-------------------------------------------------------------------
  virtual function void configure();
  endfunction : configure

  //-------------------------------------------------------------------
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info(get_type_name(), $sformatf("\n%s", tx_cfg.convert2string()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("\n%s", rx_cfg.convert2string()), UVM_LOW)
    uvm_top.print_topology();
  endfunction : end_of_elaboration_phase

  //-------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, {get_type_name(), " running"});
    phase.phase_done.set_drain_time(this, drain_ns * 1ns);

    `uvm_info(get_type_name(), "waiting for the DUT to leave reset", UVM_LOW)
    vif.wait_out_of_reset();

    run_stimulus(phase);

    `uvm_info(get_type_name(), "stimulus complete - draining", UVM_LOW)
    phase.drop_objection(this, {get_type_name(), " done"});
  endtask : run_phase

  //-------------------------------------------------------------------
  // Overridden by every concrete test.
  //-------------------------------------------------------------------
  virtual task run_stimulus(uvm_phase phase);
    `uvm_warning(get_type_name(), "base_test has no stimulus of its own")
  endtask : run_stimulus

  //-------------------------------------------------------------------
  // Convenience wrappers used by the derived tests.
  //-------------------------------------------------------------------
  virtual task run_on_tx(uvm_sequence #(uart_transaction) seq);
    seq.start(env.tx_agent.sequencer);
  endtask : run_on_tx

  virtual task run_on_rx(uvm_sequence #(uart_transaction) seq);
    seq.start(env.rx_agent.sequencer);
  endtask : run_on_rx

  //-------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr = uvm_report_server::get_server();
    int unsigned n_err   = svr.get_severity_count(UVM_ERROR);
    int unsigned n_fatal = svr.get_severity_count(UVM_FATAL);
    int unsigned n_frames= (env != null && env.scoreboard != null)
                           ? env.scoreboard.total_compared() : 0;
    int          fh;

    super.report_phase(phase);

    // Machine-readable verdict, consumed by regress.do.
    fh = $fopen($sformatf("result_%s.txt", get_type_name()), "w");
    if (fh) begin
      $fdisplay(fh, "%s %s errors=%0d fatals=%0d frames=%0d",
                ((n_err == 0) && (n_fatal == 0)) ? "PASS" : "FAIL",
                get_type_name(), n_err, n_fatal, n_frames);
      $fclose(fh);
    end

    if ((n_err == 0) && (n_fatal == 0)) begin
      `uvm_info("TEST_RESULT", $sformatf({"\n",
        "  #########################################################\n",
        "  ##                  TEST PASSED                        ##\n",
        "  ##  test    : %-41s##\n",
        "  ##  frames  : %-41d##\n",
        "  #########################################################"},
        get_type_name(), n_frames), UVM_NONE)
    end
    else begin
      `uvm_info("TEST_RESULT", $sformatf({"\n",
        "  #########################################################\n",
        "  ##                  TEST FAILED                        ##\n",
        "  ##  test    : %-41s##\n",
        "  ##  errors  : %-41d##\n",
        "  ##  fatals  : %-41d##\n",
        "  #########################################################"},
        get_type_name(), n_err, n_fatal), UVM_NONE)
    end
  endfunction : report_phase

endclass : base_test

`endif // BASE_TEST_SV
