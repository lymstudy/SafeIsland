# SafeIsland 提交版整理与最终审查计划

Updated: 2026-07-06T02:58:00+08:00
Workspace: D:\studydoc\competition\PIC\SafeIsland\SafeIsland-ymliu\submission
Target agent: Codex (codex)

## 当前追加结论：functional 目录确实不完整

刚核查当前提交目录：

- `sim/functional/regression_summary.txt` 存在，内容显示 `PASS 34/34`。
- `sim/functional/line_coverage_summary.txt` 存在，内容声称 coverage database 位于 `sim/functional/coverage/build.vdb`，并引用 `logs/cov_count.log`、`logs/cov_run.log`。
- 但当前 tree 中 `sim/functional/` 只有：
  - `logs/` 空目录
  - `line_coverage_summary.txt`
  - `regression_summary.txt`
- 当前实际缺失：
  - `sim/functional/logs/full_run.log`
  - `sim/functional/logs/full_compile.log`
  - `sim/functional/logs/cov_run.log`
  - `sim/functional/logs/cov_compile.log`
  - `sim/functional/logs/cov_count.log`
  - `sim/functional/coverage/build.vdb`
  - `sim/functional/coverage/urgReport/index.html`

判断：这不是“很多东西全缺”，但 functional 证据链明显不完整。评分细则要求功能仿真结果含代码行覆盖率，因此只交两个 txt 摘要风险较大。

## P0 新增：补 functional 仿真与 coverage 证据链

正式提交前建议至少补齐以下二选一：

### 方案 A：最稳，重新跑 functional

在 VCS VM 上执行：

```bash
cd submission/scripts
bash run_functional.sh
```

跑完后从 VM 同步/保留：

- `sim/functional/logs/full_compile.log`
- `sim/functional/logs/full_run.log`
- `sim/functional/logs/cov_compile.log`
- `sim/functional/logs/cov_run.log`
- `sim/functional/logs/cov_count.log`
- `sim/functional/regression_summary.txt`
- `sim/functional/line_coverage_summary.txt`
- 如果存在且体积可接受：`sim/functional/coverage/urgReport/`
- 如果评委可能复查 coverage：保留 `sim/functional/coverage/build.vdb`；若体积太大，则 README 必须明确“未随包提交 build.vdb，提供脚本可复现生成”。

### 方案 B：如果来不及重跑

至少把 README / 环境说明改成保守口径：

- 不写“coverage/build.vdb 已随包提交”。
- 不写“HTML 覆盖率报告已提交”。
- 写成：`当前提交保留 regression_summary.txt 与 line_coverage_summary.txt；完整日志/coverage 数据库可通过 scripts/run_functional.sh 在 VCS 环境复现生成。`

但注意：方案 B 是救火，不如方案 A。能跑就跑。

## 目标

提交前只做“口径统一 + 风险降噪 + 必要修正”，不要再大改 RTL 架构。核心目标是让评委看到：

1. 功能实现、RTL、TB、VCS 脚本、报告能闭环复现。
2. 失效模型、安全机制、注错结果三者互相对得上。
3. 未完成的 full per-row campaign 明确声明，不伪装成已跑。
4. functional 仿真和 coverage 不要只有摘要，最好有 logs 和可复现证据。
5. 所有报告避免互相打架，特别是 error / undetected、strict / engineering、SPFM / LFM 的口径。

## 评分细则反推的必须提交内容

按赛题评分，正式 zip 需要覆盖以下材料：

- 设计文档：`1-AXI_Safety_Island_设计文档.docx`
- 功能仿真计划：`2-功能仿真计划.docx`
- 失效模型：`3-失效模型描述_完整提交版.docx`
- 安全机制分析：`4-安全机制分析及设计.docx`
- 注错仿真计划：`5-注错仿真计划.docx`
- RTL：`rtl/`，当前 filelist 为 8 个设计文件：
  - `tmr_voter.v`
  - `tmr_voter_protected.v`
  - `safety_island_axi_read_engine.v`
  - `safety_island_core_logic.v`
  - `safety_island_axi_config_slave.v`
  - `safety_island_fault_detector.v`
  - `safety_island_heartbeat.v`
  - `safety_island_top.v`
  - `safety_island_top.f`
