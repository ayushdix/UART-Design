//=====================================================================
// File        : uart_tx_driver.sv
// Description : Drives the PARALLEL transmit side of the DUT
//               (start / tx_data) and owns the reset signal.
//
//               Per item:
//                 do_reset==1 -> pulse the active-low reset
//                 otherwise   -> program the frame format, wait for
//                                !busy, pulse start for one clock, wait
//                                for done, then idle for the requested
//                                inter-packet gap.
//
//               The resulting serial stream on 'tx' is decoded
//               independently by uart_tx_monitor.
//=====================================================================
`ifndef UART_TX_DRIVER_SV
`define UART_TX_DRIVER_SV

class uart_tx_driver extends uart_driver;

  `uvm_component_utils(uart_tx_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //-------------------------------------------------------------------
  virtual task init_signals();
    @(vif.drv_cb);
    vif.drv_cb.start   <= 1'b0;
    vif.drv_cb.tx_data <= '0;
  endtask : init_signals

  //-------------------------------------------------------------------
  virtual task drive_item(uart_transaction tr);

    // ---------------- reset item ----------------
    if (tr.do_reset) begin
      `uvm_info(get_type_name(),
                $sformatf("applying reset for %0d clocks", tr.reset_cycles),
                UVM_LOW)
      vif.drv_cb.start   <= 1'b0;
      vif.drv_cb.tx_data <= '0;
      vif.do_reset(tr.reset_cycles);
      init_signals();
      vif.wait_out_of_reset();
      return;
    end

    // ---------------- normal frame ----------------
    vif.set_cfg(tr.parity_en,
                bit'(tr.parity_type),
                bit'(tr.stop_bits),
                tr.baud_div);

    @(vif.drv_cb);
    while (vif.drv_cb.busy === 1'b1) @(vif.drv_cb);

    vif.drv_cb.start   <= 1'b1;
    vif.drv_cb.tx_data <= tr.data;
    @(vif.drv_cb);
    vif.drv_cb.start   <= 1'b0;

    // Wait for the end-of-frame pulse.
    do @(vif.drv_cb); while (vif.drv_cb.done !== 1'b1);

    // Inter-packet gap (line idles high between frames).
    repeat (tr.ipg_bits * tr.bit_cycles()) @(vif.drv_cb);

  endtask : drive_item

endclass : uart_tx_driver

`endif // UART_TX_DRIVER_SV
