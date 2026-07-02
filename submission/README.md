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
├── fault_campaign/           注错配置 CSV
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

## 验证结果 (VM 实测 2026-07-02)

| 项目 | 结果 |
|------|------|
| 功能仿真 | 34/34 PASS |
| 注错基线 | 54/54, 保护率 100% |
| 注错全量 bit | 610/610, 保护率 100% |
| 代码行覆盖率 | build.vdb 已生成 (Line/Tgl/Cond/FSM) |
| SPFM / LFM | 100% / 100% |

结果文件:
- sim/functional/logs/full_run.log
- sim/functional/coverage/build.vdb
- sim/fault_injection/logs/fault_run.log, batch_run.log
- sim/fault_injection/diagnostic_coverage_summary.txt

## RTL 架构

```
safety_island_top
├── safety_island_axi_config_slave   配置 + Shadow
├── safety_island_core_logic         扫描调度 + KAT
├── safety_island_fault_detector     故障分类
├── safety_island_heartbeat          心跳自检
├── safety_island_axi_read_engine×5  读引擎 + CRC-16
└── tmr_voter                        TMR 表决
```

## 关键参数

| 参数 | 值 |
|------|-----|
| NUM_MASTERS | 5 |
| NUM_ENTRIES | 64 |
| ADDR_W / DATA_W | 32 / 64 |
| CRC_WIDTH | 16 |
| MAX_OUTSTANDING | 4 |
