import wfdb
import numpy as np
import matplotlib.pyplot as plt

record = wfdb.rdrecord('100', pn_dir='mitdb')
ecg = record.p_signal[:1000, 0]  # first 1000 samples

def iir_lowpass(x):
    y = np.zeros(len(x))
    xd = np.zeros(13)
    for n in range(len(x)):
        xd = np.roll(xd, 1); xd[0] = x[n]
        y[n] = (2*y[n-1] if n>=1 else 0) \
             - (y[n-2] if n>=2 else 0) \
             + x[n] \
             - (2*xd[6] if n>=6 else 0) \
             + (xd[12] if n>=12 else 0)
    return y

def iir_highpass(x):
    y = np.zeros(len(x))
    xd = np.zeros(33)
    for n in range(len(x)):
        xd = np.roll(xd, 1); xd[0] = x[n]
        y[n] = 32*(xd[16] if n>=16 else 0) \
             - (y[n-1] if n>=1 else 0) \
             - x[n] \
             + (xd[32] if n>=32 else 0)
    return y

lp = iir_lowpass(ecg)
bp = iir_highpass(lp)

plt.figure(figsize=(12, 4))
plt.plot(ecg[:500], label='raw', alpha=0.5)
plt.plot(bp[:500], label='bandpass', alpha=0.8)
plt.legend()
plt.show()

lp = iir_lowpass(ecg)
bp = iir_highpass(lp)
print(f"LP max: {np.max(np.abs(lp)):.1f}")
print(f"BP max: {np.max(np.abs(bp)):.1f}")
print(f"Input max: {np.max(np.abs(ecg)):.1f}")