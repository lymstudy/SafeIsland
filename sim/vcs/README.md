# Safety Island 仿真复现指南

## 环境要求

| 工具 | 版本要求 | 说明 |
|------|----------|------|
| VCS | 2020+ | Verilog/SystemVerilog 仿真器 |
| Verdi | 2020+ | 波形查看器（可选） |
| OS | Linux | VCS/Verdi 运行环境 |

## 目录结构

```
SafeIsland/
├── rtl/
│   ├── safety_island_top.f              ← RTL 文件列表
│   ├── safety_island_top.v              ← 顶层模块
│   ├── safety_island_core_logic.v       ← 核心控制逻辑
│   ├── safety_island_axi_config_slave.v ← AXI 配置从端
│   └── safety_island_axi_read_engine.v  ← AXI 读引擎
├── tb/
│   ├── tb_safety_island_top_full.v       ← 全功能测试平台
│   └── tb_safety_island_fault_injection.v ← 故障注入测试平台
└── sim/
    └── vcs/
        ├── Makefile                      ← 仿真 Makefile
        └── README.md                     ← 本文档
```

## 快速开始

```bash
cd SafeIsland/sim/vcs

# 编译并运行全部回归测试（17 个 testcase）
make regress

# 或分步执行：
make full       # 编译 + 运行全功能测试
make fault      # 编译 + 运行故障注入测试
```

## Makefile 目标说明

| 目标 | 功能 |
|------|------|
| `all` / `regress` | 依次运行 `full` + `fault` |
| `full` | 编译并运行全功能测试平台 |
| `full-comp` | 仅编译全功能测试（生成 `build/simv_full`） |
| `full-run` | 仅运行全功能测试 |
| `fault` | 编译并运行故障注入测试平台 |
| `fault-comp` | 仅编译故障注入测试（生成 `build/simv_fault`） |
| `fault-run` | 仅运行故障注入测试 |
| `verdi-full` | 用 Verdi 打开全功能测试波形 |
| `verdi-fault` | 用 Verdi 打开故障注入测试波形 |
| `clean` | 清理所有生成文件 |

## 编译选项说明

```makefile
VCS_OPTS := -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps
```

| 选项 | 说明 |
|------|------|
| `-full64` | 64 位编译 |
| `-sverilog` | 启用 SystemVerilog 支持 |
| `-debug_access+all` | 全信号调试访问 |
| `-kdb` | 生成 Verdi KDB 库 |
| `-timescale=1ns/1ps` | 默认时间精度 |

## 波形文件

- 仿真自动生成 FSDB 波形文件到 `waves/` 目录：
  - `waves/full.fsdb` — 全功能测试波形
  - `waves/fault_injection.fsdb` — 故障注入测试波形

FSDB dump 由 TB 内部的 `$value$plusargs("FSDB=%s", ...)` 解析命令行参数 `+FSDB=<path>` 来控制。
若未指定 `+FSDB`，默认生成 `full.fsdb` 或 `fault_injection.fsdb` 到当前目录。

## 查看波形

```bash
# 全功能测试波形
make verdi-full

# 故障注入测试波形
make verdi-fault
```

或手动启动 Verdi：

```bash
verdi -ssf waves/full.fsdb -sv -f ../../rtl/safety_island_top.f ../../tb/tb_safety_island_top_full.v -top tb_safety_island_top_full &
```

## 全功能测试 Testcase 列表

| # | Testcase | 测试内容 |
|---|----------|----------|
| 1 | `basic_fault_flow` | 基本故障检测流程 |
| 2 | `no_fault_flow` | 无故障场景 |
| 3 | `multi_master_flow` | 多 Master 并行扫描 |
| 4 | `burst_16_incr_flow` | INCR 16-beat 突发传输 |
| 5 | `wrap_burst_flow` | WRAP 4-beat 回环传输 |
| 6 | `bus_error_flow` | AXI 总线错误响应 |
| 7 | `timeout_flow` | 读超时检测 |
| 8 | `outstanding_flow` | 多 outstanding 事务 |
| 9 | `out_of_order_flow` | 乱序返回 (Out-of-Order) |
| 10 | `interleaving_flow` | 交错返回 (Interleaving) |
| 11 | `out_of_order_interleaving_flow` | 乱序 + 交错混合 |
| 12 | `invalid_rid_error_flow` | 非法 RID 检测 |
| 13 | `aou_rcheck_ok_flow` | CRC8 RCHECK 校验通过 |
| 14 | `aou_rcheck_error_flow` | CRC8 RCHECK 校验失败（单 beat） |
| 15 | `aou_rcheck_burst_error_flow` | CRC8 RCHECK 校验失败（多 beat） |
| 16 | `config_error_flow` | 非法配置检测 |
| 17 | `latent_fault_flow` | 潜在故障检测（shadow register） |

## 预期输出

全部 17 个 testcase 通过时，日志末尾显示：

```
PASS: safety_island_top full test completed, cases=17
```

有失败时显示：

```
FAIL: safety_island_top full test completed, failures=N passes=M
```

## 关键设计参数

| 参数 | 值 | 说明 |
|------|-----|------|
| `NUM_MASTERS` | 5 | Master 通道数 |
| `NUM_ENTRIES` | 64 | 每个 Master 的 Entry 数 |
| `ADDR_W` | 32 | 地址位宽 |
| `DATA_W` | 64 | 数据位宽 |
| `ID_W` | 4 | AXI ID 位宽 |
| `TIMEOUT_CYCLES` | 48 | 读超时周期数 |
| `MAX_OUTSTANDING` | 4 | 最大 outstanding 深度 |

## 故障排除

### 编译报错：找不到 RTL 文件

确认 `rtl/safety_island_top.f` 中的文件名与 `rtl/` 目录下的实际文件名一致：

```
safety_island_axi_read_engine.v
safety_island_core_logic.v
safety_island_axi_config_slave.v
safety_island_top.v
```

Makefile 使用 `-F` 标志（大写），确保文件路径相对于文件列表所在目录（`rtl/`）解析。

### License 问题

```bash
# 检查 VCS license
lmstat -a -c $SNPSLMD_LICENSE_FILE
```

### 波形文件未生成

确认 TB 中的 FSDB dump `initial` 块未被优化掉，检查编译时是否包含 `-debug_access+all`。

## 清理

```bash
make clean
```
