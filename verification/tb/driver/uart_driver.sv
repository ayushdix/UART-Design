//=====================================================================
// File        : uart_driver.sv
// Description : Common base class for both UART drivers.  It owns the
//               virtual interface lookup, the reset handshake and the
//               get_next_item / item_done loop.  The direction specific
//               behaviour lives in uart_tx_driver and uart_rx_driver
//               which only override init_signals() and drive_item().
//=====================================================================
`ifndef UART_DRIVER_SV
`define UART_DRIVER_SV

class uart_driver extends uvm_driver #(uart_transaction);

  `uvm_component_utils(uart_driver)

  uart_config     cfg;
  virtual uart_if vif;
  int unsigned    n_driven;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //-------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(uart_config)::get(this, "", "cfg", cfg)) begin
      `uvm_warning(get_type_name(),
                   "no uart_config in the config_db - using defaults")
      cfg = uart_config::type_id::create("cfg");
    end

    // The interface may arrive either inside the config object or
    // directly through the config_db; support both.
    if (cfg.vif != null) begin
      vif = cfg.vif;
    end
    else if (!uvm_config_db #(virtual uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "virtual uart_if not found in the config_db")
    end
  endfunction : build_phase

  //-------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    init_signals();
    vif.wait_out_of_reset();
    forever begin
      seq_item_port.get_next_item(req);
      `uvm_info(get_type_name(),
                $sformatf("DRIVE %s", req.convert2string()), UVM_HIGH)
      drive_item(req);
      n_driven++;
      seq_item_port.item_done();
    end
  endtask : run_phase

  //-------------------------------------------------------------------
  // Overridden by the concrete drivers.
  //-------------------------------------------------------------------
  virtual task init_signals();
  endtask : init_signals

  virtual task drive_item(uart_transaction tr);
  endtask : drive_item

  //-------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
              $sformatf("drove %0d items", n_driven), UVM_LOW)
  endfunction : report_phase

endclass : uart_driver

`endif // UART_DRIVER_SV
