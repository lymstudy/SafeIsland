# Fault Campaign 注错配置

## 文件说明

| 文件 | 说明 |
|------|------|
| `Register_fault_list.csv` | post-TMR 寄存器/记忆体 bit 级故障清单，作为 register/memory 注错覆盖率的分母 |
| `Logic_fault_list.csv` | post-TMR 数字逻辑 bit 级故障清单，作为 digital logic 注错覆盖率的分母 |
| `legacy_logic_signal_list.csv` | 升级前 459 信号级逻辑清单（`gen_fault_lists.py` 输入，勿删） |
| `fault_smoke_tmr.csv` | 升级后 smoke 用例（14 项，TB 回归入口） |
| `Register_fault_summary.txt` | 寄存器清单汇总 |
| `Logic_fault_summary.txt` | 逻辑清单汇总 |
| `safety_metrics_report.csv` | SPFM/LFM 指标（由 VCS campaign 与等效覆盖映射生成） |

## 注错分母合计

- Register/memory: `Register_fault_list.csv` 行数
- Digital logic: `Logic_fault_list.csv` 行数

两者合计为注错覆盖率的总 site 分母。

## 生成与统计

```bash
cd submission

python tools/gen_fault_lists.py

python tools/analyze_fi_report.py \
  --input sim/fault_injection/reports/fault_campaign_report.csv \
  --output sim/fault_injection/reports/fault_campaign_safety_report.csv \
  --detail-output sim/fault_injection/reports/fault_campaign_detail.csv
```

## 默认复现命令

```bash
cd submission/scripts
bash run_fault.sh
```

默认流程执行：

- `make fault` — 基线 54 条注错用例
- `make batch` — bit/entry 级快速扫点
- `make campaign-required` — 从 `Register_fault_list.csv` 与 `Logic_fault_list.csv` 中抽取代表性 family 进行 UCLI 注错，并做等效覆盖映射
- `make campaign-report` — 生成 campaign 安全报告
- `make fi-summary` — 汇总 baseline / batch / campaign 结果到 `sim/fault_injection/diagnostic_coverage_summary.txt`

## 提交状态（2026-07-06）

**已执行并纳入提交：**
- `make fault` — baseline 54 条，保护率 92%
- `make batch` — 610 条，保护率 99%
- `make campaign-required` — 286 条 family 代表 + 等效覆盖映射
- `make campaign-report` + `make fi-summary`

**未执行（时间限制，非默认提交必要项）：**
- `make campaign-full` / `make campaign-full-isolated` — per-row 全量 220439 条

**正式报告位置：**

| 文件 | 说明 |
|------|------|
| `sim/fault_injection/diagnostic_coverage_summary.txt` | 总摘要 |
| `sim/fault_injection/reports/fault_injection_report.csv` | baseline |
| `sim/fault_injection/reports/fault_batch_report.csv` | batch |
| `sim/fault_injection/reports/fault_campaign_report.csv` | campaign 逐条 |
| `sim/fault_injection/reports/fault_campaign_summary.txt` | campaign 汇总 |
| `sim/fault_injection/reports/fault_campaign_safety_report.csv` | 安全指标 |
| `sim/fault_injection/reports/fault_site_coverage.csv` | 逐 site 覆盖 |
| `fault_campaign/safety_metrics_report.csv` | SPFM/LFM 摘要 |

## 全量注错命令（可选，本次未执行）

```bash
cd submission/scripts
make campaign-full-isolated
```

该命令对 `Register_fault_list.csv` + `Logic_fault_list.csv` 的每一行执行 UCLI 注错，耗时较长（约 1–2 天）。与 required campaign 隔离：

| 路径 | 用途 |
|------|------|
| `sim/work_full/` | 临时 UCLI、单条结果、simv_campaign |
| `sim/fault_injection/reports/full/` | 全量正式报告 |
| `sim/work_full/campaign_progress.txt` | 进度（每 100 条更新，支持断点续跑） |

自动编排（等 required + fault/batch 完成后自动开 full）：

```bash
nohup bash tools/wait_and_run_full.sh > /tmp/wait_and_run_full.log 2>&1 &
```

默认 `run_fault.sh` 不跑 `campaign-full` / `campaign-full-isolated`。

## 临时文件约束

- 临时 UCLI 脚本：`sim/work/ucli/`
- 单条 fault 中间结果：`sim/work/fault_results/`
- 编译产物（simv、daidir、csrc）：`sim/work/`
- 这些中间文件由 `make finalize` 或 `make clean-work` 清理，不作为提交材料保留。

## 说明

- 注错结果正式报告在 `sim/fault_injection/reports/`
- 诊断覆盖率摘要在 `sim/fault_injection/diagnostic_coverage_summary.txt`
- 若 `make campaign-full` 未执行，汇总中必须明确标注：`required campaign 已执行，full campaign 未执行`。