- 功能 TB：`tb/functional/tb_safety_island_top_full.v`
- 注错 TB：`tb/fault_injection/tb_safety_island_fault_injection.v`
- VCS 自动运行脚本：`scripts/Makefile`, `scripts/run_functional.sh`, `scripts/run_fault.sh`, `scripts/run_all.sh`, `scripts/环境运行说明.md`
- 功能仿真结果：`sim/functional/regression_summary.txt`, `sim/functional/logs/`, `sim/functional/line_coverage_summary.txt`，最好补 `coverage/` 或明确不随包提交。
- 注错结果：`sim/fault_injection/diagnostic_coverage_summary.txt`, `sim/fault_injection/reports/`
- 注错分母与覆盖映射：`fault_campaign/Register_fault_list.csv`, `fault_campaign/Logic_fault_list.csv`, `fault_campaign/*_summary.txt`, `fault_campaign/safety_metrics_report.csv`, `fault_campaign/README.md`
- 工具脚本：`tools/gen_fault_lists.py`, `tools/analyze_fi_report.py`, `tools/gen_safety_report.py`, `tools/run_fault_campaign.py`, `tools/logic_fault_catalog.py`

## 当前关键结论

### 可以作为主口径提交

- RTL 模块数量：README 里必须写 `8 个设计文件 + 1 个 filelist`，不能再写 `7 模块 + filelist`。
- 功能仿真：`sim/functional/regression_summary.txt` 显示 `PASS 34/34`，可以主报，但必须补日志或改成“摘要已保留、完整日志可复现”。
- 行覆盖率：当前只有 `line_coverage_summary.txt`，里面声称 build.vdb 存在，但目录中没看到 `coverage/`。正式提交前要么补 `coverage/build.vdb`，要么改 README 口径。
- 注错 baseline：54 case，`corrected=3 detected=47 undetected=4 protection_rate=92%`。
- 注错 batch：610 case，`corrected=3 detected=603 undetected=4 protection_rate=99%`。
- required campaign：286 representative faults，`corrected=31 detected=82 latent=1 safe=142 undetected=0 error=30`。
- 覆盖率主报：Register/memory `99.37%`，Digital logic `92.17%`，说明为“代表性 family 注错 + 等效覆盖映射”。
- full campaign：`220439` per-row 全量未执行。必须明确写“未执行，默认提交采用 required campaign + 等效映射；脚本保留 make campaign-full-isolated”。

### 不要作为主口径吹的内容

- 不要写“full campaign 全覆盖已完成”。没有。
- 不要写“220439 条逐条 VCS 注错全跑完”。没有。
- 不要写“SPFM/LFM 已由完整 ISO 26262 认证工具证明”。当前是设计意图 + representative campaign + mapping，不是认证工具闭环。
- 不要把 `Strict 39.51% FAIL` 放到 README 摘要主位置。Strict 口径不适合代表 family mapping 的工程结论；可保留在报告细项中，但主口径应解释 Engineering 与 coverage mapping。
- 不要把 `error=30` 直接算成真实设计逃逸。当前 evidence 显示它更像 tool/TB injection error，需要单列。
- 不要声称 functional coverage HTML 或 build.vdb 已提交，除非文件实际存在。
- 不要提交大型波形、编译产物、工作目录。

## 必须修正：不实、冲突、容易被扣分的记录

### P0：functional logs / coverage 缺证据

现状：

- `regression_summary.txt` 与 `line_coverage_summary.txt` 存在。
- 但 `logs/full_run.log`、`logs/cov_run.log`、`logs/cov_count.log` 不存在。
- `coverage/build.vdb` 或 `coverage/urgReport/index.html` 未在 tree 中出现。

具体修改：

1. 优先重新跑 `bash run_functional.sh` 并同步 logs + coverage。
2. 若无法补 coverage 数据库，README 和 `scripts/环境运行说明.md` 必须改成“可复现生成”，不要写“随包提交”。
3. `line_coverage_summary.txt` 如继续引用 `build.vdb`，必须确认实际文件存在；不存在就把措辞改为“生成路径为”。

### P0：error / undetected 统计冲突

现状：

- `sim/fault_injection/reports/fault_campaign_summary.txt` 写：`undetected=0 error=30`。
- `sim/fault_injection/reports/fault_campaign_safety_report.csv` 写：`Undetected (uncovered),30`，并列出 30 条 undetected fault。

判断：这是硬冲突。正式提交必须统一为：

