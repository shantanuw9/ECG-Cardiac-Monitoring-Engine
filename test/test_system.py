import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import numpy as np
import os

def load_ecg():
    """Load pre-generated ECG samples from mem file"""
    samples = []
    mem_path = os.path.join(os.path.dirname(__file__), 'ecg_input_100.mem')
    with open(mem_path) as f:
        for line in f:
            val = int(line.strip(), 16)
            # Convert unsigned 16-bit back to signed
            if val > 32767:
                val -= 65536
            samples.append(val)
    return samples

@cocotb.test()
async def test_qrs_detection(dut):
    """Feed MIT-BIH record 100 (first 1800 samples) and count beats"""

    clock = Clock(dut.clk, 10000, unit="ns")  
    cocotb.start_soon(clock.start())

    # 2. Power the physical chip
    power_pins = ['VPWR', 'VPB', 'vccd1', 'vdd', 'vcc']
    ground_pins = ['VGND', 'VNB', 'vssd1', 'vss']
    
    for pwr in power_pins:
        if hasattr(dut, pwr):
            getattr(dut, pwr).value = 1
            dut._log.info(f"Successfully powered high: {pwr}")
            
    for gnd in ground_pins:
        if hasattr(dut, gnd):
            getattr(dut, gnd).value = 0
            dut._log.info(f"Successfully grounded: {gnd}")

    # Reset the control logic
    dut.rst_n.value      = 0
    dut.ecg_sample.value = 0
    dut.sample_valid.value = 0
    await ClockCycles(dut.clk, 10)
    await FallingEdge(dut.clk) 
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # ---------------------------------------------------------
    # THE FIX: FLUSH THE PIPELINE
    # Shift 100 dummy zeros through the active pipeline to physically 
    # overwrite and push out any stuck 'X' states before testing.
    # ---------------------------------------------------------
    dut._log.info("Flushing X states from GLS pipeline...")
    for _ in range(100):
        await FallingEdge(dut.clk)
        dut.ecg_sample.value = 0
        dut.sample_valid.value = 1
        
        await FallingEdge(dut.clk)
        dut.sample_valid.value = 0
        
        await ClockCycles(dut.clk, 1)

    # Start the real data
    samples = load_ecg()
    beat_count  = 0
    current_sample = 0

    # 1. The Monitor: Runs in the background and checks EVERY clock cycle
    async def monitor_beats():
        nonlocal beat_count
        while True:
            await RisingEdge(dut.clk)
            # Safe check in case the signal goes to 'X' or 'Z' during init
            if dut.beat_detected.value == 1:
                beat_count += 1
                dut._log.info(f"Beat {beat_count} detected near sample {current_sample} "
                              f"HR={int(dut.heart_rate.value)} BPM "
                              f"QRS_width={int(dut.qrs_width.value)}")

    # Spawn the monitor task
    cocotb.start_soon(monitor_beats())

    # 2. The Driver: Blindly pushes samples without worrying about checking outputs
    for i, sample in enumerate(samples):
        current_sample = i
        
        await FallingEdge(dut.clk)
        dut.ecg_sample.value   = int(sample) & 0xFFFF
        dut.sample_valid.value = 1
        
        await FallingEdge(dut.clk)
        dut.sample_valid.value = 0

        # Wait the remaining 1 cycle to simulate ADC timing
        await ClockCycles(dut.clk, 1)

    # 3. The Flush: Wait for the last samples to finish traveling through the filters
    for _ in range(150):
        await FallingEdge(dut.clk)
        dut.ecg_sample.value = 0
        dut.sample_valid.value = 1
        
        await FallingEdge(dut.clk)
        dut.sample_valid.value = 0
        
        await ClockCycles(dut.clk, 1)

    dut._log.info(f"Total beats detected: {beat_count}")

    # MIT-BIH record 100, first 1800 samples has 6 annotated beats
    assert 4 <= beat_count <= 8, \
        f"Expected 4-8 beats in first 1800 samples, got {beat_count}"

    # Check cardiomyopathy flags
    dut._log.info(f"Final flags: wide_qrs={int(dut.wide_qrs.value)} "
                 f"tachy={int(dut.tachy_flag.value)} "
                 f"brady={int(dut.brady_flag.value)} "
                 f"low_hrv={int(dut.low_hrv.value)}")
