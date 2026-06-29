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

Current full top regression covers 34 cases, verified on both **ModelSim** and **VCS T-2022.06**, including AXI out-of-order, read interleaving, S_AXI write-verify, heartbeat self-check, KAT, Expected Compare, and CRC-8/16 R-channel check tests.

The monitor AXI read interface includes `m_axi_rcheck_flat`, a parameterized CRC per master R beat (CRC_WIDTH=8 or 16). In CRC-8 mode the check covers `{RID,RDATA,RRESP,RLAST}` with polynomial `0x07` and initial value `0x00`. In CRC-16 mode a two-stage E2E signature covers both AR-channel parameters and R-channel fields with polynomial `0x1021` and initial value `0xFFFF`. A mismatch is reported as a bus fault.

Fault injection campaign summary: **38 baseline (100% detected)** + **594 full bit sweep (100% detected)**.

Bit sweep report:
```text
SafeIsland/sim/out/safety_island_fault_injection/batch_coverage_report.txt
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

## VCS/Verdi Templates

`SafeIsland/sim/vcs/` contains Linux replay templates:

```bash
cd SafeIsland/sim/vcs
./run_top_full.sh
./run_fault_injection.sh
```

These scripts assume `vcs`/`verdi` and licenses are available from the shell environment. The locally verified flow for this workstation is still the ModelSim flow above.

## ASIL-D Safety Enhancements (2026-06-25)

The following safety enhancements have been implemented to address AXI port interface fault detection gaps:

| Enhancement | Files | Description |
|-------------|-------|-------------|
| CRC-16 E2E Protection | `safety_island_axi_read_engine.v`, `safety_island_top.v` | Parameterized CRC_WIDTH (8/16), AR channel signature with two-stage CRC |
| Heartbeat Self-Check | `safety_island_heartbeat.v` | Periodic test injection to verify fault_detect output path integrity |
| Known-Answer Test (KAT) | `safety_island_core_logic.v`, `safety_island_axi_config_slave.v` | Pre-scan known-register read to validate complete read path |
| TMR Critical Paths | `tmr_voter.v`, `safety_island_core_logic.v`, `safety_island_top.v` | Triple-modular redundancy on FSM state, fault outputs, config lock |
| Write-Verify | `safety_island_axi_config_slave.v` | Post-write shadow consistency check for S_AXI write protection |

### Verification Summary

| Platform | Full TB | FI Baseline | FI Bit Sweep |
|----------|:--:|:--:|:--:|
| ModelSim (Win) | 34/34 PASS | 38/38 DETECTED | 594/594 DETECTED |
| VCS T-2022.06 (Linux) | 34/34 PASS | 38/38 DETECTED | 594/594 DETECTED |
| Icarus 0.9.7 | 17/22 (77%) | — | — |

- CRC_WIDTH=8 backward compatibility maintained
- All ASIL-D safety enhancements verified on both simulators

---

## Current Project Status (2026-06-26)

### Completed
- ✅ All RTL modules (16+ modules across two versions)
- ✅ All optional features (out-of-order, interleaving, latent fault, AoU CRC-8/16, expected compare)
- ✅ 6 ASIL-D safety enhancements (CRC-16 E2E, Heartbeat, KAT, TMR, Write-Verify, Enhanced Verification)
- ✅ ModelSim + VCS dual-platform verification: Full TB 34/34, FI 38/38 baseline, FI 594/594 bit sweep
- ✅ Complete failure model analysis (Memory/Register ~117K bits + Digital Logic 65 fault sites)
- ✅ Python batch fault injection automation with coverage reporting
- ✅ VCS/Verdi simulation scripts with FSDB waveform generation
- ✅ Design documents (failure model, test plan, requirements checklist, project plan)

### Remaining
- 🟡 VCS fault_detector unit test: 3/18 fail (error code mapping), isolated from main modules
- 🟡 Code line coverage statistics
- 🟡 Digital logic deep-combinational path equivalence argument (41/65 sites beyond force capability)
- 🟢 Final submission package assembly
