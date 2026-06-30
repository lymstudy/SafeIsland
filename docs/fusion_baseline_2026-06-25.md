# Fusion Baseline 2026-06-25

> ⚠️ **历史记录** — 本文档为 2026-06-25 融合基线快照，部分数据已过时（包含当时未修復的模块级测试失败记录）。
> 当前权威状态请参考 `docs/项目计划与进度.md` 和 `docs/工程概览/` 目录。
> 最终验证结果以 ModelSim + VCS 双平台全通数据为准（Full TB 34/34, FI 38/38, Bit Sweep 594/594）。

- `python SafeIsland/tools/run_tests.py --level module` currently shows:
  - `s_axi_config`: FAIL
  - `config_checker`: PASS
  - `axi_master_channel`: PASS
  - `data_fault`: FAIL
- Observed on 2026-06-25:
  - `s_axi_config` failed with 8 errors (`CFG-007`, `CFG-009a`..`CFG-009d`, `CFG-010a`, `CFG-010b`, `CFG-012c`).
  - `data_fault` failed with 6 errors (`DAT-002`, `DAT-004`, `FLT-001`, `FLT-002`, `FLT-007`, `FLT-009`).
- `python SafeIsland/tools/run_tests.py --level top` is outside this module-gate baseline snapshot and is treated here as a separate integration smoke lane.
- These failures must be removed or replaced by stronger module tests during fusion.