- `tool/TB injection error = 30`
- `functional undetected = 0`
- `error` 不并入 `undetected`，除非能证明这些 error 是真实设计逃逸。

具体修改：

1. 修改 `tools/analyze_fi_report.py`：
   - 支持 raw `result_class == error` 或字段中含 `error` 时归入 `error` 类。
   - 新增 `Error / Tool-TB injection error` 统计。
   - `undetected` 只统计真实 `result_class == undetected`。
   - 报告标题不要再写 `Undetected (uncovered),30`。
2. 重新生成：
   - `sim/fault_injection/reports/fault_campaign_safety_report.csv`
   - `sim/fault_injection/reports/fault_campaign_detail.csv`
   - 如脚本会更新总摘要，也同步更新 `diagnostic_coverage_summary.txt`。
3. README 中写法统一为：
   - `Campaign Required: 286 representative faults; corrected=31, detected=82, latent=1, safe=142, functional undetected=0, tool/TB error=30`。

### P0：README 功能仿真状态过期

现状：

- README 仍可能写“功能仿真 待重跑”。
- `sim/functional/regression_summary.txt` 已写 `PASS 34/34`。

具体修改：

- README 改为：`功能仿真 已完成 | VCS T-2022.06 PASS 34/34`。
- 但如果 logs 没补齐，说明中加一句：`完整仿真日志可通过 scripts/run_functional.sh 复现生成`。

### P0：README RTL 数量错误

现状：README 写 `RTL 源码 (7 模块 + filelist)`。

具体修改：改成：`RTL 源码（8 个设计文件 + 1 个 filelist）`。

### P1：运行说明与 Makefile 目标不一致

现状：

- `scripts/环境运行说明.md` 第 50 行写“54 基线 + 610 全量 bit”。
- 但 `scripts/run_fault.sh` / Makefile 实际会跑：`fault + batch + campaign-required + campaign-report + fi-summary`。

具体修改：

- 3.2 标题改为：`仅注错仿真（54 baseline + 610 batch + 286 required campaign）`。
- Makefile 目标说明改：`make fault-all = fault + batch + campaign-required + campaign-report + fi-summary`。
- 删除“当前 summary 中保留历史 campaign 数据作参考”，改为“当前 summary 为 2026-07-06 VM 实测结果；full per-row campaign 未执行”。

### P1：保护概率公式要分层，不要混用

现状：`scripts/环境运行说明.md` 写 `保护概率 = (corrected + detected + latent) / 错误总数`，但 summary 里已经分为 Strict 与 Engineering。

具体修改：

- Strict protection probability = `(corrected + detected) / total`
- Engineering protection probability = `(corrected + detected + latent + safe) / total`
- `latent` 与 `safe` 不能在所有场景下直接等同赛题原始“保护概率”，必须解释为工程映射口径。

### P1：SPFM/LFM 口径不要绝对化

现状：`fault_campaign/safety_metrics_report.csv` 同时出现：

- `Design-intent SPFM,100.00%,...,DESIGN`
- `Campaign SPFM (required+mapping),99.37% (reg)`
- `Campaign LFM (required+mapping),92.17% (logic)`

风险：如果文档写“SPFM/LFM=100%正式证明”，会和 campaign/mapping 口径冲突。

建议正式口径：

- `Design-intent SPFM = 100%` 仅作为机制覆盖设计目标/理论覆盖，不作为 VCS exhaustive 结论。
- `Campaign SPFM/LFM` 主报 required campaign + equivalence mapping：Register 99.37%，Logic 92.17%。
- 文档中写“满足赛题建议目标的工程论证”，不要写“ISO 26262 认证已完成”。

### P2：文档内部需要再人工快查的点

由于 docx 是最终评分核心，交前需要快速打开检查以下关键词和表格：

- `1-AXI_Safety_Island_设计文档.docx`：feature 列表是否覆盖 AXI read/write、outstanding、OK/Error response、wrap/incr burst、len>=16、5 路 master、1 路 slave、2/3 路 fault 输出。
- `3-失效模型描述_完整提交版.docx`：是否分别列出 memory/register 与 digital logic 的故障点、故障后果、保护机制、检测/纠错效果。
- `4-安全机制分析及设计.docx`：TMR、shadow/inverse、CRC/E2E、KAT、heartbeat、timeout、write-verify、pending/outstanding/FIFO 保护是否和 RTL 文件名对应。
- `5-注错仿真计划.docx`：不要写 full campaign 已执行；要写 baseline/batch/required campaign + full optional。
- 所有 docx 中如出现 `117K bits`、`594 bit sweep 100% detected`、`SPFM/LFM=100% 正式证明`，必须改成当前一致口径：`220439 rows inventory；Register 99.37%；Logic 92.17%；full per-row 未执行；Design-intent 与 campaign mapping 分开说`。

