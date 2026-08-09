# ECG Cardiac Monitoring Engine — ASIC on SkyWater SKY130 130nm

- [Read the documentation for project](docs/info.md)

## Description

A pipelined Pan-Tompkins QRS detection engine implemented in Verilog and hardened to a DRC-clean, LVS-clean GDS on SkyWater SKY130 130nm via OpenLane. The design detects heartbeats and extracts cardiomyopathy-relevant clinical features in hardware with deterministic latency and no firmware overhead.

