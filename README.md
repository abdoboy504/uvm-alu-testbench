# UVM testbench for a simple ALU

A UVM testbench I built from scratch while learning design verification. It verifies a small ALU (ADD, SUB, AND, XOR) with a one-cycle latency. A run sends 100 random transactions, and the scoreboard checks each result against a reference model.

## Architecture



| Component | Class | Role |
|---|---|---|
| Transaction | `alu_item` | `a`, `b`, `op` (random) and `result` |
| Sequence | `alu_random_seq` | Sends 100 random items |
| Driver | `alu_driver` | Drives the DUT pins through a clocking block |
| Monitor | `alu_monitor` | Pairs inputs with the result one cycle later, broadcasts via an analysis port |
| Scoreboard | `alu_scoreboard` | Computes the expected result, counts pass and fail |
| Agent / Env / Test | `alu_agent`, `alu_env`, `alu_test` | Structure and test control |

## DUT

`alu`: 8-bit operands `a` and `b`, 2-bit `op` (0 = ADD, 1 = SUB, 2 = AND, 3 = XOR), a `valid_in`/`valid_out` handshake, and a 9-bit `result` that keeps the carry. The result appears one clock cycle after the inputs.

## How to run

1. Open [EDA Playground](https://www.edaplayground.com).
2. Select **UVM 1.2** and **Questa**.
3. Paste `alu.sv` into the design tab and `alu_uvm_verification.sv` into the testbench tab.
4. Untick "Use run.do Tcl file" and click **Run**.

## Result


`PASS: 100  FAIL: 0`, with 0 UVM errors and 0 fatals.

## What I learned

- The run phase must start at time 0, so reset has to live in a separate `initial` block from `run_test()`. A delay before `run_test()` causes a `RUNPHSTIME` fatal.
- With a one-cycle latency, inputs and result never appear on the same edge, so the monitor stores the inputs and pairs them with the result on the next edge.
- Clocking blocks remove the race between the testbench and the DUT at the clock edge.

## Next steps

- Functional coverage
- Constrained-random sequences
- A reset-aware driver
- A more complex DUT