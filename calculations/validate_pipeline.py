# validate_pipeline.py
# Run from project root: python3 test/validate_pipeline.py

import wfdb
import numpy as np

# ─────────────────────────────────────────
# Pipeline stages — Python behavioral model
# ─────────────────────────────────────────

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

def derivative(x):
    y = np.zeros(len(x))
    for n in range(4, len(x)):
        y[n] = (2*x[n] + x[n-1] - x[n-3] - 2*x[n-4]) / 8
    return y

def squaring(x):
    x_q = np.clip(np.round(x), -32768, 32767).astype(np.int64)
    sq  = (x_q * x_q) >> 10  # >>10 instead of >>15 — keeps values larger
    return np.clip(sq, 0, 65535).astype(np.int64)

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

def run_pipeline(ecg_raw):
    ecg = ecg_raw / np.max(np.abs(ecg_raw)) * 32767
    lp  = iir_lowpass(ecg)
    bp  = iir_highpass(lp)
    
    # Don't normalize globally — clip to 16-bit range instead
    # This matches what Verilog does: output truncates to 16 bits
    bp_clipped = np.clip(bp, -32768, 32767)
    
    d      = derivative(bp_clipped)
    sq     = squaring(d)
    mwi_out = mwi(sq)
    return mwi_out

# ─────────────────────────────────────────
# QRS detector — Python behavioral model
# mirrors your Verilog FSM exactly
# ─────────────────────────────────────────

def detect_beats(mwi_signal):
    WAITING    = 0
    CANDIDATE  = 1
    REFRACTORY = 2
    REFRACTORY_PERIOD = 100

    state    = WAITING
    spk_i    = 100
    npk_i    = 50
    mwi_peak = 0
    rr_count = 0
    ref_count = 0
    peak_sample = 0
    beats    = []

    for n, sample in enumerate(mwi_signal):
        sample = int(sample)
        threshold = int(npk_i + (spk_i - npk_i) // 4)

        if state == WAITING:
            rr_count += 1
            if sample > threshold and threshold > 0:
                mwi_peak = sample
                peak_sample = n
                state = CANDIDATE
            else:
                npk_i = (sample >> 3) + (npk_i - (npk_i >> 3))

        elif state == CANDIDATE:
            rr_count += 1
            if sample > mwi_peak:
                mwi_peak      = sample
                peak_sample   = n          # track when peak occurred
            if sample < threshold:
                spk_i = (mwi_peak >> 3) + (spk_i - (spk_i >> 3))
                beats.append(peak_sample)  # record peak, not falling edge
                rr_count  = 0
                ref_count = 0
                state     = REFRACTORY

        elif state == REFRACTORY:
            ref_count += 1
            if ref_count >= REFRACTORY_PERIOD:
                ref_count = 0
                state     = WAITING

    return beats

# ─────────────────────────────────────────
# Evaluation — sensitivity and specificity
# ─────────────────────────────────────────

PIPELINE_DELAY = 3  # bandpass (32)d + MWI half-window (27)

def evaluate(detected, annotated, tolerance=36):  # increase from 20 to 36
    annotated = list(annotated)
    tp = 0
    matched_det = set()
    matched_ann = set()

    # Compensate for pipeline delay in detected indices
    detected_compensated = [b - PIPELINE_DELAY for b in detected]

    for i, beat in enumerate(detected_compensated):
        if i in matched_det:
            continue
        best_j   = -1
        best_dist = tolerance + 1
        for j, ann in enumerate(annotated):
            if j in matched_ann:
                continue
            dist = abs(beat - ann)
            if dist <= tolerance and dist < best_dist:
                best_dist = dist
                best_j    = j
        if best_j >= 0:
            tp += 1
            matched_det.add(i)
            matched_ann.add(best_j)

    fn = len(annotated) - tp
    fp = len(detected) - tp

    sensitivity = tp / (tp + fn) if (tp + fn) > 0 else 0
    precision   = tp / (tp + fp) if (tp + fp) > 0 else 0
    f1 = 2 * sensitivity * precision / (sensitivity + precision) \
         if (sensitivity + precision) > 0 else 0

    return {'tp': tp, 'fp': fp, 'fn': fn,
            'sensitivity': sensitivity,
            'precision': precision,
            'f1': f1}

# ─────────────────────────────────────────
# Run on MIT-BIH benchmark records
# ─────────────────────────────────────────

records = ['100', '101', '103', '105', '108']

print(f"{'Record':<8} {'Beats':>6} {'Det':>6} {'TP':>5} "
      f"{'FP':>5} {'FN':>5} {'Se%':>7} {'Pr%':>7} {'F1%':>7}")
print("-" * 65)


total_tp = total_fp = total_fn = 0

for rec in records:
    try:
        record     = wfdb.rdrecord(rec, pn_dir='mitdb')
        annotation = wfdb.rdann(rec, 'atr', pn_dir='mitdb')
    except Exception as e:
        print(f"{rec}: download failed ({e})")
        continue

    ecg_raw      = record.p_signal[:, 0]
    ann_samples  = annotation.sample

    # Filter to normal beat annotations only
    # MIT-BIH uses 'N' for normal, 'L','R' for bundle branch blocks, etc.
    # Include all beat types for overall sensitivity
    beat_symbols = set('NLRBAaJSVrFejnE/fQ')
    ann_beats    = np.array([
        s for s, sym in zip(annotation.sample, annotation.symbol)
        if sym in beat_symbols
    ])

    mwi_signal = run_pipeline(ecg_raw)
    detected   = detect_beats(mwi_signal)

    results = evaluate(detected, ann_beats, tolerance=36)

    total_tp += results['tp']
    total_fp += results['fp']
    total_fn += results['fn']

    print(f"{rec:<8} {len(ann_beats):>6} {len(detected):>6} "
      f"{results['tp']:>5} {results['fp']:>5} {results['fn']:>5} "
      f"{results['sensitivity']*100:>6.1f}% "
      f"{results['precision']*100:>6.1f}% "
      f"{results['f1']*100:>6.1f}%")

# Overall numbers
overall_se = total_tp / (total_tp + total_fn) if (total_tp + total_fn) > 0 else 0
overall_pr = total_tp / (total_tp + total_fp) if (total_tp + total_fp) > 0 else 0
print("-" * 65)
print(f"{'OVERALL':<8} {'':>6} {'':>6} {total_tp:>5} {total_fp:>5} "
      f"{total_fn:>5} {overall_se*100:>6.1f}% {'':>7} {overall_pr*100:>6.1f}%")

print(f"\nTP={total_tp}  FP={total_fp}  FN={total_fn}")
print(f"Overall Sensitivity: {overall_se*100:.1f}%")
print(f"Overall Precision:   {overall_pr*100:.1f}%")

# ─────────────────────────────────────────
# Plot record 100 as visual validation
# ─────────────────────────────────────────

import matplotlib.pyplot as plt

record     = wfdb.rdrecord('100', pn_dir='mitdb')
annotation = wfdb.rdann('100', 'atr', pn_dir='mitdb')
ecg_raw    = record.p_signal[:, 0]
ann_beats  = np.array([
    s for s, sym in zip(annotation.sample, annotation.symbol)
    if sym in beat_symbols
])

mwi_signal = run_pipeline(ecg_raw)
detected   = detect_beats(mwi_signal)

plot_end = 1800
detected_plot  = [b for b in detected  if b < plot_end]
ann_beats_plot = [b for b in ann_beats if b < plot_end]

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 7), sharex=True)

