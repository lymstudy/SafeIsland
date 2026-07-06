# Agent Status

Updated: 2026-07-06 09:56

## 1. 修改了哪些文件
- `README.md` — 目录树修正；验证结果表更新为 VM 实测数据
- `fault_campaign/README.md` — 分母说明、提交状态、复现命令
- `fault_campaign/safety_metrics_report.csv` — 填入 required campaign 覆盖率与保护率
- `sim/fault_injection/diagnostic_coverage_summary.txt` — 重写为最终汇总
- `sim/fault_injection/reports/fault_baseline_summary.txt` — 更新为 VM 实测 92%
- `sim/fault_injection/reports/fault_batch_summary.txt` — 更新为 VM 实测 99%
- `tools/gen_fault_lists.py` — Register 213798 行；Python 3.6 兼容
- `tools/run_fault_campaign.py` — UCLI campaign；TCL 花括号；select_full 修复；断点续跑；进度文件
- `tools/analyze_fi_report.py` — safe 分类；Strict/Engineering 双保护率
- `tb/fault_injection/tb_safety_island_fault_injection.v` — +UCLI_CAMPAIGN；XMR 修复；UCLI 模式跳过旧 CSV 头
- `rtl/safety_island_axi_read_engine.v` — 8 个 wire→reg（Illegal LHS）
- `scripts/Makefile` — campaign-* / campaign-full-isolated / wait-and-run-full
- `scripts/run_fault.sh` — 默认 fault batch campaign-required campaign-report fi-summary
- `tools/wait_and_run_full.sh` — 自动编排（本次 full 已取消）
- `.cursor/rules/vm-ssh-access.mdc` — IP 更新为 192.168.113.150

## 2. 新增了哪些文件
- `tools/run_fault_campaign.py`
- `tools/probe_faultsim_tool.sh`
- `tools/run_logic_faultsim.sh`
- `tools/wait_and_run_full.sh`
- `sim/fault_injection/reports/fault_campaign_*.csv/txt`（从 VM 同步）
- `sim/fault_injection/reports/fault_site_coverage.csv`（从 VM 同步）

## 3. 跑了哪些命令（VM: 192.168.113.150）
- `python tools/gen_fault_lists.py`
- `make campaign-comp` → 成功
- `make fault batch` → 成功
- `make campaign-required` → 成功（第二轮，UCLI 修复后）
- `make campaign-report fi-summary` → 成功
- `make campaign-full-isolated` → **已启动后用户取消**

## 4. 哪些命令通过
| 命令 | 结果 |
|------|------|
| `make campaign-comp` | PASS |
| `make fault` | PASS — 54 cases, 92% |
| `make batch` | PASS — 610 cases, 99% |
| `make campaign-required` | PASS — 286 faults |
| `make campaign-report` | PASS |
| `make fi-summary` | PASS |

## 5. 失败项及修复（均已解决）
- campaign-comp 6 个 VCS 错误（XMR + Illegal LHS）→ TB/RTL 修复
- required 第一轮 286/286 error → UCLI TCL 花括号 `force {path[idx]}`
- full KeyError model → `select_full` 写回 model 字段
- VM IP 变更 149→150 → 规则文件已更新

## 6. Register/memory 覆盖率
- 清单：**213798** 行
- Required 直接仿真：36
- 等效覆盖：212414
- **覆盖率：99.37%**

## 7. Digital logic 覆盖率
- 清单：**6641** 行
- Required 直接仿真：250
- 等效覆盖：5871
- **覆盖率：92.17%**

## 8. Campaign 保护率（286 直接仿真）
- corrected=31, detected=82, latent=1, safe=142, error=30, undetected=0
- **Strict：39.51%**
- **Engineering：89.51%**

## 9. Test-Faultsim
- optional 路径已就绪（`make logic-faultsim-probe`），未阻塞主流程

## 10. 提交内容清单

### 可直接提交
- `rtl/` `tb/` `scripts/` `tools/` `fault_campaign/`
- `sim/fault_injection/diagnostic_coverage_summary.txt`
- `sim/fault_injection/reports/fault_*.csv` + `fault_*_summary.txt`
- `sim/fault_injection/reports/fault_campaign_*`
- `sim/fault_injection/reports/fault_site_coverage.csv`
- `fault_campaign/safety_metrics_report.csv`
- 5 份 docx（需人工核对 `5-注错仿真计划.docx`）

### 不要提交（临时文件）
- `sim/work/` `sim/work_full/` — simv、ucli、fault_results
- `.ai-bridge/`（内部协作用）

### 待人工处理
- `5-注错仿真计划.docx`：补充 UCLI campaign 架构、分母行数、双保护率公式、复现命令、full 未执行声明
- 功能仿真：安全升级后 RTL outstanding_flow 挂起，需排查修复后方可重新回归（当前保留升级前 PASS 34/34 摘要）

## 11. Full campaign
- **未执行**（用户决定，时间来不及）
- 汇总已标注：`required campaign executed; full campaign was not executed`

## 12. 本次（2026-07-06）修改记录
### 修改的文件
- `tools/analyze_fi_report.py` — 增加 `error` 分类；`undetected` 与 `tool/TB injection error` 分离
- `README.md` — RTL 数量 7→8；功能仿真状态改为"部分完成+如实说明"；Campaign Required 行分离 error/undetected
- `scripts/环境运行说明.md` — 3.2 节更新为 286 required campaign；Makefile 目标表补充；Strict/Engineering 双公式；删除"历史数据"表述；coverage 说明如实反映现状
- `scripts/Makefile` — `full-run`/`fault-run`/`batch-run`/`cov-full-run` 增加 `cd $(WORK_DIR)` 修复 FSDB 路径
- `sim/fault_injection/diagnostic_coverage_summary.txt` — error/undetected 分离
- `sim/fault_injection/reports/fault_campaign_safety_report.csv` — 重新生成（error/undetected 分离）
- `sim/fault_injection/reports/fault_campaign_summary.txt` — error/undetected 分离

### 尝试但阻塞
- VM 功能仿真重跑：编译成功，前 7 个测例 PASS，第 8 个 `outstanding_flow` 挂起。原因：安全升级 RTL 修改后，该测例不再通过。未修改 RTL/Testbench（按计划约束）。

### 仍需人工完成
1. 人工打开 5 个 docx，搜索并修正以下关键词：
   - `117K bits` → `220439 rows inventory`
   - `594 bit sweep 100%` → 更新口径
   - `SPFM/LFM=100% 正式证明` → design-intent + campaign mapping
   - `full campaign 已执行` → 改为未执行
2. 排查并修复 `outstanding_flow` 功能测例挂起问题
3. 打包前确认排除 `.cursor/`, `.ai-bridge/`, `tools/__pycache__/`, `*.pyc`, `sim/work/`, `simv*`, `csrc/`, `*.daidir/`, 波形
