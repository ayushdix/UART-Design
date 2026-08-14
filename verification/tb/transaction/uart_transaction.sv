//=====================================================================
// File        : uart_transaction.sv
// Description : The UART sequence item.  A single object type is used
//               for stimulus (the 'rand' fields) and for observation
//               (the 'obs_*' fields) so that the scoreboard can compare
//               an expected item against an observed item field by field.
//
//               copy() / compare() / print() / pack() / unpack() are the
//               uvm_object entry points; the class-specific behaviour is
//               supplied by do_copy(), do_compare(), do_print(),
//               do_pack() and do_unpack() below.  Field automation
//               macros are deliberately NOT used (they are slow and they
//               would fight the hand written do_* methods).
//=====================================================================
`ifndef UART_TRANSACTION_SV
`define UART_TRANSACTION_SV

class uart_transaction extends uvm_sequence_item;

  //-------------------------------------------------------------------
  // Stimulus (randomised)
  //-------------------------------------------------------------------
  rand bit [7:0]       data;
  rand bit             parity_en;
  rand uart_parity_e   parity_type;
  rand uart_stop_e     stop_bits;
  rand bit [15:0]      baud_div;
  rand uart_err_e      err_kind;
  rand uart_dir_e      dir;
  rand bit             do_reset;
  rand int unsigned    reset_cycles;
  rand int unsigned    ipg_bits;      // idle bit-times between frames

  // With err_kind == UART_ERR_FRAMING and stop_bits == UART_STOP_2 this
  // selects WHICH stop bit is driven low: 0 = the first, 1 = the second.
  // Corrupting only the second stop bit is the case that exercises the
  // second half of the receiver's framing_error term.
  rand bit             corrupt_stop2;

  //-------------------------------------------------------------------
  // Observation (filled in by the monitors)
  //-------------------------------------------------------------------
  bit [7:0]            obs_data;
  bit                  obs_parity_bit;
  bit                  obs_parity_error;
  bit                  obs_framing_error;
  bit                  obs_break;
  bit                  obs_overrun;
  bit                  obs_stop1;
  bit                  obs_stop2;
  bit                  obs_start_ok;
  bit                  decode_ok;
  time                 stamp;

  `uvm_object_utils(uart_transaction)

  //-------------------------------------------------------------------
  // Constraints
  //-------------------------------------------------------------------
  // 27 -> 115200, 54 -> 57600, 13 -> 230400 baud @ 50 MHz / 16x
  constraint c_baud_set  { baud_div inside {16'd13, 16'd27, 16'd54}; }
  constraint c_baud_dist { baud_div dist {16'd27 := 70, 16'd54 := 20, 16'd13 := 10}; }

  constraint c_reset     { soft do_reset == 1'b0;
                           reset_cycles inside {[5:20]}; }

  constraint c_err       { soft err_kind == UART_ERR_NONE; }

  constraint c_ipg       { ipg_bits inside {[1:3]}; }

  // Only meaningful for a 2-stop-bit framing error; forced off otherwise
  // so that the item stays canonical.
  constraint c_stop2_err { (err_kind != UART_ERR_FRAMING ||
                            stop_bits != UART_STOP_2) -> corrupt_stop2 == 1'b0; }

  //-------------------------------------------------------------------
  function new(string name = "uart_transaction");
    super.new(name);
  endfunction : new

  //-------------------------------------------------------------------
  // Helpers
  //-------------------------------------------------------------------
  // Parity bit that a correct transmitter would emit for 'data'.
  function bit expected_parity();
    return (parity_type == UART_PARITY_ODD) ? ~(^data) : (^data);
  endfunction : expected_parity

  function int unsigned num_stop();
    return (stop_bits == UART_STOP_2) ? 2 : 1;
  endfunction : num_stop

  // Total frame length in bit times.
  function int unsigned frame_bits();
    return 1 + 8 + (parity_en ? 1 : 0) + num_stop();
  endfunction : frame_bits

  // Clock cycles per bit for this item's baud divider (16x oversampling).
  function int unsigned bit_cycles();
    return baud_div * 16;
  endfunction : bit_cycles

  //-------------------------------------------------------------------
  // do_copy  -> used by copy()
  //-------------------------------------------------------------------
  virtual function void do_copy(uvm_object rhs);
    uart_transaction t;
    if (!$cast(t, rhs)) begin
      `uvm_fatal("UART_TR/COPY", "do_copy(): rhs is not a uart_transaction")
    end
    super.do_copy(rhs);

    data              = t.data;
    parity_en         = t.parity_en;
    parity_type       = t.parity_type;
    stop_bits         = t.stop_bits;
    baud_div          = t.baud_div;
    err_kind          = t.err_kind;
    dir               = t.dir;
    do_reset          = t.do_reset;
    reset_cycles      = t.reset_cycles;
    ipg_bits          = t.ipg_bits;
    corrupt_stop2     = t.corrupt_stop2;

    obs_data          = t.obs_data;
    obs_parity_bit    = t.obs_parity_bit;
    obs_parity_error  = t.obs_parity_error;
    obs_framing_error = t.obs_framing_error;
    obs_break         = t.obs_break;
    obs_overrun       = t.obs_overrun;
    obs_stop1         = t.obs_stop1;
    obs_stop2         = t.obs_stop2;
    obs_start_ok      = t.obs_start_ok;
    decode_ok         = t.decode_ok;
    stamp             = t.stamp;
  endfunction : do_copy

  //-------------------------------------------------------------------
  // do_compare -> used by compare()
  //-------------------------------------------------------------------
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    uart_transaction t;
    bit ok = 1'b1;
    if (!$cast(t, rhs)) return 1'b0;
    ok &= super.do_compare(rhs, comparer);

    ok &= comparer.compare_field_int("data",        data,        t.data,        8);
    ok &= comparer.compare_field_int("parity_en",   parity_en,   t.parity_en,   1);
    ok &= comparer.compare_field_int("parity_type", parity_type, t.parity_type, 1);
    ok &= comparer.compare_field_int("stop_bits",   stop_bits,   t.stop_bits,   1);
    ok &= comparer.compare_field_int("baud_div",    baud_div,    t.baud_div,   16);
    return ok;
  endfunction : do_compare

  //-------------------------------------------------------------------
  // do_print -> used by print()
  //-------------------------------------------------------------------
  // print_generic() and print_string() are used rather than
  // print_field_int(): both are non-deprecated in UVM 1.2 and they keep
  // the item printable under Questa's built-in UVM 1.1d as well.
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_string ("dir",         dir.name());
    printer.print_generic("data",        "bit[7:0]",  8, $sformatf("0x%02h", data));
    printer.print_generic("parity_en",   "bit",       1, $sformatf("%0b", parity_en));
    printer.print_string ("parity_type", parity_type.name());
    printer.print_string ("stop_bits",   stop_bits.name());
    printer.print_generic("baud_div",    "bit[15:0]",16, $sformatf("%0d", baud_div));
    printer.print_string ("err_kind",    err_kind.name());
    printer.print_generic("corrupt_stop2","bit",      1, $sformatf("%0b", corrupt_stop2));
    printer.print_generic("obs_data",    "bit[7:0]",  8, $sformatf("0x%02h", obs_data));
    printer.print_generic("obs_par_err", "bit",       1, $sformatf("%0b", obs_parity_error));
    printer.print_generic("obs_frm_err", "bit",       1, $sformatf("%0b", obs_framing_error));
    printer.print_generic("obs_break",   "bit",       1, $sformatf("%0b", obs_break));
    printer.print_generic("obs_overrun", "bit",       1, $sformatf("%0b", obs_overrun));
    printer.print_generic("decode_ok",   "bit",       1, $sformatf("%0b", decode_ok));
  endfunction : do_print

  //-------------------------------------------------------------------
  // do_pack / do_unpack -> used by pack() / unpack()
  //-------------------------------------------------------------------
  virtual function void do_pack(uvm_packer packer);
    super.do_pack(packer);
    packer.pack_field_int(data,             8);
    packer.pack_field_int(parity_en,        1);
    packer.pack_field_int(int'(parity_type), 1);
    packer.pack_field_int(int'(stop_bits),   1);
    packer.pack_field_int(baud_div,         16);
    packer.pack_field_int(int'(err_kind),    4);
    packer.pack_field_int(int'(dir),         2);
    packer.pack_field_int(obs_data,          8);
    packer.pack_field_int(obs_parity_error,  1);
    packer.pack_field_int(obs_framing_error, 1);
    packer.pack_field_int(obs_break,         1);
    packer.pack_field_int(obs_overrun,       1);
  endfunction : do_pack

  virtual function void do_unpack(uvm_packer packer);
    super.do_unpack(packer);
    data              = packer.unpack_field_int(8);
    parity_en         = packer.unpack_field_int(1);
    parity_type       = uart_parity_e'(packer.unpack_field_int(1));
    stop_bits         = uart_stop_e'  (packer.unpack_field_int(1));
    baud_div          = packer.unpack_field_int(16);
    err_kind          = uart_err_e'   (packer.unpack_field_int(4));
    dir               = uart_dir_e'   (packer.unpack_field_int(2));
    obs_data          = packer.unpack_field_int(8);
    obs_parity_error  = packer.unpack_field_int(1);
    obs_framing_error = packer.unpack_field_int(1);
    obs_break         = packer.unpack_field_int(1);
    obs_overrun       = packer.unpack_field_int(1);
  endfunction : do_unpack

  //-------------------------------------------------------------------
  virtual function string convert2string();
    return $sformatf({"%s data=0x%02h par_en=%0d par=%s stop=%s div=%0d err=%s | ",
                      "obs=0x%02h perr=%0d ferr=%0d brk=%0d ovr=%0d ok=%0d"},
                     dir.name(), data, parity_en, parity_type.name(),
                     stop_bits.name(), baud_div, err_kind.name(),
                     obs_data, obs_parity_error, obs_framing_error,
                     obs_break, obs_overrun, decode_ok);
  endfunction : convert2string

endclass : uart_transaction

`endif // UART_TRANSACTION_SV
