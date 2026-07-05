# AXI Safety Island — 赛题提交材料

项目名称: AXI Safety Island (安全岛) — ASIL-D 功能安全监控 IP  
验证平台: Synopsys VCS T-2022.06 (Linux)

## 提交目录

```
submission/
├── README.md                 本文件
├── 1-设计文档/               设计文档.docx
├── 2-功能仿真/               功能仿真计划.docx
├── 3-失效模型/               失效模型描述.docx
├── 4-安全机制/               安全机制分析及设计.docx
├── 5-注错仿真/               注错仿真计划.docx
├── rtl/                      RTL 源码 (7 模块 + filelist)
├── tb/
│   ├── functional/           功能仿真 testbench
│   └── fault_injection/      注错仿真 testbench
├── scripts/                  VCS 脚本 + 环境运行说明（仅脚本，无生成物）
├── sim/
│   ├── functional/           功能仿真结果 + 行覆盖率
│   └── fault_injection/      注错结果 + 诊断覆盖率
├── fault_campaign/           注错配置 CSV + post-TMR 故障清单
│   ├── Register_fault_list.csv
│   ├── Logic_fault_list.csv
│   ├── fault_smoke_tmr.csv
│   └── README.md
└── tools/                    安全报告生成脚本
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

# 仅功能仿真 (34 case + 行覆盖率)
bash run_functional.sh

# 仅注错仿真 (54 + 610 case)
bash run_fault.sh

# 全套
bash run_all.sh
```

详细说明见 scripts/环境运行说明.md

## 验证结果

| 项目 | 状态 | 说明 |
|------|------|------|
| 功能仿真 | 待重跑 | RTL TMR 升级后需 VM 回归 34 case |
| 注错基线 (54) | 历史参考 | 2026-07-02: 保护率 100% (corrected=3) |
| 注错全量 bit (610) | 历史参考 | legacy 路径，待 FI TB 扩展 TMR 目标 |
| post-TMR 故障清单 | 已更新 | Register 208182 + Logic 6641 = 214823 rows |
| Campaign SPFM/LFM | 待重跑 | 见 `fault_campaign/safety_metrics_report.csv` |

结果与工具:
- `sim/fault_injection/diagnostic_coverage_summary.txt` — 诊断覆盖率摘要
- `fault_campaign/Register_fault_list.csv` — post-TMR 寄存器故障清单
- `fault_campaign/Logic_fault_list.csv` — 逻辑故障清单
- `fault_campaign/fault_smoke_tmr.csv` — 升级后 smoke 用例
- `tools/gen_fault_lists.py` / `analyze_fi_report.py` / `gen_safety_report.py`

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
