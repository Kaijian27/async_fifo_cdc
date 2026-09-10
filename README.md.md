```markdown
# Parameterized Asynchronous FIFO with Clock Domain Crossing (CDC)

[![Verilog](https://img.shields.io/badge/Language-Verilog--2001-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Simulator](https://img.shields.io/badge/Simulator-Icarus%20Verilog%20%2F%20GTKWave-green.svg)](http://iverilog.icarus.com/)
[![Verification](https://img.shields.io/badge/Verification-Self--Checking%20Testbench-orange.svg)]()
[![Target Role](https://img.shields.io/badge/Focus-Digital%20IC%20%2F%20RTL%20Design-purple.svg)]()

A synthesizable, fully parameterized Asynchronous FIFO (First-In, First-Out) queue implemented in Verilog-2001, adhering strictly to the **Clifford E. Cummings** dual-clock architecture. 

Designed for robust Clock Domain Crossing (CDC) systems, this IP eliminates metastability, avoids multi-bit coherence failures via Gray-coded pointers, and features safe look-ahead pessimistic Empty/Full flag generation.

---

## 🏗️ System Architecture & Data Path

The design partitions logic strictly between the **Write Domain (`wclk`)** and **Read Domain (`rclk`)** to prevent cross-domain timing leakage:


```

```
+-------------------------------------------------------+
|                   Dual-Port SRAM                      |
|                (Memory Array: DPRAM)                  |
+-------------------------------------------------------+
  ^ wdata / waddr                         ^ rdata / raddr
  |                                       |
[Write Domain: wclk]                    [Read Domain: rclk]

```

+-----------------------+                            +-----------------------+
|  wptr_full Module     |                            |  rptr_empty Module    |
|  - Binary & Gray Wptr |                            |  - Binary & Gray Rptr |
|  - Full Flag Gen      |                            |  - Empty Flag Gen     |
+-----------------------+                            +-----------------------+
| Gray wptr                                          | Gray rptr
| (Single-bit toggling)                              | (Single-bit toggling)
v                                                    v
+-----------------------+                            +-----------------------+
|  2-Stage Synchronizer |                            |  2-Stage Synchronizer |
|  (sync_w2r in rclk)   |                            |  (sync_r2w in wclk)   |
+-----------------------+                            +-----------------------+
|                                                    |
+---- Synchronized Gray wptr ----> Empty Logic       |
|
Synchronized Gray rptr ----> Full Logic <------+

```

---

## ⚡ Key Engineering & CDC Principles

### 1. Dual-Stage DFF Synchronizer (`sync_2ff.v`)
* **Metastability Mitigation:** Cascades two back-to-back D-Flip-Flops to allow unresolvable intermediate signal states adequate settling time ($T_{res}$), elevating system Mean Time Between Failures (MTBF) by orders of magnitude.
* **Bus Protection Constraint:** Dedicated strictly to single-bit toggling signals (Gray-coded buses); raw multi-bit binary buses are strictly prohibited to prevent routing-skew induced corruption.

### 2. Binary-to-Gray Pointer Encoding
* **Single-Bit Toggle Property:** Utilizes $\text{Gray} = \text{Binary} \oplus (\text{Binary} \gg 1)$ to guarantee that exactly one bit transitions per pointer increment.
* **Coherency Preservation:** Eliminates race conditions during CDC sampling. If an asynchronous clock edge collides with a pointer transition, the sampled result is reliably either the stale or updated value, never an erroneous intermediate artifact.

### 3. Pointer Expansion & Reflection-Based Full Detection
* **$(N+1)$-Bit Counter for $2^N$ Depth:** Distinguishes full vs. empty states when lower physical RAM address bits match.
* **Mirror Property Full Flag Logic:** Due to Gray code reflective symmetry, entering the second wrap-around lap inverts both the MSB and the second-MSB.
  $$\text{Full Condition: } \mathbf{wgraynext} == \{\sim\mathbf{wq2\_rptr}[A:A-1], \mathbf{wq2\_rptr}[A-2:0]\}$$

### 4. Conservative (Pessimistic) Status Generation
* **Overrun / Underrun Prevention:** Synchronized comparison pointers introduce a 2-cycle latency. The write domain sees a delayed read pointer (pessimistic full) and the read domain sees a delayed write pointer (pessimistic empty). This guarantees functional safety: stalls may occur, but data overwrite or underflow read is mathematically impossible.

---

## 📁 Repository Structure

```text
async_fifo_cdc/
├── rtl/
│   ├── sync_2ff.v                 # Generic 2-stage DFF synchronizer
│   ├── fifo_mem.v                 # Dual-port SRAM / register array
│   ├── rptr_empty.v               # Read pointer tracking & rempty generation
│   ├── wptr_full.v                # Write pointer tracking & wfull generation
│   └── async_fifo_top.v           # Top-level parameterized structural integration
├── tb/
│   └── async_fifo_tb.v            # Self-checking testbench with asymmetric clocks
├── sm/
│   └── async_fifo_sim           # Simulation file
├── async_fifo_learning_summary.md # Deep-dive technical & debugging summary
└── README.md                      # Project documentation