## 正式 zip 不提交内容

不要提交：

- `.cursor/`
- `.ai-bridge/`
- `tools/__pycache__/`
- `*.pyc`
- `sim/work/`
- `sim/work_full/`
- `simv*`
- `csrc/`
- `*.daidir/`
- `DVEfiles/`
- `novas.*`
- `ucli.key`
- `*.fsdb`, `*.vpd`, `*.vcd` 等大型波形
- 临时 UCLI：`sim/work/ucli/`
- 单条中间结果：`sim/work/fault_results/`
- `.ai-bridge/implementation-diff.patch` 等 agent 协作文件

可以保留但要说明：

- `fault_campaign/legacy_logic_signal_list.csv`：作为 `gen_fault_lists.py` 输入，不能删。
- `sim/fault_injection/reports/full/README.txt`：如存在，用来说明 full campaign 未执行；不要放大结果。
- `tools/probe_faultsim_tool.sh`, `tools/run_logic_faultsim.sh`：可作为可选 Test-Faultsim/TetraMAX 探测脚本；不能作为主验证依据。

## 建议最终 README 摘要口径

建议 README 验证结果表改成：

| 项目 | 状态 | 正式口径 |
|------|------|----------|
| 功能仿真 | 已完成但需补日志 | VCS T-2022.06 PASS 34/34；补 full_run.log/full_compile.log 最稳 |
| 代码覆盖率 | 摘要存在，证据不足 | 当前只有 line_coverage_summary；需补 build.vdb/urgReport/logs，或改成可复现生成 |
| 注错 baseline | 已完成 | 54 cases，保护率 92% |
| 注错 batch | 已完成 | 610 cases，保护率 99% |
| Required campaign | 已完成 | 286 representative faults；corrected=31, detected=82, latent=1, safe=142, functional undetected=0, tool/TB error=30 |
| Register/memory coverage | 已完成 | 213798 inventory，99.37% covered by representative + equivalence mapping |
| Digital logic coverage | 部分完成/工程达标 | 6641 inventory，92.17% covered by representative + equivalence mapping |
| Full per-row campaign | 未执行 | 220439 rows per-row exhaustive campaign 未执行，脚本保留 |

## 建议最终执行顺序

1. 先在 VM 重跑或补齐 `bash run_functional.sh` 生成的 functional logs / coverage。
2. 修 `tools/analyze_fi_report.py` 的 error 分类。
3. 重新生成 `fault_campaign_safety_report.csv` 与 detail。
4. 修 README 三处：RTL 数量、功能仿真状态、campaign/error 口径、functional coverage 口径。
5. 修 `scripts/环境运行说明.md`：fault-all 实际流程、Strict/Engineering 公式、coverage HTML/build.vdb 说明、summary 不是历史数据。
6. 快速打开 5 个 docx，搜索并改掉所有过期夸张口径。
7. 清理 zip 黑名单文件。
8. 最终只做一次轻量检查：
   - `rtl/safety_island_top.f` 文件都存在。
   - README 里的文件路径都存在。
   - `sim/functional/regression_summary.txt` 是 PASS 34/34。
   - `sim/functional/logs/full_run.log` 最好存在。
   - `diagnostic_coverage_summary.txt` 与 `fault_campaign_safety_report.csv` 对 `error/undetected` 口径一致。
   - 不包含 `.cursor/.ai-bridge/__pycache__/sim/work/simv/csrc/波形`。

## 给后续 agent 的实施约束

- 优先补证据链和改文本，不要重构 RTL。
- 不要把 failed/partial 指标藏起来；要解释口径，别硬吹。硬吹=给评委递刀。
- 所有数字只使用当前仓库已有报告中的数字，不能脑补。
- 每改一处统计口径，必须同步 README、运行说明、summary、CSV，避免“一个项目四套宇宙”。
- 完成后更新 `.ai-bridge/agent-status.md`，记录 touched files、checks、remaining blockers。
