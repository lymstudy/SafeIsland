# AXI Safety Island ASIL-D 安全增强修复设计

> 状态: 已批准 | 日期: 2026-06-25 | 关联分析: 代码审查根因分析

## 1. 背景与目标

当前 `safety_island_top` 在功能层面正确，但在 AXI 端口接口故障检测、内部安全机制完整性方面存在系统性缺口，不足以满足 ASIL-D 对单点故障度量 (SPFM ≥ 99%) 和潜在故障度量 (LFM ≥ 90%) 的要求。

本设计定义 **6 项可综合 RTL 修复**，按依赖顺序增量实施，每项修复独立验证通过后进入下一项。

### 修复范围（A 级 — 架构级可综合修复）

| # | 修复项 | 优先级 | 新增/改动文件 |
|---|--------|--------|---------------|
| 1 | CRC 参数化 (8/16 bit) + AR 通道端到端保护 | **最高** | `safety_island_axi_read_engine.v`, `safety_island_top.v` |
| 2 | 心跳自检机制 | 高 | 新增 `safety_island_heartbeat.v`, `safety_island_top.v` |
| 3 | Known-Answer Test (KAT) | 高 | `safety_island_core_logic.v`, `safety_island_axi_config_slave.v` |
| 4 | TMR 关键控制路径 | 中 | 新增 `tmr_voter.v`, `safety_island_core_logic.v`, `safety_island_top.v` |
| 5 | S_AXI Write-Verify 传输保护 | 中 | `safety_island_axi_config_slave.v` |
| 6 | 增强故障注入验证 (回归 + 新 case) | — | `tb_safety_island_top_full.v`, `tb_safety_island_fault_injection.v` |

### 关键设计决策

- **CRC 策略**: 参数化 `CRC_WIDTH` (8 或 16)，`CRC_WIDTH=8` 时向后兼容原 CRC-8 行为
- **TMR 范围**: 仅关键控制路径 — FSM state、fault 输出、cfg_locked/enable
- **实施策略**: 方案 1 — 增量式修复，每项独立验证
- **约束**: 纯 RTL 可综合，ModelSim 仿真，不使用第三方 VIP

---

## 2. 修复 1：CRC 参数化 + AR 通道端到端保护

### 2.1 问题

当前设计仅在 R 通道使用 CRC-8 (`polynomial 0x07`) 覆盖 `{RID, RDATA, RRESP, RLAST}` (71 bits)。AR 通道 (`ARID, ARADDR, ARLEN, ARSIZE, ARBURST`) **无任何保护**。`m_axi_araddr` 上的 stuck-at 故障使安全岛从错误地址读取数据，CRC-8 和 Expected 比较均无法检测。

### 2.2 设计

#### 2.2.1 CRC-16 参数化

**文件**: `safety_island_axi_read_engine.v`

新增 parameter:
```verilog
parameter CRC_WIDTH = 16   // 8 or 16
```

CRC-16 多项式: `0x1021` (CRC-16-CCITT)，初值 `0xFFFF`。

CRC-8 多项式: `0x07`（保持不变），初值 `0x00`。

新增函数 `crc_n()`:
```verilog
function [CRC_WIDTH-1:0] crc_n;
    input [ID_WIDTH+ADDR_WIDTH+8+3+2-1:0] payload;  // max bits for AR
    // parameterized CRC calculation
endfunction
```

#### 2.2.2 AR 通道签名

每个 AR 事务发出时，计算 AR 签名并存储:

```
AR_SIGNATURE = crc_n({ARID, ARADDR, ARLEN, ARSIZE, ARBURST})
```

新增 slot 存储:
```verilog
reg [CRC_WIDTH-1:0] slot_ar_sig_q [0:MAX_OUTSTANDING-1];  // 每个 outstanding slot
```

`ar_fire` 时写入 `slot_ar_sig_q[wr_ptr] <= AR_SIGNATURE`。

#### 2.2.3 R 通道 E2E 校验增强

R beat 时 CRC 覆盖范围从 `{RID, RDATA, RRESP, RLAST}` 扩展为:
```
R_CHECK = crc_n({AR_SIGNATURE, RID, RDATA, RRESP, RLAST})
```

`m_axi_rcheck` 端口宽度参数化: `CRC_WIDTH` bits per master。

`r_error_next` 中的 CRC mismatch 检测使用扩展后的覆盖范围。

#### 2.2.4 顶层端口适配

**文件**: `safety_island_top.v`

```verilog
// 原: input wire [NUM_MASTERS*8-1:0]  m_axi_rcheck_flat
// 新:
input wire [NUM_MASTERS*CRC_WIDTH-1:0] m_axi_rcheck_flat
```

`CRC_WIDTH` 作为顶层 parameter 传递到各 read engine 实例。

### 2.3 验证

