//=====================================================================
// File        : uart_rx.sv
// Description : UART receiver core with 16x oversampling.
//               - 2-FF metastability synchroniser on the serial input
//               - mid-bit sampling (oversample phase 7 of 0..15)
//               - false start-bit rejection
//               - parity / framing / BREAK error detection
//               After a BREAK the core waits for the line to return high
//               before it will look for a new start bit.
//=====================================================================
`ifndef UART_RX_SV
`define UART_RX_SV

module uart_rx #(
  parameter int DATA_WIDTH = 8,
  parameter int OVERSAMPLE = 16
)(
  input  logic                  clk,
  input  logic                  rst_n,       // active low
  input  logic                  baud_tick,
  input  logic                  rx,
  input  logic                  parity_en,
  input  logic                  parity_type, // 0 = EVEN, 1 = ODD
  input  logic                  stop_bits,   // 0 = 1 stop, 1 = 2 stop
  output logic [DATA_WIDTH-1:0] data_out,
  output logic                  valid,       // 1-cycle end-of-frame pulse
  output logic                  parity_error,
  output logic                  framing_error,
  output logic                  break_detect,
  output logic                  busy
);

  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_START  = 3'd1,
    S_DATA   = 3'd2,
    S_PARITY = 3'd3,
    S_STOP1  = 3'd4,
    S_STOP2  = 3'd5,
    S_BRK    = 3'd6
  } rx_state_e;

  localparam int OS_W  = (OVERSAMPLE <= 2) ? 1 : $clog2(OVERSAMPLE);
  localparam int BIT_W = (DATA_WIDTH <= 2) ? 1 : $clog2(DATA_WIDTH);
  localparam int MID   = OVERSAMPLE/2 - 1;   // phase 7 for OVERSAMPLE=16

  // ---------------- input synchroniser ----------------
  logic rx_q1, rx_q2;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_q1 <= 1'b1;
      rx_q2 <= 1'b1;
    end
    else begin
      rx_q1 <= rx;
      rx_q2 <= rx_q1;
    end
  end
  wire rx_s = rx_q2;

  rx_state_e             state;
  logic [OS_W-1:0]       os_cnt;
  logic [BIT_W-1:0]      bit_cnt;
  logic [DATA_WIDTH-1:0] shreg;
  logic                  par_rx;
  logic                  stop1_rx, stop2_rx;
  logic                  p_en_l, p_type_l, stop_l;
  logic                  exp_par;

  wire sample_mid = baud_tick && (os_cnt == OS_W'(MID));
  wire bit_done   = baud_tick && (os_cnt == OS_W'(OVERSAMPLE-1));

  assign busy = (state != S_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      os_cnt        <= '0;
      bit_cnt       <= '0;
      shreg         <= '0;
      par_rx        <= 1'b0;
      stop1_rx      <= 1'b1;
      stop2_rx      <= 1'b1;
      p_en_l        <= 1'b0;
      p_type_l      <= 1'b0;
      stop_l        <= 1'b0;
      data_out      <= '0;
      valid         <= 1'b0;
      parity_error  <= 1'b0;
      framing_error <= 1'b0;
      break_detect  <= 1'b0;
    end
    else begin
      valid <= 1'b0;

      // --------------- oversample counter ---------------
      if ((state == S_IDLE) || (state == S_BRK)) begin
        os_cnt <= '0;
      end
      else if (baud_tick) begin
        os_cnt <= (os_cnt == OS_W'(OVERSAMPLE-1)) ? '0 : (os_cnt + 1'b1);
      end

      // --------------- frame state machine --------------
      unique case (state)

        S_IDLE : begin
          if (!rx_s) begin                  // falling edge -> possible START
            p_en_l   <= parity_en;
            p_type_l <= parity_type;
            stop_l   <= stop_bits;
            shreg    <= '0;
            par_rx   <= 1'b0;
            stop1_rx <= 1'b1;
            stop2_rx <= 1'b1;
            bit_cnt  <= '0;
            state    <= S_START;
          end
        end

        S_START : begin
          if (sample_mid && rx_s) begin
            state <= S_IDLE;                // false start -> abort
          end
          else if (bit_done) begin
            bit_cnt <= '0;
            state   <= S_DATA;
          end
        end

        S_DATA : begin
          if (sample_mid) begin
            shreg[bit_cnt] <= rx_s;
          end
          if (bit_done) begin
            if (bit_cnt == BIT_W'(DATA_WIDTH-1)) begin
              state <= p_en_l ? S_PARITY : S_STOP1;
            end
            else begin
              bit_cnt <= bit_cnt + 1'b1;
            end
          end
        end

        S_PARITY : begin
          if (sample_mid) par_rx <= rx_s;
          if (bit_done)   state  <= S_STOP1;
        end

        S_STOP1 : begin
          if (sample_mid) stop1_rx <= rx_s;
          if (bit_done) begin
            if (stop_l) begin
              state <= S_STOP2;
            end
            else begin
              // -------- end of frame (1 stop bit) --------
              data_out      <= shreg;
              valid         <= 1'b1;
              parity_error  <= p_en_l && (par_rx != exp_par);
              framing_error <= !stop1_rx;
              break_detect  <= (shreg == '0) && (!p_en_l || !par_rx) && !stop1_rx;
              state         <= ((shreg == '0) && (!p_en_l || !par_rx) && !stop1_rx)
                               ? S_BRK : S_IDLE;
            end
          end
        end

        S_STOP2 : begin
          if (sample_mid) stop2_rx <= rx_s;
          if (bit_done) begin
            // -------- end of frame (2 stop bits) --------
            data_out      <= shreg;
            valid         <= 1'b1;
            parity_error  <= p_en_l && (par_rx != exp_par);
            framing_error <= !stop1_rx || !stop2_rx;
            break_detect  <= (shreg == '0) && (!p_en_l || !par_rx) && !stop1_rx;
            state         <= ((shreg == '0) && (!p_en_l || !par_rx) && !stop1_rx)
                             ? S_BRK : S_IDLE;
          end
        end

        S_BRK : begin
          if (rx_s) state <= S_IDLE;        // wait for line to idle high
        end

        default : state <= S_IDLE;

      endcase
    end
  end

  // Expected parity over the bits captured so far.
  always_comb begin
    exp_par = p_type_l ? ~(^shreg) : (^shreg);
  end

endmodule : uart_rx

`endif // UART_RX_SV
