# AXI Safety Island 工程概览

> **项目名称**: AXI Safety Island (安全岛) — ASIL-D 功能安全监控IP  
> **合规标准**: ISO 26262-5 ASIL-D | AXI4 协议 (ARM IHI0022H)  
> **更新日期**: 2026-06-30

---

## 1. 项目简介

AXI Safety Island 是一个基于 AXI4 协议的硬件安全监控 IP 核，用于周期性读取并校验系统中关键安全寄存器。该 IP 通过 1 路 AXI4-Lite Slave 配置接口接收监控参数，通过 5 路 AXI4 Read Master 监控接口读取外部安全寄存器，并对读回数据进行 Mask+OR 累加、预期值比较、CRC E2E 校验等故障判定，最终输出三类故障检测信号。

### 核心能力

| 能力 | 说明 |
|------|------|
| **系统故障检测** | Mask+OR / Expected 值比较 / AXI 响应错误 / 超时检测 |
| **安全岛自身故障检测** | Shadow/反码 / FSM 翻转 / TMR 表决 / 心跳自检 / Known-Answer Test |
| **潜在故障检测** | Stuck-at 阈值 / 间歇性故障恢复检测 / Shadow 累积失配 |
| **AoU 总线校验** | CRC-8 / CRC-16 R 通道 E2E 校验（参数化 CRC_WIDTH） |
| **故障注入平台** | 38 baseline + 594 bit sweep，100% 检测率 |

### 验证状态

| 平台 | Full TB | FI Baseline | FI Bit Sweep |
|------|:-------:|:-----------:|:------------:|
| ModelSim (Win) | 34/34 PASS | 38/38 DETECTED | 594/594 DETECTED |
| VCS T-2022.06 (Linux) | 34/34 PASS | 38/38 DETECTED | 594/594 DETECTED |
| Icarus 0.9.7 | 17/22 (77%) | — | — |

---

## 2. 目录结构

```
RTL/
├── rtl/                              RTL 设计源码
│   ├── AXI/                          可复用 AXI4 master/slave 基础模块
│   │   ├── axi_master.v
│   │   └── axi_slave.v
│   ├── safety_island_top.v           新顶层（整合版）— 主设计入口
│   ├── safety_island_core_logic.v    核心调度与数据流控制
│   ├── safety_island_axi_config_slave.v  AXI4-Lite Slave 配置寄存器
│   ├── safety_island_axi_read_engine.v   AXI4 Read Master 读引擎 (×5实例)
│   ├── safety_island_fault_detector.v   故障检测与分类
│   ├── safety_island_heartbeat.v     心跳自检模块
│   ├── tmr_voter.v                   TMR 三模冗余表决器
│   ├── axi_safety_island_pkg.vh      公共定义头文件 (参数/地址/宏)
│   ├── safety_island_top.f           RTL 文件列表 (综合/仿真用)
│   └── ...                           兼容版/融合版模块
│
├── tb/                               验证平台 (Testbench)
│   ├── AXI/                          AXI 单元级 testbench
│   ├── tb_safety_island_top_full.v   顶层全功能集成测试 (34 场景)
│   ├── tb_safety_island_fault_injection.v  故障注入测试平台
│   ├── tb_safety_island_fault_detector.v   故障检测模块单元测试
│   ├── axi_slave_mem_model.v         AXI Slave 存储模型 BFM
│   └── ...                           模块级/单元级 testbench
│
├── sim/                              仿真脚本
│   ├── modelsim/                     ModelSim .do 脚本
│   │   ├── AXI/                       AXI 单元测试脚本
│   │   ├── run_safety_island_top_full_tb.do
│   │   └── run_safety_island_fault_injection_tb.do
│   └── vcs/                          VCS/Verdi Linux 仿真模板
│       ├── Makefile                   VCS 编译-仿真自动化
│       └── README.md
│
├── tools/                            Python 自动化工具链
│   ├── run_tests.py                  Icarus 一键测试运行器
│   ├── run_fi_sweep.py              ModelSim 批量故障注入自动化
│   ├── gen_fi_bit_list.py           故障注入 bit 清单生成器
│   ├── gen_safety_report.py         安全指标 (SPFM/LFM) 报告生成
│   └── analyze_fi_report.py         故障注入结果分析器
│
├── docs/                             设计文档
│   ├── 工程概览/                     本目录 — 工程概览文档
│   ├── 设计测试文档.md               赛题需求与测试覆盖对照
│   ├── 设计需求对照检查_AXI_core.md  详细需求符合性检查
│   ├── 失效模型分析.md               Memory/寄存器/数字逻辑失效分析
│   ├── 测试方案与报告.md             完整测试方案与验证结果
│   ├── VCS_Verdi仿真.md             VCS/Verdi 仿真环境说明
│   ├── 赛题评分细则.md               赛题评分标准
│   ├── 项目计划与进度.md             项目计划与进度跟踪
│   └── fusion_baseline_2026-06-25.md 融合基线文档
│
├── meeting/                          会议记录与日程
├── result/wavedebug/                 波形调试结果
└── README.md                         项目顶层说明
```

