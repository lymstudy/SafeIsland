# VCS/Verdi Simulation Templates

These scripts are engineering templates for a Linux host with Synopsys VCS and Verdi installed. The current checked simulation result is from ModelSim on Windows; these scripts are not claimed as locally executed in this workspace.

## Environment Assumptions

- `vcs`, `verdi`, and required license variables are available from `PATH`.
- Optional variables `VCS_HOME` and `VERDI_HOME` may be exported by the site setup script.
- Run scripts from any directory; outputs are written under `SafeIsland/sim/out/`.

## Commands

```bash
cd SafeIsland/sim/vcs
chmod +x run_top_full.sh run_fault_injection.sh
./run_top_full.sh
./run_fault_injection.sh
```

## Outputs

- `../out/vcs_top_full/compile.log`
- `../out/vcs_top_full/sim.log`
- `../out/vcs_top_full/vcdplus.vpd`
- `../out/vcs_fault_injection/compile.log`
- `../out/vcs_fault_injection/sim.log`
- `../out/vcs_fault_injection/vcdplus.vpd`
- `../out/vcs_fault_injection/fault_injection_summary.txt`

The ModelSim flow remains the recommended local acceptance flow for this Windows workstation.