| TB 用例 | 操作 | 预期结果 |
|---------|------|----------|
| `e2e_crc16_ok` | CRC_WIDTH=16，slave 计算含 AR 签名的 CRC-16 | fault_or_result 正确，无故障 |
| `e2e_araddr_corrupt` | force `m_axi_araddr` bit flip，CRC-16 mismatch | `fault_detect=1`, `error_code=0x20` |
| `e2e_arlen_corrupt` | force `m_axi_arlen` bit flip | `fault_detect=1`, `error_code=0x20` |
| `e2e_crc8_compat` | CRC_WIDTH=8，运行 basic_fault_flow | 与修改前行为完全一致 |

**回归门**: CRC_WIDTH=8 时全部 17 个现有 TB case 必须 PASS。

### 2.4 AoU 要求更新

当 CRC_WIDTH=16 时，外部 slave 的 CRC 计算必须包含 AR 签名:
```
R_CHECK[15:0] = crc16_ccitt({ARID, ARADDR, ARLEN, ARSIZE, ARBURST, RID, RDATA, RRESP, RLAST})
```
多项式 `0x1021`，初值 `0xFFFF`。

---

## 3. 修复 2：心跳自检机制

### 3.1 问题

`fault_detect` 和 `safety_island_fault_detect` 输出路径上任何 stuck-at-0 故障会使整个安全岛静默失效。当前无机制检测故障输出通路自身的健康状态。

### 3.2 设计

#### 3.2.1 新增模块 `safety_island_heartbeat.v`

```
Module: safety_island_heartbeat

Parameters:
  HEARTBEAT_INTERVAL = 1024  // 心跳周期 (cycles)

Ports:
  input  clk, rst
  input  enable               // 安全岛使能
  input  scan_busy            // 扫描进行中 (心跳测试需等待空闲)
  output test_inject          // 测试注入脉冲 (连接到 core logic)
  input  safety_island_fault_detect  // 监控目标
  output heartbeat_fault      // 心跳失败标志 (OR 到 safety_island_fault_detect)
  output heartbeat_active     // 心跳进行中 (暂停扫描)
```

**心跳测试序列**:
1. 心跳计数器累计，到达 HEARTBEAT_INTERVAL 时触发测试
2. 等待 `scan_busy == 0`（扫描空闲）
3. `heartbeat_active = 1`，阻止新的扫描启动
4. 脉冲 `test_inject = 1`（1 cycle），注入到 core logic 的 `fault_or_accum_inv`
5. 等待最多 10 cycles，监控 `safety_island_fault_detect`
6. 若 `safety_island_fault_detect == 1` → 测试通过，清除注入，继续
7. 若超时未检测到 → `heartbeat_fault = 1`（sticky），通过独立路径报告
8. `heartbeat_active = 0`，恢复扫描

**集成方式** (`safety_island_top.v`):

```verilog
// heartbeat_fault 与 fd_safety_island_fault 独立 OR
assign safety_island_fault_detect = fd_safety_island_fault | heartbeat_fault;
```

**test_inject 连接到 core logic**:
在 `safety_island_core_logic.v` 中新增 input `test_inject`:
```verilog
// 在累加器反码逻辑中，test_inject 时强制翻转 accum_inv
if (test_inject) begin
    fault_or_accum_inv <= ~(~fault_or_accum);  // 模拟反码不匹配
end
```

### 3.3 验证

| TB 用例 | 操作 | 预期结果 |
|---------|------|----------|
| `heartbeat_pass` | CRC_WIDTH=16, KAT disabled, 正常操作 + 等待心跳 | `safety_island_fault_detect` 脉冲一次后恢复，扫描继续 |
| `heartbeat_fail` | force `safety_island_fault_detect` = 0 | heartbeat 超时，`heartbeat_fault` 通过独立路径拉高 |
| `heartbeat_no_interfere` | 心跳触发时恰好 scan_busy=1 | 心跳等待 scan_busy=0 后才执行，不打断正在进行的扫描 |

---

## 4. 修复 3：Known-Answer Test (KAT)

### 4.1 问题

如果 CRC E2E + Expected 比较恰好都通过（例如错误地址返回了与 expected 匹配的值，且 CRC 也合法），整个读路径可能静默失效。需要一个独立于正常扫描的"已知答案"测试来验证读通路。

### 4.2 设计

#### 4.2.1 KAT 配置寄存器

**文件**: `safety_island_axi_config_slave.v`

新增寄存器地址:
| 地址 | 名称 | 说明 |
|------|------|------|
| `0x0038` | KAT_CTRL | bit[0]: kat_enable, bit[63:1]: reserved |
| `0x0040` | KAT_ADDR | KAT 目标地址 (指向外部已知值寄存器) |
| `0x0048` | KAT_EXPECTED | KAT 期望值 |
| `0x0050` | KAT_MASK | KAT 比较 Mask |