---

## 3. 架构总览

### 3.1 顶层架构图

```
                          ┌─────────────────────────────────────────┐
                          │          safety_island_top              │
                          │                                         │
   S_AXI (AXI4-Lite) ──► │  ┌─────────────────────────────────┐    │
   (1路配置接口)          │  │  safety_island_axi_config_slave │    │
                          │  │  · 配置寄存器 + Shadow/反码     │    │
                          │  │  · TMR 关键控制位               │    │
                          │  │  · Write-Verify 写保护          │    │
                          │  └──────────┬──────────────────────┘    │
                          │             │ cfg_* 总线                 │
                          │  ┌──────────▼──────────────────────┐    │
                          │  │  safety_island_core_logic        │    │
                          │  │  · 扫描调度 FSM (TMR)            │    │
                          │  │  · 地址生成 + Outstanding 管理    │    │
                          │  │  · Pending FIFO + 安全自检       │    │
                          │  │  · KAT Known-Answer Test         │    │
                          │  └──┬───────────────┬──────────────┘    │
                          │     │ read_req ×5   │ fd_resp            │
                          │  ┌──▼──────────┐ ┌─▼──────────────────┐ │
                          │  │ Read Engine │ │ fault_detector     │ │
                          │  │  ×5 (gen)   │ │ · Mask+OR 累加     │ │
                          │  │ · AR/R 通道 │ │ · Expected 比较    │ │
                          │  │ · CRC E2E   │ │ · Stuck-at 检测    │ │
                          │  │ · RSP FIFO  │ │ · Latent 故障      │ │
                          │  │ · Shadow    │ │ · 事件分类上报     │ │
                          │  └──┬──────────┘ └─┬──────────────────┘ │
                          │     │              │                     │
                          │  ┌──▼──────────────▼──────────────────┐ │
                          │  │  safety_island_heartbeat           │ │
                          │  │  · 周期性测试注入                   │ │
                          │  │  · fault_detect 路径自检            │ │
                          │  └────────────────────────────────────┘ │
                          │                                         │
   M_AXI ×5 ◄─────────────┤  (5路 AXI4 Read Monitor)               │
   fault_detect ──────────┤  系统故障检测                           │
   safety_island ─────────┤  安全岛自身故障                          │
   latent_fault ──────────┤  潜在故障检测                            │
                          └─────────────────────────────────────────┘
```

### 3.2 数据流路径

```
配置阶段:
  S_AXI Write → Config Slave (Shadow/反码校验)
              → cfg_*_flat 总线 → Core Logic + Fault Detector

扫描阶段:
  Core Logic FSM → read_req[mi] → Read Engine[mi]
                                 → AXI AR 通道 → 外部 Slave
  AXI R 通道 ← 外部 Slave 返回数据
             → Read Engine (CRC 校验 + Slot 管理 + RSP FIFO)
             → Core Logic (地址/预期值/Mask/索引 传递)
             → Fault Detector (Mask+OR + Expected 比较 + Stuck 判定)
             → 故障事件输出

安全自检:
  Heartbeat → test_inject → Core Logic → safety_island_fault_detect
                                      → Heartbeat 验证检测路径通畅
```

