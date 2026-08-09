# Run this once to create ecg_input_100.mem
import wfdb
import numpy as np

record = wfdb.rdrecord('100', pn_dir='mitdb')
ecg_raw = record.p_signal[:1800, 0]
ecg_norm = np.clip(ecg_raw / np.max(np.abs(ecg_raw)) * 32767,
                   -32768, 32767).astype(int)

with open('test/ecg_input_100.mem', 'w') as f:
    for v in ecg_norm:
        f.write(f'{v & 0xFFFF:04x}\n')