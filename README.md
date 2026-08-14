# UART UVM Verification Environment

A complete, self-checking UVM 1.2 verification environment for a configurable
UART, targeting QuestaSim.

| Item | Value |
|---|---|
| Protocol | UART, no flow control |
| System clock | 50 MHz |
| Baud rates | 115200 (default), 57600, 230400 |
| Data bits | 8, LSB first |
| Parity | None / Even / Odd (per frame) |
| Stop bits | 1 or 2 (per frame) |
| Oversampling | 16x |
| Reset | Asynchronous, active LOW |
| Methodology | UVM 1.2 |
| Simulator | QuestaSim |

---

## 1. Directory layout

```
uart_uvm/
├── rtl/
│   ├── uart_top.sv                 DUT top: baud gen + TX + RX + RX FIFO
│   ├── uart_tx.sv                  transmitter FSM
│   ├── uart_rx.sv                  receiver FSM (16x oversampling)
│   ├── baud_generator.sv           programmable tick generator
│   └── uart_fifo.sv                synchronous receive FIFO
│
├── verification/tb/
│   ├── tb_top.sv                   static top: clock, reset, DUT, SVA, run_test()
│   ├── tb_pkg.sv                   test package
│   ├── interface/uart_if.sv        pins, clocking blocks, modports, reset/cfg tasks
│   ├── transaction/uart_transaction.sv
│   ├── sequence/                   base, reset, tx, rx, random, parity,
│   │                               framing_error, break, overrun
│   ├── sequencer/uart_sequencer.sv
│   ├── driver/                     uart_driver (base), uart_tx_driver, uart_rx_driver
│   ├── monitor/                    uart_tx_monitor, uart_rx_monitor
│   ├── agent/                      uart_tx_agent, uart_rx_agent
│   ├── scoreboard/uart_scoreboard.sv
│   ├── coverage/uart_coverage.sv
│   ├── subscriber/uart_subscriber.sv
│   ├── env/uart_env.sv
│   ├── config/uart_config.sv
│   ├── assertions/uart_assertions.sv
│   ├── tests/                      base, smoke, reset, tx, rx, random, parity,
│   │                               framing_error, break, overrun, stress
│   └── package/uart_pkg.sv         verification IP package
│
└── sim/
    ├── compile.do                  library creation + ordered compile
    ├── run.do                      elaborate + run one test + save coverage
    ├── run_questa.do               compile.do + run.do (one-shot)
    ├── regress.do                  run the whole test list + merge coverage
    ├── coverage.do                 merge UCDBs + write reports
    ├── wave.do                     waveform setup
    ├── Makefile                    GNU make front end
    └── run.sh                      shell front end
```

---

## 2. Environment architecture

```
                              uart_env
   ┌──────────────────────────────────────────────────────────────┐
   │                                                              │
   │   uart_tx_agent                        uart_rx_agent         │
   │   ┌──────────────────┐                 ┌──────────────────┐  │
   │   │ uart_sequencer   │                 │ uart_sequencer   │  │
   │   │ uart_tx_driver   │ parallel        │ uart_rx_driver   │  │ serial
   │   │ uart_tx_monitor  │ start/tx_data   │ uart_rx_monitor  │  │ rx pin
   │   └───┬──────────┬───┘                 └───┬──────────┬───┘  │
   │  req_ap│      rsp_ap                  req_ap│      rsp_ap    │
   └────────┼──────────┼─────────────────────────┼──────────┼─────┘
            │          │                         │          │
            v          v                         v          v
        ┌────────────────────────────────────────────────────┐
        │                 uart_scoreboard                    │
        └────────────────────────────────────────────────────┘
                       │                         │
                       └──────────┬──────────────┘
                                  v
                    uart_coverage  +  uart_subscriber
```

**The checking is independent of the stimulus.** Neither monitor looks at its
driver:

* `uart_tx_monitor.req_ap` – the parallel transmit command (`tx_data` + the
  programmed format) sampled on the clock where `start` is accepted.
