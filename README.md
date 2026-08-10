# ECG Cardiac Monitoring Engine — ASIC on SkyWater SKY130 130nm

## Description

A pipelined Pan-Tompkins QRS detection engine implemented in Verilog and hardened to a DRC-clean, LVS-clean GDS on SkyWater SKY130 130nm via OpenLane. It detects heartbeats in real time and extracts clinical features associated with cardiomyopathy, entirely in 
hardware, with no firmware, no microcontroller, and no cloud dependency.

- [Read the documentation](docs/info.md)

## What it does

The purpose of this project was to target cardiomyopathy. One of the challenges with the disease is that it's often caught late. The electrical signatures show up on an ECG, but continuous monitoring isn't something most people have access to outside a hospital setting.

The design implements the Pan-Tompkins QRS detection algorithm as a five-stage pipelined RTL datapath. It detects heartbeats (QRS complexes) from a raw ECG signal, and on each detected beat, computes a set of features relevant to cardiomyopathy screening.

## Output flags

beat_detected — one-cycle pulse per QRS complex
wide_qrs — QRS duration > 120ms (43 samples at 360Hz)
tachy_flag — heart rate > 100 BPM
brady_flag — heart rate < 60 BPM
low_hrv — HRV MAD below threshold
anomaly_flag — any cardiomyopathy flag asserted


## Notes

- The IIR highpass filter has a gain of 386×. After the lowpass stage, 
the values grow large enough that dividing by the same scale factor 
used in hardware collapses the signal to zero before squaring. 
The Python and Verilog scaling strategies had to be different. Python keeps the full float 
range, but Verilog uses bit-shifts sized for registers.

- Gate-level simulation required flushing the pipeline with dummy data after 
reset to clear trapped X values in certain shift registers that don't respond to asynchronous reset the same way RTL simulation does.