//=====================================================================
// File        : uart_rx_driver.sv
// Description : Bit-bangs UART frames onto the DUT's serial 'rx' input
//               and drains the receive FIFO through 'rx_read'.
//
//               Error injection (driven by uart_transaction.err_kind):
//                 UART_ERR_NONE    - clean frame
//                 UART_ERR_PARITY  - parity bit inverted on the wire
//                 UART_ERR_FRAMING - stop bit driven low
//                 UART_ERR_BREAK   - line held low for a whole frame
//                 UART_ERR_OVERRUN - clean frame, but the FIFO reader is
//                                    disabled so the FIFO fills up
//
//               One bit time = baud_div * 16 system clocks, which is
//               exactly the DUT's own bit period, so the DUT's mid-bit
//               sampling always lands in the middle of a driven bit.
//=====================================================================
`ifndef UART_RX_DRIVER_SV
`define UART_RX_DRIVER_SV

class uart_rx_driver extends uart_driver;

  `uvm_component_utils(uart_rx_driver)

  protected bit read_enable = 1'b1;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //-------------------------------------------------------------------
  virtual task init_signals();
    @(vif.rx_drv_cb);
    vif.rx_drv_cb.rx <= 1'b1;          // idle line is high
  endtask : init_signals

  //-------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    fork
      fifo_reader();
    join_none
    super.run_phase(phase);
  endtask : run_phase

  //-------------------------------------------------------------------
  // Background FIFO drain.  Disabled for overrun stimulus.
  //-------------------------------------------------------------------
  protected virtual task fifo_reader();
    @(vif.rx_drv_cb);
    vif.rx_drv_cb.rx_read <= 1'b0;
    vif.wait_out_of_reset();
    forever begin
      @(vif.rx_drv_cb);
      if (read_enable && (vif.rx_drv_cb.fifo_empty === 1'b0)) begin
        vif.rx_drv_cb.rx_read <= 1'b1;
        @(vif.rx_drv_cb);
        vif.rx_drv_cb.rx_read <= 1'b0;
      end
    end
  endtask : fifo_reader

  //-------------------------------------------------------------------
  protected virtual task drive_bit(input bit val, input int unsigned n_clk);
    vif.rx_drv_cb.rx <= val;
    repeat (n_clk) @(vif.rx_drv_cb);
  endtask : drive_bit

  //-------------------------------------------------------------------
  virtual task drive_item(uart_transaction tr);
    int unsigned bc;
    bit          par;
    int unsigned n_stop;

    // ---------------- reset item ----------------
    if (tr.do_reset) begin
      vif.rx_drv_cb.rx <= 1'b1;
      vif.do_reset(tr.reset_cycles);
      vif.wait_out_of_reset();
      return;
    end

    read_enable = cfg.enable_fifo_read && (tr.err_kind != UART_ERR_OVERRUN);

    vif.set_cfg(tr.parity_en,
                bit'(tr.parity_type),
                bit'(tr.stop_bits),
                tr.baud_div);

    bc     = tr.bit_cycles();
    n_stop = tr.num_stop();
    par    = tr.expected_parity();
    if (tr.err_kind == UART_ERR_PARITY) par = ~par;

    @(vif.rx_drv_cb);

    if (tr.err_kind == UART_ERR_BREAK) begin
      // Hold the line low for one complete frame time, then release it.
      drive_bit(1'b0, bc * tr.frame_bits());
      drive_bit(1'b1, bc * 2);
    end
    else begin
      drive_bit(1'b0, bc);                                  // START
      for (int i = 0; i < 8; i++) drive_bit(tr.data[i], bc); // DATA (LSB first)
      if (tr.parity_en) drive_bit(par, bc);                 // PARITY

      if (tr.err_kind == UART_ERR_FRAMING) begin
        if ((n_stop == 2) && tr.corrupt_stop2) begin
          drive_bit(1'b1, bc);                              // good first STOP
          drive_bit(1'b0, bc);                              // corrupted second STOP
        end
        else begin
          drive_bit(1'b0, bc);                              // corrupted first STOP
          if (n_stop == 2) drive_bit(1'b1, bc);
        end
        drive_bit(1'b1, bc);                                // return to idle
      end
      else begin
        repeat (n_stop) drive_bit(1'b1, bc);                // STOP(s)
      end
    end

    // Inter-packet gap.
    drive_bit(1'b1, bc * tr.ipg_bits);

  endtask : drive_item

endclass : uart_rx_driver

`endif // UART_RX_DRIVER_SV
