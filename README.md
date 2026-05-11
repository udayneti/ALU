# Parameterized Pipelined ALU Design & Verification

![Language](https://img.shields.io/badge/Language-Verilog-blue.svg)
![Architecture](https://img.shields.io/badge/Architecture-Pipelined-brightgreen.svg)
![Verification](https://img.shields.io/badge/Verification-File--Driven_Scoreboard-orange.svg)

This repository contains the RTL design and an advanced verification environment for a parameterized, fully pipelined Arithmetic Logic Unit (ALU). The ALU is designed to handle both signed/unsigned arithmetic and a full suite of logical/shift operations with a dynamic latency architecture.

## 📂 Repository Structure

```text
ALU/
├── README.md                 # Project overview and instructions
├── docs/
│   ├── test_plan.md          # Detailed test matrix and feature coverage
│   └── verification_report.md# Final simulation results and coverage metrics
└── src/
    ├── design/
    │   └── alu.v             # ALU RTL Design (Verilog)
    └── test_bench/
        └── alu_tb.v          # Pipelined Scoreboard Testbench
```
