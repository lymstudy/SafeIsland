# AXI Safety Island — VCS/Verdi 仿真复现指南

## 环境要求

| 工具 | 版本要求 | 说明 |
|------|----------|------|
| VCS | T-2022.06+ | Verilog/SystemVerilog 仿真器 |
| Verdi | T-2022.06+ | 波形查看器 |
| OS | Linux (RHEL/CentOS 7+) | VCS/Verdi 运行环境 |

已验证环境：Linux eda 3.10 (CentOS 7), VCS T-2022.06, Verdi T-2022.06

---

## 快速开始

```bash
cd SafeIsland/sim/vcs

# 一键跑全部回归（功能 + 故障注入）
make regress

# 分步执行：
make full       # 功能仿真, 34 case
make fault      # 故障注入基线, 38 case
make batch      # 故障注入全量 bit 扫描, 594 case
```

---

## Makefile 目标说明

| 目标 | 说明 | 用例数 |
|------|------|:--:|
| `all` / `regress` | 依次运行 `full` + `fault` + `fdet` | 34 + 38 + 18 |
| `full` | 功能仿真：编译 + 运行 | 34 |
| `full-comp` | 仅编译功能仿真 | — |
| `full-run` | 仅运行功能仿真 | — |
| `fault` | 故障注入基线：编译 + 运行 | 38 |
| `fault-comp` | 仅编译故障注入 | — |
| `fault-run` | 仅运行故障注入基线 | — |
| `batch` | 故障注入全量 bit 扫描 | 594 |
| `batch-comp` | 仅编译 batch 模式 | — |
| `batch-run` | 仅运行 batch 扫描 | — |
| `fdet` | fault_detector 单元测试 | 18 |
| `verdi-full` | Verdi 打开功能仿真波形 | — |
| `verdi-fault` | Verdi 打开故障注入波形 | — |
| `clean` | 清理所有生成文件 | — |

---

## 预期输出

### make full（34 case）
```
PASS: safety_island_top full test completed, cases=34
```

### make fault（38 case）
```
FI_SUMMARY: total=38 corrected=0 detected=38 undetected=0 protection_rate=100%
PASS: safety_island fault injection campaign completed
```

### make batch（594 case）
```
FI_SUMMARY: total=594 corrected=0 detected=594 undetected=0 protection_rate=100%
PASS: safety_island fault injection campaign completed
```

---

## 波形文件

仿真自动生成 FSDB 波形到 `waves/` 目录：
- `waves/full.fsdb` — 功能仿真波形
- `waves/fault_injection.fsdb` — 故障注入波形

FSDB dump 由 `` `ifdef FSDB `` 编译控制（已在 Makefile 的 `VCS_OPTS` 中默认启用）。

---

## 查看波形

```bash
make verdi-full    # 功能仿真波形
make verdi-fault   # 故障注入波形
```

或手动启动 Verdi：
```bash
verdi -ssf waves/full.fsdb -sv -f ../../rtl/safety_island_top.f \
      ../../tb/tb_safety_island_top_full.v -top tb_safety_island_top_full &
```

---

## 编译选项

```makefile
VCS_OPTS       := -full64 -sverilog -debug_access+all -kdb +define+FSDB -timescale=1ns/1ps
VCS_BATCH_OPTS := -full64 -sverilog -debug_access+all -kdb +define+FSDB +define+FI_ARRAY_BIT_TARGETS -timescale=1ns/1ps
```

| 选项 | 说明 |
|------|------|
| `-full64` | 64 位编译 |
| `-sverilog` | 启用 SystemVerilog |
| `-debug_access+all` | 全信号调试访问 |
| `-kdb` | 生成 Verdi KDB 库 |
| `+define+FSDB` | 启用 FSDB 波形 dump |
| `+define+FI_ARRAY_BIT_TARGETS` | 启用数组寄存器 bit 级注错 (batch 模式用) |
| `-timescale=1ns/1ps` | 默认时间精度 |

---

## 关键设计参数

| 参数 | 值 | 说明 |
|------|-----|------|
| `NUM_MASTERS` | 5 | Master 通道数 |
| `NUM_ENTRIES` | 64 | 每个 Master 的 Entry 数 |
| `ADDR_W` | 32 | 地址位宽 |
| `DATA_W` | 64 | 数据位宽 |
| `CRC_WIDTH` | 16 | CRC-16 E2E 保护 |
| `MAX_OUTSTANDING` | 4 | 最大 outstanding 深度 |
| `STUCK_AT_THRESHOLD` | 10 | Stuck-at 检测阈值 |

---

## 故障排除

### License 问题
```bash
lmstat -a -c $SNPSLMD_LICENSE_FILE
```

### 编译报错：找不到文件
确认 `rtl/safety_island_top.f` 中的文件名与 `rtl/` 目录一致：
```
safety_island_axi_read_engine.v
safety_island_core_logic.v
safety_island_axi_config_slave.v
safety_island_fault_detector.v
safety_island_heartbeat.v
safety_island_top.v
```

### 波形未生成
确认编译时包含 `+define+FSDB`，TB 中 `` `ifdef FSDB `` 块会调用 `$fsdbDumpfile` / `$fsdbDumpvars`。

---

## 清理

```bash
make clean
```
