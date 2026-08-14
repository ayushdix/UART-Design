//=====================================================================
// File        : uart_env.sv
// Description : Top level verification environment.
//
//                        +----------------+
//                        |  uart_tx_agent |
//                        |  seqr/drv/mon  |
//                        +--+----------+--+
//              req_ap ------+          +------ rsp_ap
//                    |                        |    |    |
//                    v                        v    v    v
//              +----------------------------------+  +-----------+
//              |         uart_scoreboard          |  | coverage  |
//              +----------------------------------+  | subscriber|
//                    ^                        ^   ^  +-----------+
//              req_ap|                  rsp_ap|   |
//                        +----------------+
//                        |  uart_rx_agent |
//                        +----------------+
//
//               Agent configuration objects are supplied by base_test
//               through the uvm_config_db; the environment forwards its
//               own handles down so the agents, drivers and monitors all
//               share one object.
//=====================================================================
`ifndef UART_ENV_SV
`define UART_ENV_SV

class uart_env extends uvm_env;

  `uvm_component_utils(uart_env)

  uart_config      tx_cfg;
  uart_config      rx_cfg;

  uart_tx_agent    tx_agent;
  uart_rx_agent    rx_agent;
  uart_scoreboard  scoreboard;
  uart_coverage    coverage;
  uart_subscriber  subscriber;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //-------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(uart_config)::get(this, "", "tx_cfg", tx_cfg)) begin
      `uvm_warning(get_type_name(), "no tx_cfg found - creating a default one")
      tx_cfg           = uart_config::type_id::create("tx_cfg");
      tx_cfg.agent_dir = UART_DIR_TX;
    end
    if (!uvm_config_db #(uart_config)::get(this, "", "rx_cfg", rx_cfg)) begin
      `uvm_warning(get_type_name(), "no rx_cfg found - creating a default one")
      rx_cfg           = uart_config::type_id::create("rx_cfg");
      rx_cfg.agent_dir = UART_DIR_RX;
    end

    // Push each agent its own configuration.
    uvm_config_db #(uart_config)::set(this, "tx_agent", "cfg", tx_cfg);
    uvm_config_db #(uart_config)::set(this, "rx_agent", "cfg", rx_cfg);
    uvm_config_db #(uart_config)::set(this, "coverage", "cfg", tx_cfg);

    tx_agent = uart_tx_agent::type_id::create("tx_agent", this);
    rx_agent = uart_rx_agent::type_id::create("rx_agent", this);

    if (tx_cfg.has_scoreboard || rx_cfg.has_scoreboard)
      scoreboard = uart_scoreboard::type_id::create("scoreboard", this);

    if (tx_cfg.has_coverage || rx_cfg.has_coverage) begin
      coverage   = uart_coverage::type_id::create("coverage",   this);
      subscriber = uart_subscriber::type_id::create("subscriber", this);
    end
  endfunction : build_phase

  //-------------------------------------------------------------------
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // ---------------- scoreboard ----------------
    if (scoreboard != null) begin
      tx_agent.monitor.req_ap.connect(scoreboard.tx_exp_imp);
      tx_agent.monitor.rsp_ap.connect(scoreboard.tx_act_imp);
      rx_agent.monitor.req_ap.connect(scoreboard.rx_exp_imp);
      rx_agent.monitor.rsp_ap.connect(scoreboard.rx_act_imp);
    end

    // ---------------- coverage / subscriber ----------------
    if (coverage != null) begin
      tx_agent.monitor.rsp_ap.connect(coverage.analysis_export);
      rx_agent.monitor.rsp_ap.connect(coverage.analysis_export);
    end
    if (subscriber != null) begin
      tx_agent.monitor.rsp_ap.connect(subscriber.analysis_export);
      rx_agent.monitor.rsp_ap.connect(subscriber.analysis_export);
    end
  endfunction : connect_phase

endclass : uart_env

`endif // UART_ENV_SV