* `uart_tx_monitor.rsp_ap` – the frame independently decoded off the `tx` pin,
  including a recomputed parity bit and stop-bit check.
* `uart_rx_monitor.req_ap` – the frame decoded off the `rx` pin, **plus the
  error flags a correct receiver is required to report**. This is the reference
  model.
* `uart_rx_monitor.rsp_ap` – `rx_data` and the DUT's own error flags, sampled on
  `rx_valid`.

The scoreboard compares `req` against `rsp` in order, per direction. A broken
driver therefore cannot mask a broken DUT.

### Signal ownership

The DUT has a single shared format register bank, so exactly one component owns
each signal and TX/RX stimulus is always run **sequentially**, never in
parallel:

| Signal | Owner |
|---|---|
| `start`, `tx_data` | `uart_tx_driver` (via `drv_cb`) |
| `rx`, `rx_read` | `uart_rx_driver` (via `rx_drv_cb`) |
| `reset` | `uart_if::do_reset()` (tb_top at power-on, reset_sequence later) |
| `parity_en`, `parity_type`, `stop_bits`, `baud_div` | `uart_if::set_cfg()` |
| everything else | DUT outputs |

---

## 3. How to run

All commands are issued from `uart_uvm/sim/`.

### The raw QuestaSim command sequence

```tcl
vlib work
vmap work work

# RTL
vlog -sv -work work +cover=sbcef ../rtl/baud_generator.sv ../rtl/uart_tx.sv \
                                 ../rtl/uart_rx.sv ../rtl/uart_fifo.sv ../rtl/uart_top.sv

# interface must precede the package (the package declares "virtual uart_if")
vlog -sv -work work ../verification/tb/interface/uart_if.sv

# verification IP, then tests, then top level
vlog -sv -work work -L mtiUvm +incdir+<all tb subdirs> ../verification/tb/package/uart_pkg.sv
vlog -sv -work work -L mtiUvm +incdir+<all tb subdirs> ../verification/tb/tb_pkg.sv
vlog -sv -work work -L mtiUvm +incdir+<all tb subdirs> ../verification/tb/assertions/uart_assertions.sv \
                                                       ../verification/tb/tb_top.sv

# run
vsim -c -L mtiUvm -coverage -sv_seed 1 +UVM_TESTNAME=smoke_test work.tb_top
run -all
coverage save cov_smoke_test.ucdb
coverage report -detail -file cov_smoke_test.rpt
```

`compile.do` builds the `+incdir+` list for you and resolves the UVM kit.

### Scripted

```bash
vsim -c -do "do compile.do; quit -f"                          # compile only
vsim -c -do "set TEST rx_test; do run_questa.do; quit -f"     # compile + run
vsim -c -do "do regress.do; quit -f"                          # full regression
vsim -c -do "do coverage.do; quit -f"                         # merge + report
vsim    -do "set TEST break_test; set WAVES 1; do run_questa.do"   # GUI + waves
```

### Makefile / run.sh

```bash
make                          # compile + smoke test
make run TEST=parity_test     # one test
make gui TEST=break_test      # GUI with waves
make regress                  # everything + merged coverage
make report                   # merged coverage summary
make clean

./run.sh run rx_test
./run.sh regress
```

Variables: `TEST`, `SEED`, `VERB`, `WAVES`, `UVM_VER`.

---

## 4. Test list

| Test | What it proves |
|---|---|
| `smoke_test` | build acceptance: 5 clean frames each way |
| `reset_test` | async reset before/between/after live traffic; DUT parks legally and resumes |
| `tx_test` | corner data, all 8 frame formats, all 3 baud rates on the transmit path |
| `rx_test` | same sweep on the receive path |
| `random_test` | constrained-random both directions + back-to-back burst |
| `parity_test` | parity generation (TX) and parity checking + error injection (RX) |
| `framing_error_test` | stop bit driven low; DUT flags it and recovers |
| `break_test` | line low for a whole frame; break + framing + zero data; recovery |
| `overrun_test` | FIFO reader disabled; DUT must raise overrun and keep delivering data |
| `stress_test` | long random regression with mid-stream resets |

