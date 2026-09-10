```markdown
# Asynchronous FIFO with Clock Domain Crossing (CDC) - Engineering & Learning Summary

**Author:** Tan Kai Jian  
**Focus:** Digital IC Frontend Design / RTL Design / Metastability & CDC Synchronization  
**Target Role:** RTL / ASIC Design Engineer (Singapore IC Industry)  
**Deliverables:** Synthesizable Verilog RTL (`sync_2ff.v`, `fifo_mem.v`, `rptr_empty.v`, `wptr_full.v`, `async_fifo_top.v`), Self-Checking Testbench (`async_fifo_tb.v`), Simulation Waveforms (`async_fifo_tb.vcd`).

---

## 1. Project Overview & Motivation
In modern SoC architectures, different functional blocks operate on completely independent, unsynchronized clock frequencies (e.g., a 100 MHz write domain coupled with a 40 MHz read domain). Crossing data buses directly between asynchronous domains triggers severe physical timing violations:
* **Metastability:** Violating flip-flop setup/hold times causes non-deterministic intermediate voltage levels, collapsing downstream state machines.
* **Multi-bit Coherency & Skew Failure:** When multi-bit binary values transition simultaneously (e.g., $011 \rightarrow 100$), differing physical wire delays cause the receiving clock to sample corrupted intermediate values.

This project implements the industry-standard **Clifford E. Cummings Asynchronous FIFO architecture**, utilizing 2-Stage DFF synchronizers, Gray code pointers, and dual-domain look-ahead empty/full generation.

---

## 2. Microarchitecture & Module Decomposition

The subsystem is partitioned into five dedicated modules ensuring zero cross-domain logic leakage:


```

```
+-------------------------------------------------------+
|                   Dual-Port SRAM                      |
|                (Memory Array: DPRAM)                  |
+-------------------------------------------------------+
    ^ wdata / waddr                         ^ rdata / raddr
    |                                       |
[Write Domain: wclk]                   [Read Domain: rclk]

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

### Module Responsibilities:
1. **`sync_2ff.v` (Generic 2-Stage DFF Synchronizer):**
   * Eliminates metastability and drives system MTBF (Mean Time Between Failures) to hundreds of years.
   * Parameterized bus width (`WIDTH`) for synchronizing multi-bit Gray code pointers.
2. **`fifo_mem.v` (Dual-Port Memory Array):**
   * Synchronous write (`wclk`), combinational continuous read (`rclk`).
   * Gated write control (`winc && !wfull`) to ensure memory contents are never overwritten.
3. **`rptr_empty.v` (Read Pointer & Empty Logic):**
   * Tracks read binary address (`rbin`) and generates $(N+1)$-bit Gray pointer (`rptr`).
   * Evaluates `rempty` by comparing `rgraynext` with the synchronized write pointer (`rq2_wptr`).
4. **`wptr_full.v` (Write Pointer & Full Logic):**
   * Tracks write binary address (`wbin`) and generates $(N+1)$-bit Gray pointer (`wptr`).
   * Evaluates `wfull` by comparing `wgraynext` with the synchronized read pointer (`wq2_rptr`).
5. **`async_fifo_top.v` (Top-Level Interconnect):**
   * Fully parameterized integration propagating `DATASIZE` and `ADDRSIZE` to all sub-blocks.

---

## 3. Key Theoretical Insights & Interview Deep-Dives

### A. The Pointer Width Expansion ($(N+1)$-bit Pointer for $2^N$ Depth)
* **Problem:** If depth is $16$ ($2^4$), 4 bits can only index $0 \sim 15$. When `wptr == rptr`, it is mathematically ambiguous whether the FIFO is completely **Empty** or completely **Full** (wrapped around).
* **Solution:** Expand pointer width to $ADDRSIZE + 1$ (5 bits). The MSB acts as a "lap counter" (circle bit), while the lower 4 bits physically index the SRAM array.

### B. Binary-to-Gray Code Conversion & Single-Bit Toggle
* **Formula:**
  $$\text{Gray} = \text{Binary} \oplus (\text{Binary} \gg 1)$$
  In Verilog: `assign graynext = (binnext >> 1) ^ binnext;`
* **Why it works:** Gray code guarantees that **only 1 bit changes per increment**. Even if the receiving clock samples during a transition, the outcome is strictly either the old pointer or the new pointer—never an illegal intermediate multi-bit glitch.

### C. Gray Code Full Condition (The Mirror Property)
* For **Empty**: Both pointers are on the same lap and address $\rightarrow$ `rgraynext == rq2_wptr`.
* For **Full**: Write pointer has wrapped around exactly once. Due to the reflective symmetry of Gray codes, passing the halfway mark inverts the second MSB as well.
* **Universal Full Rule:** The highest 2 bits must be **inverted**, while all remaining lower bits are **identical**:
  ```verilog
  assign wfull_val = (wgraynext == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});