#### 4.2.2 KAT 执行流程

**文件**: `safety_island_core_logic.v`

在 `ST_PREP_SCAN` 状态中，若 `kat_enable == 1`:
1. 发起一次 KAT 读取（类似正常 entry 读取，但使用 KAT_ADDR/EXPECTED/MASK）
2. 等待 KAT 响应
3. 比较 `(read_data & kat_mask) == (kat_expected & kat_mask)`
4. 若匹配 → 进入正常扫描 `ST_FIND_ENTRY`
5. 若不匹配 → 跳转 `ST_SAFE_ERROR`，`core_safety_fault=1`，error_code=`ERR_KAT_FAIL (0x47)`

KAT 读取复用现有的 read engine 通道（master 0），确保覆盖完整的读路径（AR → Interconnect → Slave → R）。

### 4.3 验证

| TB 用例 | 操作 | 预期结果 |
|---------|------|----------|
| `kat_pass` | 配置 KAT_ADDR 指向已知值，KAT_EXPECTED 正确 | 扫描正常完成 |
| `kat_fail` | KAT_EXPECTED 与实际值不匹配 | `safety_island_fault_detect=1`，error_code=`0x47` |
| `kat_araddr_stuck` | force `m_axi_araddr` bit flip on KAT read | E2E CRC 捕获（CRC_WIDTH=16）或 KAT mismatch 捕获 |
| `kat_disabled` | kat_enable=0 | 扫描行为与修改前一致 |

---

## 5. 修复 4：TMR 关键控制路径

### 5.1 问题

FSM state 寄存器、fault 输出寄存器、cfg_locked 等关键寄存器使用反码保护，但反码只能检测 stuck-at 且需两个周期才能触发，且反码比较逻辑本身可能故障。

### 5.2 设计

#### 5.2.1 新增模块 `tmr_voter.v`

```verilog
module tmr_voter #(parameter WIDTH = 4) (
    input  wire [WIDTH-1:0] a, b, c,
    output wire [WIDTH-1:0] voted,
    output wire             mismatch     // a,b,c 三者均不同 → 1
);
```

表决逻辑: `voted = (a & b) | (b & c) | (a & c)` (按位多数表决)

#### 5.2.2 TMR 施加范围

| 模块 | 寄存器 | 宽度 | TMR 方式 |
|------|--------|------|----------|
| `core_logic` | `state` | 4 bit | 三份副本 `state_a/b/c` + 表决器读出 |
| `core_logic` | `safety_fault_q` | 1 bit | 三份副本 + 表决器 |
| `core_logic` | `safety_error_code_q` | 8 bit | 三份副本 + 表决器 |
| `config_slave` | `cfg_locked_r` | 1 bit | 三份副本 + 表决器 |
| `config_slave` | `cfg_illegal_r` | 1 bit | 三份副本 + 表决器 |
| `config_slave` | `enable` | 1 bit | 三份副本 + 表决器 |
| `top` | `fault_detect` 输出 | 1 bit | 三份驱动 + 表决器 |
| `top` | `safety_island_fault_detect` 输出 | 1 bit | 三份驱动 + 表决器 |

#### 5.2.3 集成示例 (core_logic state)

```verilog
// 原:
reg [3:0] state;
// 新:
reg [3:0] state_a, state_b, state_c;
wire [3:0] state;             // 表决后使用
wire       state_tmr_mismatch;

tmr_voter #(.WIDTH(4)) u_state_tmr (
    .a(state_a), .b(state_b), .c(state_c),
    .voted(state), .mismatch(state_tmr_mismatch)
);

// 写入时三份同时写入:
always @(posedge clk) begin
    if (rst) begin
        state_a <= ST_IDLE;
        state_b <= ST_IDLE;
        state_c <= ST_IDLE;
    end else begin
        state_a <= state_next;
        state_b <= state_next;
        state_c <= state_next;
    end
end
```

`state_tmr_mismatch` OR 到 `core_safety_fault`。

#### 5.2.4 顶层 fault 输出 TMR

```verilog
// fault_detect 三份驱动
wire fd_a = fd_external_fault | fd_bus_fault | fd_cfg_fault;
wire fd_b = /* 同上的独立复制 */;
wire fd_c = /* 同上的独立复制 */;
tmr_voter #(.WIDTH(1)) u_fd_tmr (.a(fd_a), .b(fd_b), .c(fd_c), .voted(fault_detect), .mismatch(fd_tmr_mismatch));
```

**注意**: 三份驱动必须是各自独立的逻辑门（综合工具不得合并），需要添加 `(* DONT_TOUCH = "TRUE" *)` 等综合属性。

### 5.3 验证