---

## 5. Coverage

`uart_coverage` samples both monitors' **observed** streams, so every bin comes
from real DUT activity.

* `cp_data` – 8 bins (0x00, 0xFF, 0xAA, 0x55 + four ranges)
* `cp_parity_en`, `cp_parity_type`, `cp_stop`, `cp_baud`, `cp_frame_len`
* `cp_dir`, `cp_err` (none / parity / framing / break / overrun)
* Crosses: `x_format`, `x_dir_baud`, `x_dir_data`, `x_dir_err`, `x_format_baud`

Unreachable corners are removed with `ignore_bins` (the TX agent drives the
parallel side and cannot inject a wire-level error), so **100% is attainable**.

Coverage must be **merged across the regression** — no single test can hit
BREAK *and* OVERRUN *and* framing errors *and* parity errors *and* all three
baud settings in both directions:

```bash
make regress          # runs everything and merges
# reports: cov_functional.rpt cov_assertions.rpt cov_code.rpt cov_summary.rpt
#          cov_html/index.html
```

### Coverage exclusions

`coverage_exclusions.do` holds the reviewed exclusion set, applied by `run.do`
before every run so all UCDBs carry the same exclusions. Every entry is code
that is **unreachable given how the block is integrated**, never missing
stimulus, and each carries a `-comment` explaining why:

* `baud_generator` `!enable` branch — `enable` is tied high by `uart_top`.
* `baud_generator` `baud_div < 2` clamp — defensive; SVA `a_baud_div_legal`
  proves the divider is always ≥ 2.
* the `default:` arm of the TX and RX frame FSMs — every state encoding has an
  explicit case arm, so the arm is dead code kept only as an SEU recovery path.

Nothing else is excluded. When the merged report first showed an uncovered FEC
row in the receiver's `framing_error = !stop1 || (two_stop && !stop2)` term, it
was closed with **new stimulus** (`framing_error_sequence::send_stop2_error()`,
which corrupts only the *second* stop bit), not with an exclusion.

---

## 6. Assertions (`uart_assertions.sv`)

Reset behaviour (live while reset is asserted), X/Z checks, transmit protocol
(idle high, start bit low, `busy`/`done` handshake, stop bit high, bounded frame
length), baud tick timing, receive protocol (`rx_valid` pulse, parity error only
with parity enabled, break implies framing error and zero data), and FIFO /
overrun rules. Ten `cover property` directives prove the interesting scenarios
were actually reached.

---

## 7. UVM version note

This environment targets **UVM 1.2**.

QuestaSim's *built-in* kit is UVM 1.1d. Selecting UVM 1.2 requires Questa to
build a small C wrapper for the one DPI **export** that UVM 1.2 contains
(`m__uvm_report_dpi` in `uvm_globals.svh`), which needs a **host C compiler**.
Without one, elaboration fails with:

```
** Fatal: (vsim-7019) Can't locate a C/C++ compiler for 'DPI Export Compilation'.
```

`compile.do` therefore resolves the kit as follows:

* `UVM_VER=1.2` – force UVM 1.2 (requires gcc)
* `UVM_VER=1.1d` – force the built-in kit
* `UVM_VER=auto` (default) – use 1.2 when a C compiler is on `PATH`, otherwise
  fall back to 1.1d with a clear warning

To enable UVM 1.2, install gcc and add to `modelsim.ini`:

```ini
DpiCppPath = <gcc-install>/bin/gcc
```

then run with `UVM_VER=1.2`.

The testbench source is written against UVM 1.2 but deliberately uses only APIs
that are present and non-deprecated in **both** kits (for example
`uvm_printer::print_generic` rather than the 1.2-only `print_field_int`), so the
identical source compiles and runs on either without modification.