```

### D. Safe Pessimistic Design (保守/悲观设计原则)

* Because cross-domain pointer synchronization incurs a 2-cycle delay:
* **Write domain** sees a delayed `rptr`: It may believe the FIFO is full when it actually has freed space. This causes a minor, harmless stall—**never an overflow (Overrun)**.
* **Read domain** sees a delayed `wptr`: It may believe the FIFO is empty when new data has already arrived. This causes a minor read delay—**never an underflow (Underrun)**.



---

## 4. Hardware Debugging & Engineering Log (Real Issues & Fixes)

### 🐛 Bug 1: Top-Level Parameter Shadowing & Elaboration Warnings

* **Symptom:** Parameters were not explicitly overridden during sub-module instantiations, risking width mismatches when scaling depth.
* **Root Cause:** Relying on default parameters in leaf cells instead of propagating top-level generics.
* **Resolution:** Explicitly mapped parameter sets:
```verilog
fifo_mem #(.DATASIZE(DSIZE), .ADDRSIZE(ASIZE)) inst_fifo_mem (...);
wptr_full #(.ADDRSIZE(ASIZE)) inst_wptr_full (...);
rptr_empty #(.ADDRSIZE(ASIZE)) inst_rptr_empty (...);

```


### 🐛 Bug 2: Testbench Cross-Domain Clock Pollution

* **Symptom:** In `read_byte` task, the loop read hung or produced unstable strobe widths.
* **Root Cause:** Accidentally included `@(posedge wclk)` inside the read task! Mixing two asynchronous clocks within a single procedural task creates non-deterministic pulse timing.
* **Resolution:** Completely decoupled domain tasks: `write_byte` exclusively listens to `wclk`; `read_byte` exclusively listens to `rclk`.

### 🐛 Bug 3: Race Conditions & Sampling Same Address Repeatedly (`0xa0` Stuck Bug)

* **Symptom:** Self-checking checker reported:
`[PASS] Read: 0xa0` followed by 15 consecutive `[ERROR] Read: 0xa0, Expected: 0xa1 ~ 0xaf`.
* **Root Cause:** Asserting `rinc` and sampling `rdata` at the exact same clock edge before `rbin` had updated in the DUT, sampling the stale address 0 continuously.
* **Resolution (Negedge-Drive, Posedge-Sample Protocol):**
Refactored testbench to drive inputs on **negedge** and verify data on **posedge**. This provides half a clock cycle of setup margin and eliminates sampling race conditions:
```verilog
task read_byte;
    reg [DSIZE-1:0] sampled_data;
    begin
        @(negedge rclk);
        if (!rempty) begin
            rinc = 1'b1;
            sampled_data = rdata; // Latch stable continuous SRAM output
            @(posedge rclk);      // Address increments inside DUT
            // Validate sampled_data against golden queue
            @(negedge rclk);
            rinc = 1'b0;
        end
    end
endtask

```



---

## 5. Verification Results & Testbench Coverage

The self-checking verification environment (`async_fifo_tb.v`) ran against asymmetric asynchronous clocks:

* **Write Clock (`wclk`):** 100 MHz ($T = 10\text{ ns}$)
* **Read Clock (`rclk`):** 40 MHz ($T = 25\text{ ns}$)

### Scenarios Validated:

1. **Full-Capacity Burst Write:** Wrote 16 consecutive bytes (`0xA0` to `0xAF`). Full flag asserted precisely on the 16th byte.
2. **Overflow Guard Check:** Attempted write when `wfull == 1`. FIFO blocked the write and preserved internal contents.
3. **Burst Drain Read:** Read all 16 bytes across the 40 MHz boundary. Every single byte matched the golden software queue in exact FIFO order.
4. **Underflow Guard Check:** Attempted read when `rempty == 1`. Read request was safely suppressed.

```text
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

## 6. Synthesis & ASIC Physical Considerations (Next Steps)

* **`ASYNC_REG` Constraints:** In synthesis (Synopsys DC / Vivado), register pairs inside `sync_2ff` must be tagged with `ASYNC_REG = "TRUE"` to guarantee physical adjacency during Place & Route (PnR), maximizing resolution time $T_{res}$.
* **Static Timing Analysis (STA):** Set `set_max_delay` / `set_false_path` on cross-domain pointer paths to prevent STA tools from penalizing asynchronous skew while enforcing strict skew limits on Gray code buses.

```

---
