# Findings & Decisions

## Requirements
- User wants the whole project assessed through the related files in `docs/`.
- Output should explain how to further improve contest scoring.
- Initial task is analysis and recommendation; no code changes requested yet.

## Research Findings
- Scoring is 100 points: basic module implementation 30, safety theory/doc analysis 20, safety mechanism implementation 30, fault injection/coverage 20.
- Required submission artifacts include design docs, RTL/testbench/replay scripts, fault-injection environment/results with diagnostic coverage, VCS automation scripts, and functional simulation results including code line coverage.
- Current docs claim strong functionality and safety mechanism implementation: ModelSim/VCS full TB 34/34 PASS, FI baseline 38/38 DETECTED, FI bit sweep 594/594 DETECTED in `README.md`.
- Older scoring self-assessment in `docs/赛题评分细则.md` estimates only ~60-70/100 because safety theory analysis, SPFM/LFM, VCS measured results, code line coverage, and large-scale FI statistics were incomplete at that time.
- `docs/失效模型分析.md` is now much more complete, but explicitly warns that current bit statistics include redundant implementation bits and should not be treated as original safety-goal protected-bit coverage. It asks for two recalculated views: original function bits and added protection bits.
- `docs/失效模型分析.md` identifies remaining gaps: 22/65 digital logic paths still unprotected or needing proof, especially shadow comparators, config error detection, CRC calculation/comparison, slot allocation/release, heartbeat timeout, and config read/write logic.
- `docs/fusion_baseline_2026-06-25.md` is an old baseline snapshot, not current status. Current `tb/tb_s_axi_config.v` includes the old failed CFG cases as PASS expectations, and current `tb/tb_data_fault.v` includes the old DAT/FLT cases as PASS expectations.
- Current RTL supports those repaired module paths: `rtl/s_axi_config.v` implements address validity/write protection/W1C/shadow checks; `rtl/read_data_processor.v` implements masked compare and OR accumulation; `rtl/fault_detector.v` implements external fault, timeout/error, safety fault, and latent fault outputs.
- `docs/工程概览/` now contains more current overview, quick-start, toolchain, architecture, and verification-platform documentation that should be treated as stronger current documentation than older baseline notes.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Treat docs content as the scoring source of truth | Contest-score improvement should be tied to explicit scoring items and existing evidence. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Earlier analysis incorrectly treated old fusion baseline failures as current. | Re-checked current TB/RTL. Treat `docs/fusion_baseline_2026-06-25.md` as historical only; current scoring assessment should rely on ModelSim/VCS flows and current TBs. |

## Resources
- `docs/赛题评分细则.md`
- `docs/设计需求对照检查_AXI_core.md`
- `docs/测试方案与报告.md`
- `docs/失效模型分析.md`
- `docs/设计测试文档.md`
- `docs/superpowers/specs/2026-06-25-axi-safety-island-asil-d-fix-design.md`
- `docs/superpowers/plans/2026-06-25-axi-safety-island-asil-d-fix-plan.md`

## Score Gap Hypothesis
- Highest score-impact near-term work: produce defensible coverage evidence, not more feature work.
- Likely priorities: line coverage, original-bit fault coverage tables, SPFM/LFM calculation evidence, final reproducible VCS/ModelSim logs and generated reports.
- Generated evidence files such as simulation logs, waveforms, and fault reports are produced in the simulator/editor environment and may be git-ignored. Treat them as submission-package artifacts to collect separately, not as source-repo gaps.

## Visual/Browser Findings
- Not applicable.
