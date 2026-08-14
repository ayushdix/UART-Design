//=====================================================================
// File        : uart_tx.sv
// Description : UART transmitter core.
//               Frame = START(0) + DATA[7:0] LSB-first + [PARITY] + STOP(1/2)
//               Configuration (parity_en / parity_type / stop_bits) is
//               latched at the beginning of every frame so that the
//               testbench may re-program it between frames.
//=====================================================================
`ifndef UART_TX_SV
`define UART_TX_SV

module uart_tx #(
  parameter int DATA_WIDTH = 8,
  parameter int OVERSAMPLE = 16
)(
  input  logic                  clk,
  input  logic                  rst_n,       // active low
  input  logic                  baud_tick,   // OVERSAMPLE ticks per bit
  input  logic                  start,       // 1-cycle request pulse
  input  logic [DATA_WIDTH-1:0] data_in,
  input  logic                  parity_en,
  input  logic                  parity_type, // 0 = EVEN, 1 = ODD
  input  logic                  stop_bits,   // 0 = 1 stop, 1 = 2 stop
  output logic                  tx,
  output logic                  busy,
  output logic                  done         // 1-cycle end-of-frame pulse
);

  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_START  = 3'd1,
    S_DATA   = 3'd2,
    S_PARITY = 3'd3,
    S_STOP1  = 3'd4,
    S_STOP2  = 3'd5
  } tx_state_e;

  localparam int OS_W  = (OVERSAMPLE  <= 2) ? 1 : $clog2(OVERSAMPLE);
  localparam int BIT_W = (DATA_WIDTH  <= 2) ? 1 : $clog2(DATA_WIDTH);

  tx_state_e              state;
  logic [OS_W-1:0]        os_cnt;
  logic [BIT_W-1:0]       bit_cnt;
  logic [DATA_WIDTH-1:0]  shreg;
  logic                   par_bit;
  logic                   p_en_l, p_type_l, stop_l;

  // A bit boundary occurs on the last oversample tick of the bit period.
  wire bit_done = baud_tick && (os_cnt == OS_W'(OVERSAMPLE-1));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= S_IDLE;
      tx       <= 1'b1;
      busy     <= 1'b0;
      done     <= 1'b0;
      os_cnt   <= '0;
      bit_cnt  <= '0;
      shreg    <= '0;
      par_bit  <= 1'b0;
      p_en_l   <= 1'b0;
      p_type_l <= 1'b0;
      stop_l   <= 1'b0;
    end
    else begin
      done <= 1'b0;

      // --------------- oversample counter ---------------
      if (state == S_IDLE) begin
        os_cnt <= '0;
      end
      else if (baud_tick) begin
        os_cnt <= (os_cnt == OS_W'(OVERSAMPLE-1)) ? '0 : (os_cnt + 1'b1);
      end

      // --------------- frame state machine --------------
      unique case (state)

        S_IDLE : begin
          tx   <= 1'b1;
          busy <= 1'b0;
          if (start) begin
            shreg    <= data_in;
            p_en_l   <= parity_en;
            p_type_l <= parity_type;
            stop_l   <= stop_bits;
            par_bit  <= parity_type ? ~(^data_in) : (^data_in);
            bit_cnt  <= '0;
            busy     <= 1'b1;
            tx       <= 1'b0;          // START bit
            state    <= S_START;
          end
        end

        S_START : begin
          if (bit_done) begin
            tx      <= shreg[0];
            bit_cnt <= '0;
            state   <= S_DATA;
          end
        end

        S_DATA : begin
          if (bit_done) begin
            if (bit_cnt == BIT_W'(DATA_WIDTH-1)) begin
              if (p_en_l) begin
                tx    <= par_bit;
                state <= S_PARITY;
              end
              else begin
                tx    <= 1'b1;          // STOP bit
                state <= S_STOP1;
              end
            end
            else begin
              bit_cnt <= bit_cnt + 1'b1;
              tx      <= shreg[bit_cnt + 1'b1];
            end
          end
        end

        S_PARITY : begin
          if (bit_done) begin
            tx    <= 1'b1;              // STOP bit
            state <= S_STOP1;
          end
        end

        S_STOP1 : begin
          if (bit_done) begin
            tx <= 1'b1;
            if (stop_l) begin
              state <= S_STOP2;
            end
            else begin
              busy  <= 1'b0;
              done  <= 1'b1;
              state <= S_IDLE;
            end
          end
        end

        S_STOP2 : begin
          if (bit_done) begin
            tx    <= 1'b1;
            busy  <= 1'b0;
            done  <= 1'b1;
            state <= S_IDLE;
          end
        end

        default : state <= S_IDLE;

      endcase
    end
  end

endmodule : uart_tx

`endif // UART_TX_SV
