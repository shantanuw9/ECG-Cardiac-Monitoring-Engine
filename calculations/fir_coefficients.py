from scipy.signal import firwin
import numpy as np

taps = firwin(33, 11.0, fs=360.0, window='hamming')
coeffs_int = np.round(taps * 32768).astype(int)
print(f"Low pass: {coeffs_int}")
taps2 = firwin(33, 5.0, fs=360.0, window='hamming', pass_zero=False)
coeffs_int2 = np.round(taps2 * 32768).astype(int)
print(f"High pass: {coeffs_int2}")