---

## 4. 模块清单

### 4.1 主设计模块 (5 核心 + 1 心跳 + 1 TMR)

| 模块 | 文件 | 功能描述 | 安全机制 |
|------|------|---------|---------|
| **顶层集成** | `safety_island_top.v` | 实例化所有子模块，信号展平与路由，顶层 TMR 故障输出 | TMR 关键路径，DONT_TOUCH 约束 |
| **配置 Slave** | `safety_island_axi_config_slave.v` | AXI4-Lite Slave，配置寄存器读写，配置锁 + 非法检测 | Shadow/反码，TMR 关键位，Write-Verify |
| **核心逻辑** | `safety_island_core_logic.v` | 扫描调度 FSM，地址生成，Outstanding 管理，数据路由，KAT | TMR FSM，Shadow 累加器，索引/指针范围检查 |
| **读引擎** | `safety_island_axi_read_engine.v` | AXI4 Read Master，Slot 管理，CRC E2E 校验，Timeout 检测 | Shadow/反码 Slot，CRC 双路计算比对，指针范围检查 |
| **故障检测** | `safety_island_fault_detector.v` | Mask+OR 累加，Expected 值比较，Stuck-at 阈值，Latent 检测 | Shadow 累加器，事件 Shadow，错误码保护 |
| **心跳自检** | `safety_island_heartbeat.v` | 周期性测试注入，fault_detect 输出路径完整性验证 | FSM Shadow/反码，故障自锁 |
| **TMR 表决器** | `tmr_voter.v` | 三模冗余多数表决器，mismatch 指示 | 纯组合逻辑，2-out-of-3 |

### 4.2 兼容版/融合版模块

| 模块 | 文件 | 说明 |
|------|------|------|
| 融合顶层 | `axi_safety_island_core.v` | 替代顶层，9 模块集成 |
| 独立故障检测 | `fault_detector.v` | 融合版用 |
| 故障状态管理 | `fault_status_manager.v` | 故障分类与状态 |
| 监控调度器 | `monitor_scheduler.v` | 扫描调度与遍历 |
| 读数据处理 | `read_data_processor.v` | Mask+OR 累加 |
| 配置校验 | `config_checker.v` | 独立配置合法性校验 |

### 4.3 可复用基础模块 (AXI/)

| 模块 | 文件 | 说明 |
|------|------|------|
| AXI Master | `AXI/axi_master.v` | 通用 AXI4 Master |
| AXI Slave | `AXI/axi_slave.v` | 通用 AXI4 Slave |

---

## 5. 关键设计参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `NUM_MASTERS` | 5 | 监控 Master 通道数 |
| `NUM_ENTRIES` | 64 | 每通道偏移地址条目数 |
| `ADDR_W` | 32 | 地址位宽 |
| `DATA_W` | 64 | 数据位宽 |
| `ID_W` | 4 | AXI ID 位宽 |
| `TIMEOUT_CYCLES` | 1024 | AXI 读超时周期 |
| `SUPPORT_OUTSTANDING` | 1 | Outstanding 支持使能 |
| `MAX_OUTSTANDING` | 4 | 最大 Outstanding 事务数 |
| `STUCK_AT_THRESHOLD` | 10 | Stuck-at 检测连续轮次阈值 |
| `CRC_WIDTH` | 16 (可配 8) | CRC 校验位宽 |
| `HEARTBEAT_INTERVAL` | 1024 | 心跳自检间隔周期 |

---

## 6. ASIL-D 安全机制汇总

