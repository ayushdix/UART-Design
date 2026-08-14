//=====================================================================
// File        : uart_config.sv
// Description : Agent / environment configuration object.  One instance
//               is created per agent by base_test and published through
//               the uvm_config_db so that the agent, its driver and its
//               monitor all see exactly the same settings.
//=====================================================================
`ifndef UART_CONFIG_SV
`define UART_CONFIG_SV

class uart_config extends uvm_object;

  // ---- topology ----
  uvm_active_passive_enum is_active       = UVM_ACTIVE;
  uart_dir_e              agent_dir       = UART_DIR_TX;
  bit                     has_coverage    = 1'b1;
  bit                     has_scoreboard  = 1'b1;

  // ---- DUT / protocol ----
  int unsigned            clk_freq_hz     = 50_000_000;
  int unsigned            baud_rate       = 115200;
  int unsigned            oversample      = 16;
  int unsigned            fifo_depth      = 16;

  // ---- driver behaviour ----
  bit                     enable_fifo_read = 1'b1;   // cleared by overrun_test
  int unsigned            reset_cycles     = 10;

  // ---- virtual interface ----
  virtual uart_if         vif;

  `uvm_object_utils(uart_config)

  function new(string name = "uart_config");
    super.new(name);
  endfunction : new

  // Divider that produces 'baud_rate' with 'oversample' phases per bit.
  function bit [15:0] calc_div();
    int unsigned d;
    d = clk_freq_hz / (baud_rate * oversample);
    if (d < 2)      d = 2;
    if (d > 65535)  d = 65535;
    return 16'(d);
  endfunction : calc_div

  virtual function string convert2string();
    return $sformatf({"uart_config: dir=%s active=%s cov=%0d sb=%0d ",
                      "clk=%0d baud=%0d os=%0d div=%0d fifo_rd=%0d"},
                     agent_dir.name(), is_active.name(), has_coverage,
                     has_scoreboard, clk_freq_hz, baud_rate, oversample,
                     calc_div(), enable_fifo_read);
  endfunction : convert2string

  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_string("cfg", convert2string());
  endfunction : do_print

endclass : uart_config

`endif // UART_CONFIG_SV
