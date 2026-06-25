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
    vcs/                VCS/Verdi Linux replay templates
    out/                Generated simulation libraries, logs, WLF, VCD
  docs/                 Design notes, requirement check, simulation notes
  meeting/              Meeting and schedule notes
```

## Main ModelSim Commands

Run from `SafeIsland/sim/modelsim`.

```powershell
cd D:\studydoc\competition\PIC\SafeIsland\sim\modelsim
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

Current full top regression covers 17 cases, including AXI out-of-order, read interleaving, and AoU CRC-8 R-channel check optional tests.

The monitor AXI read interface includes `m_axi_rcheck_flat`, an 8-bit CRC per master R beat. The CRC-8 covers `{RID,RDATA,RRESP,RLAST}` with polynomial `0x07` and initial value `0x00`; a mismatch is reported as a bus fault.

Fault injection also writes the campaign summary to:

```text
SafeIsland/sim/out/safety_island_fault_injection/fault_injection_summary.txt
```

The current engineering fault-injection campaign covers 18 cases with `undetected=0`.

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

## VCS/Verdi Templates

`SafeIsland/sim/vcs/` contains Linux replay templates:

```bash
cd SafeIsland/sim/vcs
./run_top_full.sh
./run_fault_injection.sh
```

These scripts assume `vcs`/`verdi` and licenses are available from the shell environment. The locally verified flow for this workstation is still the ModelSim flow above.