| 机制 | 实现位置 | 保护类型 | 检测延迟 |
|------|---------|:------:|:-------:|
| **TMR 三模冗余** | FSM 状态/故障输出/配置锁 | 纠错 | 1 cycle |
| **Shadow/反码** | 配置寄存器 / Slot 数据 / 事件寄存器 | 探测 | 组合/1 cycle |
| **CRC-8/16 E2E** | AR 签名 + R 通道 CRC 校验 | 探测 | 1 R beat |
| **心跳自检** | fault_detect 输出路径完整性 | 探测 | ≤10 cycles |
| **KAT** | 预扫描已知寄存器路径验证 | 探测 | KAT 扫描周期 |
| **Write-Verify** | S_AXI 写后读 Shadow 一致性 | 探测 | 写事务完成 |
| **Stuck-at 阈值** | 连续 N 轮 mismatch 判定 | 探测 | N 轮扫描 |
| **Latent 检测** | 间歇性故障恢复追踪 | 探测 | 按扫描周期 |
| **FSM 自检** | 状态合法性/反码/反转检查 | 探测 | 0-1 cycle |
| **范围检查** | 索引/指针/计数器溢出 | 探测 | 0-1 cycle |

---

## 7. 故障编码体系

### 故障类型

| 编码 | 类型 | 说明 |
|:----:|------|------|
| `4'h0` | 外部寄存器 mismatch | Mask+OR 或 Expected 比较不匹配 |
| `4'h1` | AXI 超时 | Master 读超时未响应 |
| `4'h2` | AXI 错误响应 | SLVERR/DECERR |
| `4'h3` | 非法配置 | burst/interval/地址非法 |
| `4'h4` | 内部 stuck-at | 连续多轮 mismatch |
| `4'h5` | 内部瞬时翻转 | 单次 flip 后恢复 |
| `4'h6` | AoU 校验错误 | CRC mismatch |
| `4'h7` | 潜在故障 | 间歇性恢复检测 |
| `4'h8` | 写保护违规 | lock 后写操作 |
| `4'h9` | 地址非对齐 | 基地址/偏移地址非对齐 |
| `4'hA` | 地址越界 | 配置地址超出有效范围 |

### 故障分类

| 编码 | 分类 | 说明 |
|:----:|------|------|
| `2'b00` | CORRECTED | 故障被 TMR 自动纠正 |
| `2'b01` | DETECTED | 故障被 fault_detect 捕获 |
| `2'b10` | LATENT_DETECTED | 故障被 latent_fault_detect 捕获 |
| `2'b11` | NOT_DETECTED | 故障未被检测到 |

---

## 8. 配置寄存器映射

| 地址 | 名称 | 说明 |
|------|------|------|
| `0x0000` | CTRL | 控制寄存器 (enable/scan_once/lock/clear/fault_clear) |
| `0x0008` | READ_INTERVAL | 扫描间隔 (时钟周期) |
| `0x0010` | STATUS | 状态寄存器 (busy/done/fault events) |
| `0x0018` | FAULT_RESULT | Mask+OR 累加结果 |
| `0x0020` | ERROR_CODE | 错误码 |
| `0x0028` | INDEX_STATUS | 当前 master/entry 索引 |
| `0x0030` | OUTSTANDING | 当前 outstanding 事务数 |
| `0x0038` | KAT_CTRL | KAT 控制 (enable/addr/expected/mask) |
| `0x0100 + n×8` | BASE[n] | Master n 基地址 (n = 0..4) |
| `0x1000 + m×0x1000 + e×0x20` | ENTRY | Master m Entry e 配置区 (offset/mask/burst/expected) |

---

## 9. 快速参考链接

- [模块架构详解](模块架构详解.md)
- [验证平台说明](验证平台说明.md)
- [工具链说明](工具链说明.md)
- [快速入门指南](快速入门指南.md)
- [项目 README](../../README.md)
- [设计测试文档](../设计测试文档.md)
- [失效模型分析](../失效模型分析.md)
- [需求对照检查](../设计需求对照检查_AXI_core.md)
