//=====================================================================
// File        : uart_rx_agent.sv
// Description : Receive agent = sequencer + uart_rx_driver +
//               uart_rx_monitor.  Structurally identical to the TX
//               agent; only the driver/monitor types differ.
//=====================================================================
`ifndef UART_RX_AGENT_SV
`define UART_RX_AGENT_SV

class uart_rx_agent extends uvm_agent;

  `uvm_component_utils(uart_rx_agent)

  uart_config      cfg;
  uart_sequencer   sequencer;
  uart_rx_driver   driver;
  uart_rx_monitor  monitor;

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
      cfg.agent_dir = UART_DIR_RX;
    end

    uvm_config_db #(uart_config)::set(this, "*", "cfg", cfg);

    is_active = cfg.is_active;

    monitor = uart_rx_monitor::type_id::create("monitor", this);

    if (cfg.is_active == UVM_ACTIVE) begin
      sequencer = uart_sequencer::type_id::create("sequencer", this);
      driver    = uart_rx_driver::type_id::create("driver",    this);
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

endclass : uart_rx_agent

`endif // UART_RX_AGENT_SV
