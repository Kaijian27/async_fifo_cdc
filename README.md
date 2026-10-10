# Parameterized Asynchronous FIFO (Verilog RTL)

A dual-clock asynchronous FIFO implemented in Verilog-2001. The design uses local binary pointers for memory addressing, Gray-coded pointers for clock-domain crossing (CDC), two-flip-flop pointer synchronizers, and registered FULL/EMPTY flags.

> **CDC note:** Gray coding limits a pointer increment to one changed bit, and two-stage synchronization reduces the probability of metastability propagating into destination logic. Neither technique eliminates metastability. A physical implementation must also constrain inter-bit Gray-bus skew and review reset crossing and target memory inference.

## Architecture

```text
Producer (wclk)                           Consumer (rclk)
    winc, wdata                               rinc, rdata
         |                                         ^
         v                                         |
  +----------------+                      +----------------+
  | wptr_full      |-- waddr --+  +-- raddr| rptr_empty     |
  | binary/Gray    |           |  |       | binary/Gray    |
  | FULL detect    |           v  v       | EMPTY detect   |
  +----------------+       +----------+   +----------------+
         | wptr            | fifo_mem |            | rptr
         |                 +----------+            |
         v                                         v
  sync_2ff (rclk)                          sync_2ff (wclk)
         | rq2_wptr                               | wq2_rptr
         +--> read EMPTY logic                     +--> write FULL logic
```

The memory has a **synchronous write** and an **asynchronous (combinational) read**. `rdata` is the word addressed by the current `raddr`; consumers must use it only on an accepted read (`rinc && !rempty` at `posedge rclk`). A blocked read does not advance the pointer, but `rdata` itself is not gated or automatically cleared.

## Parameters

| Parameter | Default | Meaning |
| --- | --- | --- |
| `DSIZE` | 8 | Bits per data word |
| `ASIZE` | 4 | Memory address bits; depth is `2**ASIZE` (16 default) |

The binary and Gray pointers have `ASIZE+1` bits, with an extra wrap bit. The Gray-code FULL comparison inverts the two most significant bits of the synchronized read pointer; EMPTY compares the next read Gray pointer with the synchronized write pointer. The implementation assumes `ASIZE >= 2`.

## Interface

- **Write accepted:** `winc && !wfull` on a rising edge of `wclk`.
- **Read accepted:** `rinc && !rempty` on a rising edge of `rclk`.
- A rejected transaction is **not queued for automatic retry**. The producer or consumer must manage its own request/ready protocol.
- FULL/EMPTY assertion uses local next-pointer logic; deassertion due to activity in the other domain is conservatively delayed by pointer synchronization.
- The two reset inputs should be asserted together for initialization. Stored RAM contents are not cleared; they are invalid after reset. Independent reset assertion/release during live traffic has not been characterized by this testbench.

## Repository layout

```text
async-fifo-cdc/
├── rtl/
│   ├── async_fifo_top.v
│   ├── fifo_mem.v
│   ├── wptr_full.v
│   ├── rptr_empty.v
│   └── sync_2ff.v
├── tb/
│   └── async_fifo_tb.v
├── .gitignore
└── README.md
```

## Verification

The FIFO is verified using a self-checking Verilog testbench with two independent clock frequencies:

- Write clock: 100 MHz
- Read clock: 40 MHz

The testbench covers four scenarios:

1. **FIFO Full Test:** Write 16 bytes (`0xA0`–`0xAF`) and verify that the FULL flag is asserted.
2. **Overflow Protection:** Attempt an additional write while FULL and verify that the write pointer does not advance.
3. **FIFO Empty Test:** Read all 16 bytes, compare the received data against the expected sequence, and verify that the EMPTY flag is asserted.
4. **Underflow Protection:** Attempt an additional read while EMPTY and verify that the read pointer does not advance.

The testbench checks FIFO data ordering and basic FULL/EMPTY protection. More advanced scenarios, such as continuous concurrent read/write operations, multiple wraparounds, and reset during active operation, are not currently covered.

### Run with Icarus Verilog

```bash
iverilog -g2012 -s async_fifo_tb -o fifo_sim rtl/*.v tb/async_fifo_tb.v
vvp fifo_sim
# Optional waveform viewer:
gtkwave async_fifo_tb.vcd
```

The testbench uses Verilog-compatible RTL and common simulation constructs; `-g2012` enables broad simulator compatibility. The simulation prints `[TEST PASSED]` only when its internal error counter remains zero. **The directed simulation completed successfully using Icarus Verilog, with all four test scenarios passing.**

## Author and project scope

Student RTL/CDC learning and portfolio project. The design is intended as a demonstrator, not a silicon-qualified FIFO IP block.

This project was developed with AI assistance for RTL implementation and debugging. I reviewed the design architecture, studied the FIFO pointer and CDC logic, and performed functional verification using an Icarus Verilog testbench.

The project is intended for learning and demonstrating fundamental RTL design and clock-domain crossing concepts.
