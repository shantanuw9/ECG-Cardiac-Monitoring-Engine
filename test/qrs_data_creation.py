import wfdb
import numpy as np

record = wfdb.rdrecord('100', pn_dir='mitdb')
ecg_raw = record.p_signal[:1800, 0]

ecg = ecg_raw / np.max(np.abs(ecg_raw)) * 32767

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

lp = iir_lowpass(ecg)
bp = iir_highpass(lp)

# Renormalize to 16-bit range
bp_norm = np.clip(bp / np.max(np.abs(bp)) * 32767, -32768, 32767)

def derivative(x):
    y = np.zeros(len(x))
    for n in range(4, len(x)):
        y[n] = (2*x[n] + x[n-1] - x[n-3] - 2*x[n-4]) / 8
    return y

d = derivative(bp_norm)
d_q = np.clip(np.round(d), -32768, 32767).astype(np.int64)
print(f"Derivative range: {d_q.min()} to {d_q.max()}")
print(f"Derivative samples > 1000: {np.sum(np.abs(d_q) > 1000)}")

# Square WITHOUT >> 15 — keep full precision in Python
sq_full = (d_q * d_q).astype(np.int64)
print(f"Squared full range: {sq_full.min()} to {sq_full.max()}")

# Scale squared output to 16-bit range for MWI
sq_max = sq_full.max()
if sq_max > 0:
    sq_16 = np.clip((sq_full * 65535) // sq_max, 0, 65535).astype(np.int64)
else:
    sq_16 = sq_full.astype(np.int64)
print(f"Squared 16-bit range: {sq_16.min()} to {sq_16.max()}")

def mwi(x, N=54):
    y = np.zeros(len(x), dtype=np.int64)
    s = np.int64(0)
    buf = np.zeros(N, dtype=np.int64)
    idx = 0
    for n in range(len(x)):
        s = s + x[n] - buf[idx]
        buf[idx] = x[n]
        idx = (idx + 1) % N
        y[n] = s >> 6
    return y

mwi_out = mwi(sq_16)
print(f"MWI range: {mwi_out.min()} to {mwi_out.max()}")

mwi_q = np.clip(mwi_out, 0, 65535).astype(int)

with open('mwi_signal.mem', 'w') as f:
    for v in mwi_q:
        f.write(f'{v & 0xFFFF:04x}\n')

annotation = wfdb.rdann('100', 'atr', pn_dir='mitdb')
beat_samples = annotation.sample[annotation.sample < 1800]
print(f"Beat locations: {beat_samples}")
print(f"Expected ~{len(beat_samples)} beats")

with open('beat_locations.txt', 'w') as f:
    for s in beat_samples:
        f.write(f'{s}\n')

# Plot to visually verify peaks align with annotations
import matplotlib.pyplot as plt
plt.figure(figsize=(14, 4))
plt.plot(mwi_q, label='MWI output')
for s in beat_samples:
    plt.axvline(x=s, color='r', alpha=0.5, linewidth=0.8)
plt.title('MWI signal with beat annotations (red lines)')
plt.xlabel('Sample')
plt.ylabel('Amplitude')
plt.legend()
plt.tight_layout()
plt.savefig('mwi_plot.png', dpi=150)
plt.show()
print("Plot saved to mwi_plot.png")