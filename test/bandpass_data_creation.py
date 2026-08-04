import wfdb
import numpy as np

# Download record 100 from PhysioNet (requires internet, ~2MB)
record = wfdb.rdrecord('100', pn_dir='mitdb')
ecg_raw = record.p_signal[:500, 0]  # first 500 samples, channel 0

# Normalize to Q1.15 range
ecg_norm = ecg_raw / np.max(np.abs(ecg_raw))
ecg_q15 = np.round(ecg_norm * 32767).astype(int)

# Write input
with open('ecg_input.mem', 'w') as f:
    for v in ecg_q15:
        f.write(f'{v & 0xFFFF:04x}\n')

# Compute expected bandpass output using Python reference implementation
def iir_lowpass(x):
    y = np.zeros(len(x))
    for n in range(len(x)):
        y[n] = (2*y[n-1] if n>=1 else 0) \
             - (y[n-2] if n>=2 else 0) \
             + x[n] \
             - (2*x[n-6] if n>=6 else 0) \
             + (x[n-12] if n>=12 else 0)
    return y

def iir_highpass(x):
    y = np.zeros(len(x))
    for n in range(len(x)):
        y[n] = 32*(x[n-16] if n>=16 else 0) \
             - (y[n-1] if n>=1 else 0) \
             - x[n] \
             + (x[n-32] if n>=32 else 0)
    return y

lp = iir_lowpass(ecg_q15.astype(float))
bp = iir_highpass(lp)

# Apply same scaling as Verilog: LP>>5 then HP>>9
lp_scaled = (lp / 32).astype(int)
bp_scaled = (bp / 512).astype(int)

with open('bp_expected.mem', 'w') as f:
    for v in bp_scaled:
        f.write(f'{v & 0xFFFF:04x}\n')

print(f"Input range: {ecg_q15.min()} to {ecg_q15.max()}")
print(f"BP output range: {bp_scaled.min()} to {bp_scaled.max()}")