```

---

## ⚙️ Generics & Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `DSIZE` | `8` | Word width of write and read data buses (`wdata`, `rdata`). |
| `ASIZE` | `4` | Address bus bit-width. Memory depth scales to $2^{\text{ASIZE}}$ (Default: 16 entries). |

---

## 🔬 Verification & Test Scenarios

The design is verified via a self-checking testbench (`async_fifo_tb.v`) operating under asymmetric, non-integer-multiple clock domains:

* **Write Clock (`wclk`):** 100 MHz ($T = 10\text{ ns}$)
* **Read Clock (`rclk`):** 40 MHz ($T = 25\text{ ns}$)

### Stimulus Profile:

1. **Full Capacity Burst Write:** 16 consecutive writes (`0xA0` to `0xAF`). Full flag asserts on the 16th transaction.
2. **Overflow Guard Check:** Unlawful write attempted while `wfull == 1`. Verified that the write was blocked and memory contents remained uncorrupted.
3. **Burst Drain Read:** 16 consecutive reads across the 40 MHz domain. Verified byte-for-byte correctness against a Golden Queue in strict FIFO order.
4. **Underflow Guard Check:** Unlawful read attempted while `rempty == 1`. Verified that read was safely suppressed.

### Simulation Output:

```text
VCD info: dumpfile async_fifo_tb.vcd opened for output.
--------------------------------------------------
[TEST START] Starting Asynchronous FIFO Verification
--------------------------------------------------

--- Test 1: Writing 16 bytes to fill FIFO ---
[WRITE] Data = 0xa0 ... 0xaf

--- Test 2: Writing to FULL FIFO (Overflow check) ---
[WARNING] FIFO is FULL! Cannot write data: 0xff

--- Test 3: Reading 16 bytes until empty ---
[PASS] Successfully read: 0xa0 ... 0xaf

--- Test 4: Reading from EMPTY FIFO (Underflow check) ---
[WARNING] FIFO is EMPTY! Cannot read data.
--------------------------------------------------
[TEST PASSED] All data matched! No CDC data loss.
--------------------------------------------------

```

---

## 🚀 How to Compile & Run

Prerequisites: Ensure `iverilog` and `vvp` are installed.

```bash
# Clone repository
git clone [https://github.com/Kaijian27/async-fifo-cdc.git](https://github.com/Kaijian27/async-fifo-cdc.git)
cd async-fifo-cdc

# Compile using Icarus Verilog
iverilog -o async_fifo_sim rtl/*.v tb/async_fifo_tb.v

# Run the simulation executable
vvp async_fifo_sim

# (Optional) Open waveform in GTKWave
gtkwave async_fifo_tb.vcd &

```

---

## 👨‍💻 Author

**Tan Kai Jian**

*Undergraduate in Electrical & Electronics Engineering, Universiti Putra Malaysia*

*Aspiring Digital IC / RTL Design Engineer (Singapore)*

*GitHub:* [@Kaijian27](https://www.google.com/search?q=https://github.com/Kaijian27)

```

```