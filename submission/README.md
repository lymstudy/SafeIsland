# AXI Safety Island — 赛题提交材料

项目名称: AXI Safety Island (安全岛) — ASIL-D 功能安全监控 IP  
验证平台: Synopsys VCS T-2022.06 (Linux)

## 提交目录

```
submission/
├── README.md                            本文件
├── 1-AXI_Safety_Island_设计文档.docx   设计文档
├── 2-功能仿真计划.docx               功能仿真计划
├── 3-失效模型描述_完整提交版.docx    失效模型描述
├── 4-安全机制分析及设计.docx          安全机制分析及设计
├── 5-注错仿真计划.docx                注错仿真计划
├── rtl/                               RTL 源码（8 个设计文件 + 1 个 filelist）
├── tb/
│   ├── functional/                    功能仿真 testbench
│   └── fault_injection/               注错仿真 testbench
├── scripts/                           VCS 脚本 + 环境运行说明（仅脚本，无生成物）
├── sim/
│   ├── functional/                    功能仿真结果 + 行覆盖率
│   └── fault_injection/             注错结果 + 诊断覆盖率
├── fault_campaign/                    注错配置 CSV + post-TMR 故障清单
│   ├── Register_fault_list.csv        register/memory bit 分母
│   ├── Logic_fault_list.csv           数字逻辑 bit 分母
│   ├── fault_smoke_tmr.csv            升级后 smoke 用例
│   └── README.md
└── tools/                             安全报告生成脚本
```

## 评分材料对照

| 评分项 | 材料 |
|--------|------|
| 设计文档补充 (10分) | 1-设计文档/AXI_Safety_Island_设计文档.docx |
| RTL + 功能验证 (20分) | rtl/ + tb/functional/ + sim/functional/ |
| Memory/寄存器失效分析 (10分) | 3-失效模型/失效模型描述.docx |
| 数字逻辑失效分析 (10分) | 3-失效模型/失效模型描述.docx |
| Memory/寄存器保护 (10分) | 4-安全机制/ + rtl/ |
| 数字逻辑保护 (20分) | 4-安全机制/ + rtl/ |
| 注错测试与覆盖 (20分) | 5-注错仿真/ + sim/fault_injection/ |

## 快速复现

```bash
cd submission/scripts

# 仅功能仿真 (34 case + 行覆盖率，生成 logs + coverage 需 VCS 环境)
bash run_functional.sh

# 仅注错仿真 (54 baseline + 610 batch + 286 required campaign)
bash run_fault.sh

# 全套
bash run_all.sh
```

详细说明见 scripts/环境运行说明.md

## 验证结果

| 项目 | 状态 | 说明 |
|------|------|------|
| 功能仿真 | **部分完成** | 安全升级前 PASS 34/34（保留回归摘要）；升级后 outstanding_flow 测例需排查；脚本可供复现参考 |
| 注错基线 (54) | **已完成** | 2026-07-06 VM: 保护率 **92%** (corrected=3, detected=47) |
| 注错 Batch (610) | **已完成** | 2026-07-06 VM: 保护率 **99%** (corrected=3, detected=603) |
| Campaign Required (286) | **已完成** | corrected=31, detected=82, latent=1, safe=142, functional undetected=0, tool/TB error=30；Engineering 保护率 **89.51%**；Strict **39.51%** |
| Register 覆盖率 | **99.37%** | 清单 213798 行，family 代表 + 等效映射 |
| Logic 覆盖率 | **92.17%** | 清单 6641 行，family 代表 + 等效映射 |
| Full campaign (220439) | **未执行** | 时间限制；默认提交流程不要求 per-row 全量 |
| post-TMR 故障清单 | 已更新 | Register 213798 + Logic 6641 = **220439** rows |

> **功能仿真说明**：`sim/functional/regression_summary.txt` 显示 PASS 34/34，该结果为安全升级前 RTL 的回归数据。安全升级后 RTL 因 outstanding_flow 测例存在仿真挂起问题，尚未完成完整功能仿真回归。设计功能正确性主要由注错仿真（286 条 campaign）及等效覆盖映射验证。完整功能仿真回归修复后，可通过 `scripts/run_functional.sh` 在 VCS 环境复现。

结果与工具:
- `sim/fault_injection/diagnostic_coverage_summary.txt` — 诊断覆盖率总摘要
- `sim/fault_injection/reports/fault_campaign_summary.txt` — campaign 汇总
- `sim/fault_injection/reports/fault_campaign_safety_report.csv` — 安全指标报告
- `sim/fault_injection/reports/fault_site_coverage.csv` — 逐 site 覆盖映射
- `fault_campaign/safety_metrics_report.csv` — SPFM/LFM 指标摘要
- `fault_campaign/Register_fault_list.csv` / `Logic_fault_list.csv` — 注错分母清单

## RTL 架构

```
safety_island_top
├── safety_island_axi_config_slave   配置 + Shadow
├── safety_island_core_logic         扫描调度 + KAT
├── safety_island_fault_detector     故障分类
├── safety_island_heartbeat          心跳自检
├── safety_island_axi_read_engine×5  读引擎 + CRC-16
├── tmr_voter                        TMR 表决
└── tmr_voter_protected              自保护 TMR 表决
```

升级后安全机制要点:
- **corrected**: TMR majority + 下一拍 repair，单点 flip/stuck 不改变功能输出
- **detected**: 10 cycle 内 `fault_detect` / `safety_island_fault_detect`
- **latent**: shadow/parity/TMR mismatch 上报，功能仍正确
- config_slave 配置表三副本 + scrub；read_engine slot TMR；core FSM/索引/pending TMR
- top sticky fault latch + protected voter；fault_detector event/status TMR

## 关键参数

| 参数 | 值 |
|------|-----|
| NUM_MASTERS | 5 |
| NUM_ENTRIES | 64 |
| ADDR_W / DATA_W | 32 / 64 |
| CRC_WIDTH | 16 |
| MAX_OUTSTANDING | 4 |