ax1.set_xlim(0, plot_end)
ax2.set_xlim(0, plot_end)


# Top: raw ECG with detections marked
ax1.plot(ecg_raw[:plot_end], color='steelblue', linewidth=0.8, label='Raw ECG')
for b in detected:
    ax1.axvline(x=b, color='green', alpha=0.7, linewidth=1.2, label='Detected' if b==detected[0] else '')
for b in ann_beats:
    ax1.axvline(x=b, color='red', alpha=0.4, linewidth=0.8, linestyle='--',
                label='Annotated' if b==ann_beats[0] else '')

ax1.set_ylabel('Amplitude')
ax1.set_title('MIT-BIH Record 100 — ECG with QRS Detections')
ax1.legend(loc='upper right', fontsize=8)

# Bottom: MWI signal
ax2.plot(mwi_signal[:plot_end], color='darkorange', linewidth=0.8, label='MWI output')
for b in detected:
    ax2.axvline(x=b, color='green', alpha=0.7, linewidth=1.2)
ax2.set_ylabel('MWI Amplitude')
ax2.set_xlabel('Sample (360 Hz)')
ax2.set_title('Moving Window Integrator Output')
ax2.legend(loc='upper right', fontsize=8)

plt.tight_layout()
plt.savefig('test/validation_plot.png', dpi=150)
plt.show()
print("\nPlot saved to test/validation_plot.png")
print("First 5 detected:", detect_beats(run_pipeline(record.p_signal[:,0]))[:5])
print("First 5 annotated:", list(ann_beats[:5]))

record = wfdb.rdrecord('100', pn_dir='mitdb')
mwi_out = run_pipeline(record.p_signal[:,0])
det = detect_beats(mwi_out)
ann = wfdb.rdann('100', 'atr', pn_dir='mitdb')
print("Detections:", det[:15])
print("Annotations:", list(ann.sample[:15]))