| TB 用例 | 操作 | 预期结果 |
|---------|------|----------|
| `tmr_state_ok` | 正常操作 | FSM 正常，`state_tmr_mismatch=0` |
| `tmr_state_minority` | force `state_b[0]` != `state_a[0]`，`state_c`==`state_a` | 表决器输出=多数，FSM 正常，mismatch=0 |
| `tmr_state_double_fault` | force `state_b[0]` != `state_a[0]` 且 `state_c[0]` != `state_a[0]` | tmr_mismatch=1 → `safety_island_fault_detect=1` |
| `tmr_fd_stuck` | force `fd_b` stuck-at-0 | 表决器输出仍正确，`fault_detect` 不受影响 |
| `tmr_cfg_locked_fault` | force `cfg_locked_r_b=0` | 表决器仍为 1，写保护保持 |

---

## 6. 修复 5：S_AXI Write-Verify 传输保护

### 6.1 问题

S_AXI 配置接口的 `s_axi_wdata` 传输路径无保护。配置写入时若 wdata 发生位翻转，且翻转后的值恰好合法（满足 shadow register 约束），则错误配置将静默生效。

### 6.2 设计

**文件**: `safety_island_axi_config_slave.v`

**Write-Verify 流程**:
1. AW+W 握手完成，获得 write_addr, write_data, write_strb
2. 写入目标寄存器（与现有流程一致）
3. 同一周期读取目标寄存器的当前值（从 shadow/inv 寄存器重建）
4. 比较 `apply_wstrb(old_value, write_data, write_strb) == new_value`
5. 若匹配 → `bresp = OKAY`
6. 若不匹配 → `bresp = SLVERR`，`cfg_illegal_r = 1`

**实现要点**:
- verify 比较逻辑为纯组合逻辑，不增加额外延迟
- 比较失败时 `bresp=SLVERR`，上层通过 `cfg_illegal` 触发 `fault_detect`
- 写保护 (cfg_locked) 仍优先生效 — locked 后禁止所有写入

### 6.3 验证

| TB 用例 | 操作 | 预期结果 |
|---------|------|----------|
| `write_verify_pass` | 正常配置写入 (ADDR_READ_INTERVAL = 64'd8) | bresp=OKAY，读回值正确 |
| `write_verify_fail` | testbench force wdata 内部路径 flip | bresp=SLVERR，`cfg_illegal=1` |

---

## 7. 文件改动总结

| 文件 | 改动类型 | 改动量 (估算) |
|------|----------|--------------|
| `rtl/safety_island_axi_read_engine.v` | 修改 | +80 行 (CRC 参数化 + AR 签名) |
| `rtl/safety_island_top.v` | 修改 | +60 行 (端口 + TMR + heartbeat 集成) |
| `rtl/safety_island_core_logic.v` | 修改 | +60 行 (KAT + test_inject + TMR) |
| `rtl/safety_island_axi_config_slave.v` | 修改 | +50 行 (KAT regs + write-verify + TMR) |
| `rtl/safety_island_fault_detector.v` | 修改 | +10 行 (KAT error code) |
| **`rtl/safety_island_heartbeat.v`** | **新增** | ~100 行 |
| **`rtl/tmr_voter.v`** | **新增** | ~30 行 |
| `rtl/axi_safety_island_pkg.vh` | 修改 | +15 行 (新 error codes + KAT 地址定义) |
| `tb/tb_safety_island_top_full.v` | 修改 | +200 行 (新测试用例) |
| `tb/tb_safety_island_fault_injection.v` | 修改 | +150 行 (新注错用例) |

---

## 8. 实施顺序与依赖

```
修复 1 (CRC+E2E) ────── 无依赖，最先实施
       ↓
修复 2 (心跳) ──────── 依赖修复 1 的 test_inject 接口
       ↓
修复 3 (KAT) ───────── 依赖修复 1 的 E2E CRC 配合检测
       ↓
修复 4 (TMR) ───────── 依赖修复 2/3 的心跳和 KAT 作为互补
       ↓
修复 5 (Write-Verify) ─ 独立，可并行但建议最后
       ↓
修复 6 (验证增强) ──── 累积验证所有修复
```

每步验证门:
1. 所有新增 case 必须 PASS
2. 所有现有 17 个 full TB case 必须回归 PASS
3. 所有现有 18 个 fault injection case 必须回归 PASS

---

## 9. 自检清单

- [x] 无 TBD/TODO
- [x] 内部一致: CRC_WIDTH 参数在各模块间传递一致
- [x] 范围受控: 6 项修复，每项独立可验证
- [x] 无歧义: CRC 多项式、表决器逻辑、心跳时序均已明确
- [x] 向后兼容: CRC_WIDTH=8 时行为不变
- [x] 可综合: 无 force/release，无可综合违规
- [x] 验证覆盖: 每项修复 ≥ 2 个验证用例
