import wfdb
import numpy as np

record = wfdb.rdrecord('100', pn_dir='mitdb')
ecg_raw = record.p_signal[:1800, 0]  # 5 seconds at 360Hz

# Normalize
ecg = ecg_raw / np.max(np.abs(ecg_raw)) * 32767

# Stage 1: bandpass
def iir_lowpass(x):
    y = np.zeros(len(x))
    for n in range(len(x)):
        y[n] = (2*y[n-1] if n>=1 else 0) \
             - (y[n-2] if n>=2 else 0) \
             + x[n] \
             - (2*x[n-6] if n>=6 else 0) \
             + (x[n-12] if n>=12 else 0)
    return y / 32  # match Verilog >>5 scaling

def iir_highpass(x):
    y = np.zeros(len(x))
    for n in range(len(x)):
        y[n] = 32*(x[n-16] if n>=16 else 0) \
             - (y[n-1] if n>=1 else 0) \
             - x[n] \
             + (x[n-32] if n>=32 else 0)
    return y / 512  # match Verilog >>9 scaling

bp = iir_highpass(iir_lowpass(ecg))

# Stage 2: derivative
def derivative(x):
    y = np.zeros(len(x))
    for n in range(4, len(x)):
        y[n] = (2*x[n] + x[n-1] - x[n-3] - 2*x[n-4]) / 8
    return y

d = derivative(bp)

# Stage 3: squaring — match Verilog product[30:15]
# In Python: (x * x) >> 15, but values are already scaled floats
# Re-quantize to 16-bit first
d_q = np.clip(np.round(d), -32768, 32767).astype(int)
sq = ((d_q.astype(np.int64) * d_q.astype(np.int64)) >> 15).astype(int)
sq = np.clip(sq, 0, 65535)

# Stage 4: moving window integrator, N=54, divide by 64
def mwi(x, N=54):
    y = np.zeros(len(x))
    s = 0
    buf = np.zeros(N, dtype=np.int64)
    idx = 0
    for n in range(len(x)):
        s = s + x[n] - buf[idx]
        buf[idx] = x[n]
        idx = (idx + 1) % N
        y[n] = s >> 6
    return y

mwi_out = mwi(sq)
mwi_q = np.clip(np.round(mwi_out), 0, 65535).astype(int)

# Write MWI signal as testbench input
with open('mwi_signal.mem', 'w') as f:
    for v in mwi_q:
        f.write(f'{v & 0xFFFF:04x}\n')

# Get PhysioNet annotations (cardiologist-labeled beat locations)
annotation = wfdb.rdann('100', 'atr', pn_dir='mitdb')
beat_samples = annotation.sample[annotation.sample < 1800]

print(f"Beat locations in first 1800 samples: {beat_samples}")
print(f"MWI range: {mwi_q.min()} to {mwi_q.max()}")

# Write beat locations for reference
with open('beat_locations.txt', 'w') as f:
    for s in beat_samples:
        f.write(f'{s}\n')