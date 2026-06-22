# SafeIsland Project Layout

## Directory Structure

```text
SafeIsland/
  rtl/                  Safety island RTL source files
    AXI/                Reusable AXI master/slave RTL
    safety_island_top.f Top-level RTL filelist, intended to run from rtl/
  tb/                   Testbench source files
    axi/                AXI unit testbenches and simulation-only models
  sim/
    modelsim/           ModelSim run scripts for top-level tests
      axi/              ModelSim run scripts for AXI unit tests
    out/                Generated simulation libraries, logs, WLF, VCD
  docs/                 Design notes, requirement check, simulation notes
  meeting/              Meeting and schedule notes
```

## Main ModelSim Commands

Run from `SafeIsland/sim/modelsim`.

```powershell
& 'D:\software\modelism\MODELISM\win64\vsim.exe' -c -do run_safety_island_top_basic_tb.do
& 'D:\software\modelism\MODELISM\win64\vsim.exe' -c -do run_safety_island_top_full_tb.do
& 'D:\software\modelism\MODELISM\win64\vsim.exe' -c -do run_safety_island_fault_injection_tb.do
```

Full-test waveforms are generated at:

```text
SafeIsland/sim/out/safety_island_top_full/safety_island_top_full.wlf
SafeIsland/sim/out/safety_island_top_full/safety_island_top_full.vcd
SafeIsland/sim/out/safety_island_fault_injection/safety_island_fault_injection.wlf
SafeIsland/sim/out/safety_island_fault_injection/safety_island_fault_injection.vcd
```

Open WLF in ModelSim:

```powershell
& 'D:\software\modelism\MODELISM\win64\vsim.exe' -view D:\studydoc\competition\PIC\SafeIsland\sim\out\safety_island_top_full\safety_island_top_full.wlf
```

## AXI Unit Test Commands

Run from `SafeIsland/sim/modelsim/axi`.

```powershell
& 'D:\software\modelism\MODELISM\win64\vsim.exe' -c -do run_axi_master_tb.do
& 'D:\software\modelism\MODELISM\win64\vsim.exe' -c -do run_axi_slave_tb.do
```
