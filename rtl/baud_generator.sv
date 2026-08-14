//=====================================================================
// File        : baud_generator.sv
// Description : Programmable baud-rate / oversampling tick generator.
//               Produces one single-cycle 'tick' every 'baud_div' system
//               clocks.  The UART TX/RX cores consume 16 ticks per bit
//               (16x oversampling).
//
//               f_tick = f_clk / baud_div
//               baud   = f_tick / OVERSAMPLE
//
//               50 MHz / 27 / 16 = 115_740 baud  (0.47% error vs 115200)
//=====================================================================
`ifndef BAUD_GENERATOR_SV
`define BAUD_GENERATOR_SV

module baud_generator #(
  parameter int DIV_WIDTH = 16
)(
  input  logic                 clk,
  input  logic                 rst_n,      // active low
  input  logic                 enable,
  input  logic [DIV_WIDTH-1:0] baud_div,
  output logic                 tick
);

  logic [DIV_WIDTH-1:0] cnt;

  // Guard against a divider of 0/1 programmed by mistake.
  wire [DIV_WIDTH-1:0] div_eff = (baud_div < 2) ? DIV_WIDTH'(2) : baud_div;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt  <= '0;
      tick <= 1'b0;
    end
    else if (!enable) begin
      cnt  <= '0;
      tick <= 1'b0;
    end
    else if (cnt >= (div_eff - 1'b1)) begin
      cnt  <= '0;
      tick <= 1'b1;
    end
    else begin
      cnt  <= cnt + 1'b1;
      tick <= 1'b0;
    end
  end

endmodule : baud_generator

`endif // BAUD_GENERATOR_SV
