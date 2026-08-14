//=====================================================================
// File        : uart_sequencer.sv
// Description : Sequencer for uart_transaction items.  One instance
//               lives inside each ACTIVE agent (TX and RX); tests start
//               their sequences on env.tx_agent.sequencer and
//               env.rx_agent.sequencer.
//=====================================================================
`ifndef UART_SEQUENCER_SV
`define UART_SEQUENCER_SV

class uart_sequencer extends uvm_sequencer #(uart_transaction);

  `uvm_component_utils(uart_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

endclass : uart_sequencer

`endif // UART_SEQUENCER_SV
