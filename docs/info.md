## How it works

This chip implements the Pan-Tompkins QRS detection algorithm as a five-stage hardware pipeline: an IIR bandpass filter removes baseline wander and noise, a derivative filter emphasizes QRS slopes, a squaring unit amplifies peaks, a moving window integrator smooths the signal into one broad hump per heartbeat, and an adaptive threshold FSM detects beats and enforces a 200ms refractory period to prevent double-counting.

On each detected beat, the chip computes QRS width, heart rate, RR interval, and a 32-beat HRV estimate in hardware. These feed into flag logic that asserts `wide_qrs`, `tachy_flag`, `brady_flag`, `low_hrv`, and `anomaly_flag` — the electrical signatures associated with cardiomyopathy. A 96-bit feature vector with a synchronized valid strobe is output per beat as an interface for a planned hardware neural network inference engine.

## How to test

Apply a normalized 16-bit signed ECG sample on `ecg_sample` and pulse `sample_valid` high for one cycle per sample at 360Hz. After reset, the pipeline warms up over the first few beats as the adaptive threshold estimators initialize.

Monitor `beat_detected` for one-cycle pulses on each QRS complex. Cardiomyopathy flags (`wide_qrs`, `low_hrv`, `tachy_flag`, `brady_flag`) update on each beat. `anomaly_flag` asserts if any clinical threshold is crossed.

To verify detection accuracy, use the Python validation script in `calculations/validate_pipeline.py` which runs the full pipeline against PhysioNet MIT-BIH records and reports sensitivity and precision against cardiologist annotations. Record 100 achieves 99.8% sensitivity and precision. Overall across five benchmark records: 88.6% sensitivity.

## External hardware

No external hardware required. For integration with a real ECG front-end, connect the ADC output (normalized to Q1.15 signed 16-bit) to `ecg_sample` and drive `sample_valid` at 360Hz from a timer interrupt or DMA transfer-complete signal.