//=====================================================================
// File        : uart_tx_agent.sv
// Description : Transmit agent = sequencer + uart_tx_driver +
//               uart_tx_monitor.  When cfg.is_active is UVM_PASSIVE only
//               the monitor is built.  The monitor's two analysis ports
//               are re-published at agent level so the environment does
//               not have to reach through the hierarchy.
//=====================================================================
`ifndef UART_TX_AGENT_SV
`define UART_TX_AGENT_SV

class uart_tx_agent extends uvm_agent;

  `uvm_component_utils(uart_tx_agent)

  uart_config      cfg;
  uart_sequencer   sequencer;
  uart_tx_driver   driver;
  uart_tx_monitor  monitor;

  // Re-published monitor ports.
  uvm_analysis_port #(uart_transaction) req_ap;
  uvm_analysis_port #(uart_transaction) rsp_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //-------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(uart_config)::get(this, "", "cfg", cfg)) begin
      `uvm_warning(get_type_name(), "no uart_config found - using defaults")
      cfg           = uart_config::type_id::create("cfg");
      cfg.agent_dir = UART_DIR_TX;
    end

    // Make the same config visible to the children.
    uvm_config_db #(uart_config)::set(this, "*", "cfg", cfg);

    is_active = cfg.is_active;

    monitor = uart_tx_monitor::type_id::create("monitor", this);

    if (cfg.is_active == UVM_ACTIVE) begin
      sequencer = uart_sequencer::type_id::create("sequencer", this);
      driver    = uart_tx_driver::type_id::create("driver",    this);
    end
  endfunction : build_phase

  //-------------------------------------------------------------------
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    req_ap = monitor.req_ap;
    rsp_ap = monitor.rsp_ap;

    if (cfg.is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction : connect_phase

endclass : uart_tx_agent

`endif // UART_TX_AGENT_SV
