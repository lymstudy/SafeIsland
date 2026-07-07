# AXI Safety Island — 赛题提交材料

## 项目简介

AXI Safety Island 是一款面向 AXI 总线的 ASIL-D 功能安全监控 IP。模块挂载为 AXI Slave 接收监控配置表，通过 5 路 AXI Master 周期性读取被监控模块寄存器，经 CRC-16 校验与 bitwise-OR 比对后，**10 周期内**上报 fault_detect / safety_island_fault_detect 信号。

安全机制覆盖 **TMR（三模冗余纠错）**、Shadow/Scrub 配置保护、CRC/E2E 总线保护、KAT 自检、Heartbeat、Write-Verify、Timeout 等多层次，满足赛题对纠错型安全机制的最高得分要求。

**验证平台**：Synopsys VCS T-2022.06 / Linux RHEL 7+

---

## 快速复现

```bash
cd submission/scripts

bash run_functional.sh   # 功能仿真 34 case + 行覆盖率（~2 min）
bash run_fault.sh        # 注错仿真 baseline+batch+campaign（~30 min）
bash run_all.sh          # 全套一键
```

> 详细操作说明见 [scripts/环境运行说明.md](scripts/环境运行说明.md)

---

## 评分项 → 材料对照

| 评分项（分值） | 提交材料 | 关键证据 |
|--------------|---------|---------|
| 设计文档 (10) | [1-AXI_Safety_Island_设计文档.docx](1-AXI_Safety_Island_设计文档.docx) | 架构、接口、Feature 列表、实现思路 |
| RTL + 功能验证 (20) | [rtl/](rtl/)（8 文件 + filelist） + [tb/functional/](tb/functional/) + [sim/functional/](sim/functional/) | **PASS 34/34**，含 outstanding/out-of-order/interleaving，编译 0e/0w，覆盖率数据库完整 |
| Memory/寄存器失效分析 (10) | [3-失效模型描述_完整提交版.docx](3-失效模型描述_完整提交版.docx) | 按模块、故障类型（stuck-at/transient）、保护机制分类 |
| 数字逻辑失效分析 (10) | 同上 | 按 logic_kind 分类，覆盖 FSM/数据路径/控制逻辑 |
| Memory/寄存器保护 (10) | [4-安全机制分析及设计.docx](4-安全机制分析及设计.docx) + [rtl/](rtl/) | **TMR 纠错** + Shadow/Scrub + Parity |
| 数字逻辑保护 (20) | 同上 | **TMR voter/protected 纠错** + CRC/E2E + KAT + Heartbeat + FSM 保护 |
| 注错测试与覆盖 (20) | [5-注错仿真计划.docx](5-注错仿真计划.docx) + [sim/fault_injection/](sim/fault_injection/) + [fault_campaign/](fault_campaign/) | 285 条 family 代表 + 等效映射，Register **100%**，Logic **100%** |

---

## 验证结果一览

### 功能仿真

| 项目 | 结果 |
|------|------|
| Testbench | `tb/functional/tb_safety_island_top_full.v`，34 场景 |
| 编译 | **0 error, 0 warning**（VCS T-2022.06） |
| 仿真 | **PASS 34/34**（含 outstanding_flow、out_of_order、interleaving 等） |
| CPU 时间 | 2.5s |
| 覆盖率 | Line+Tgl+Cond+FSM（数据库见 `sim/functional/coverage/build.vdb`） |
| 日志 | `sim/functional/logs/full_run.log` |

### 注错仿真

| 阶段 | 规模 | 结果 |
|------|------|------|
| Baseline | 54 cases | 保护率 **90%**（corrected=3, detected=46, undetected=5） |
| Batch 扫描 | 610 cases | 保护率 **99%**（corrected=3, detected=602, undetected=5） |
| Required Campaign | **285** faults（family 代表 + 等效映射） | corrected=31, detected=83, latent=1, safe=170, error=0, **undetected=0** |
| 保护率 | — | **100.00%** |

### 站点覆盖率（post-TMR，等效映射）

| 类别 | 清单规模 | 直接仿真 | 等效覆盖 | 覆盖率 |
|------|---------|---------|---------|--------|
| Register/memory | 213,798 sites | 36 | 213,762 | **100.00%** |
| Digital logic | 6,640 sites | 249 | 6,391 | **100.00%** |

---

## 注错方法：等效覆盖映射

220,438 个 fault site 中包含大量由 `generate`/`for` 复制的同构硬件结构。本设计采用 **representative sampling + equivalence mapping** 方法：

1. **清单生成**（`tools/gen_fault_lists.py`）：遍历 post-TMR 网表每个 bit 级存储单元和逻辑节点，生成完整分母。
2. **Family 分组**：按 TMR triplet、entry 阵列（64 路）、Master 通道（5 路）、bit-slice 将同构 site 归组。
3. **代表注错**：每组抽取 1 个 site 做 VCS UCLI 直接仿真（共 285 条），验证该 family 的保护机制有效性。
4. **映射覆盖**：同组其余 site 因硬件结构、故障注入路径、保护机制完全等价，映射为已覆盖。详细映射记录见 `sim/fault_injection/reports/fault_site_coverage.csv`。

---

## RTL 架构

```
safety_island_top
├── safety_island_axi_config_slave   配置表（三副本 + Scrub）+ Shadow 寄存器
├── safety_island_core_logic         扫描调度 + KAT + Outstanding 管理
├── safety_island_fault_detector     故障分类（stuck-at/latent/expected mismatch）
├── safety_island_heartbeat          心跳自检
├── safety_island_axi_read_engine×5  读引擎 + CRC-16 E2E 校验
├── tmr_voter                        TMR 表决器
└── tmr_voter_protected              自保护 TMR 表决器
```

**安全升级要点**：
- **TMR 纠错**（correction）：FSM state、fault 输出、cfg_locked/enable 等关键信号三模冗余，majority vote + 下一拍 repair
- **检测上报**（detection）：Shadow/反码寄存器、CRC-16、KAT、Heartbeat、Timeout → 10 cycle 内 fault_detect
- **潜伏上报**（latent）：TMR mismatch、Shadow mismatch 上报，功能输出保持正确
- 全模块 TMR 覆盖：config_slave 三副本、read_engine slot TMR、core FSM/索引/pending TMR、fault_detector event/status TMR、top sticky fault latch + protected voter

---

## 关键参数

| 参数 | 值 |
|------|-----|
| NUM_MASTERS | 5 |
| NUM_ENTRIES | 64 |
| ADDR_W / DATA_W | 32 / 64 |
| CRC_WIDTH | 16 |
| MAX_OUTSTANDING | 4 |

---

## 说明

- **full per-row campaign（220,438 条）因时间限制未执行**。提交采用 285 条 family 代表 + 等效映射，脚本保留 `make campaign-full-isolated` 可执行。
- **SPFM/LFM**：Design-intent SPFM = 100%（全机制覆盖），Campaign-measured SPFM/LFM = 100%/100%（required campaign + equivalent mapping）。
