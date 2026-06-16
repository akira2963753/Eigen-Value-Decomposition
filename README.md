# Eigen-Value Decomposition (EVD) Hardware

A VLSI implementation of **Eigen-Value Decomposition for 3×3 symmetric matrices**,
using the iterative QR algorithm (Givens rotations) computed by CORDIC processing
elements arranged as a systolic array, synthesized on TSMC 16nm.

> NTU "DSP in VLSI" (ICDA5003), 2026 Spring — Final Project.

## Algorithm

Given symmetric matrix $\mathbf{A} \in \mathbb{R}^{N \times N}$ (this project: $N = 3$):

$$
\begin{aligned}
&\text{// First phase} \\
&[\mathbf{U}_{\mathrm{EVD}}^{(0)}, \mathbf{A}^{(0)}] = \mathrm{HessenbergReduction}(\mathbf{A}) \\[4pt]
&\text{// Second phase, } i = 0 \\
&\textbf{while } (\neg\text{converged}) \\
&\quad \mathbf{T}^{(i)} = \mathbf{A}^{(i)} - \mu_i \mathbf{I} \\
&\quad [\mathbf{Q}^{(i)}, \mathbf{R}^{(i)}] = \mathrm{QRD}(\mathbf{T}^{(i)}) \\
&\quad \mathbf{T}^{(i+1)} = \mathbf{R}^{(i)} \mathbf{Q}^{(i)} \\
&\quad \mathbf{A}^{(i+1)} = \mathbf{T}^{(i+1)} + \mu_i \mathbf{I} \\
&\quad \mathbf{U}_{\mathrm{EVD}}^{(i+1)} = \mathbf{U}_{\mathrm{EVD}}^{(i)} \mathbf{Q}^{(i)} \\
&\quad i = i + 1 \\
&\textbf{End}
\end{aligned}
$$

This design skips Hessenberg reduction ($\mathbf{A}^{(0)} = \mathbf{A}$,
$\mathbf{U}_{\mathrm{EVD}}^{(0)} = \mathbf{I}$) and runs a fixed 7 iterations
without shift ($\mu_i = 0$). Each $\mathrm{QRD}(\cdot)$ is realized by Givens
rotations in a triangular CORDIC systolic array; vectoring mode records rotation
directions and rotation mode replays them (angle-free CORDIC, no arctan ROM).

## Architecture

| Module | File | Role |
|--------|------|------|
| `EVD` | [src/01_RTL/EVD.sv](src/01_RTL/EVD.sv) | Top module. 3-state FSM (IDLE / PROCESS / OUT), iteration and I/O control. |
| `QRD` | [src/01_RTL/QRD.sv](src/01_RTL/QRD.sv) | QR decomposition systolic array (3 CORDIC PEs + delay units). |
| `CORDIC_PE` | [src/01_RTL/CORDIC_PE.sv](src/01_RTL/CORDIC_PE.sv) | CORDIC processing element (Vectoring / Rotation modes, 8 stages). |

## Specifications

| Item | Value |
|------|-------|
| Matrix size | 3×3 symmetric |
| Data format | 17-bit signed (1 sign / 5 integer / 11 fraction) |
| QR iterations | 7 |
| CORDIC stages | 8 (2 pipeline stages) |
| Total latency | 112 cycles |
| Best synthesis | ~0.92 ns clock, ~5078 µm² (TSMC 16nm) |

## I/O Interface

| Signal | Dir | Description |
|--------|-----|-------------|
| `clk`, `rst_n` | in | Clock and active-low reset |
| `InValid` | in | Asserted while input is fed |
| `InData[0:2]` | in | 17-bit signed; matrix loaded column-by-column over 3 cycles |
| `OutData[0:2]` | out | Eigenvalues / eigenvector columns |
| `OutValid` | out | Asserted while output is valid |

## Repository Structure

```
src/
├── 00_TESTBED/    # Testbench + golden test data (.dat)
├── 01_RTL/        # RTL sources: EVD.sv, QRD.sv, CORDIC_PE.sv, define.vh
├── 02_SYN/        # Synthesis (Design Compiler, syn16.tcl)
└── 03_GATESIM/    # Gate-level simulation
report/            # LaTeX technical report + figures
spec/              # Project specification (PDF)
```

## How to Run

```bash
# 1. RTL simulation
cd src/01_RTL && ./01_run        # vcs -full64 -debug_access+all -R +v2k -f file.f

# 2. Logic synthesis (TSMC 16nm)
cd src/02_SYN && ./02_run        # dc_shell -f syn16.tcl | tee syn.log

# 3. Gate-level simulation
cd src/03_GATESIM && ./03_run    # vcs ... +define+GATE_SIM
```

## Tools

SystemVerilog · Synopsys VCS + Verdi · Synopsys Design Compiler