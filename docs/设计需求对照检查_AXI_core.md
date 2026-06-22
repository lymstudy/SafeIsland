# AXI 与 Core 设计需求对照检查

检查对象：

- RTL：`SafeIsland/rtl/safety_island_top.v`
- Core：`SafeIsland/rtl/safety_island_core_logic.v`
- 配置 AXI Slave：`SafeIsland/rtl/safety_island_axi_config_slave.v`
- 监控 AXI Read Engine：`SafeIsland/rtl/safety_island_axi_read_engine.v`
- Filelist：`SafeIsland/rtl/safety_island_top.f`
- 仿真：`SafeIsland/tb/tb_safety_island_top_basic.v`、`SafeIsland/tb/tb_safety_island_top_full.v`
- ModelSim 脚本：`SafeIsland/sim/modelsim/run_safety_island_top_basic_tb.do`、`SafeIsland/sim/modelsim/run_safety_island_top_full_tb.do`

## 当前结论

当前安全岛顶层已经形成完整主路径：

- 1 路 64bit AXI 配置 Slave。
- 5 路 64bit AXI read master 监控接口。
- Core、配置寄存器、AXI read engine 已在顶层连接。
- 支持配置寄存器、周期/单次扫描、Mask+OR、INCR/WRAP burst、16 beat burst、OK/Error/Timeout、lock 写保护、非法配置检测。
- 支持同一路 master 内最多 `MAX_OUTSTANDING=4` 个未完成 read 请求。
- 提供 `fault_detect`、`safety_island_fault_detect`、`safety_island_latent_fault_detect`。
- 已建立 ModelSim full TB、fault injection TB 和波形脚本；当前 full TB 为 `10/10 PASS`，基础注错 campaign 为 `6/6 detected`。

强制功能按当前设计边界基本完成。仍未实现的内容是可选加分项：

- AXI out-of-order response。
- AXI interleaving。

当前 AoU 限制：同一路 master 的 read response 必须按 AR 发起顺序返回；read engine 不做 AXI ID 重排和 interleaving 重组。

## 需求符合性表

| 需求项 | 设计方案要求 | 当前实现 | 符合性 |
|---|---|---|---|
| 同步设计 | 时钟上升沿采样 | 新增安全岛顶层、配置 slave、core、read engine 均使用 `posedge clk` 和同步高有效 `rst` | 符合 |
| RTL 实现 | 使用可综合 RTL | 主要模块均为 Verilog RTL | 符合 |
| AXI4 基础协议 | 以 AXI4 为基础协议 | 配置侧实现 AXI read/write 通道；监控侧实现 5 路 AXI read master 通道 | 符合主路径要求 |
| 1 路 AXI Slave 配置接口 | 64bit 数据、32bit 地址，配置 interval/base/offset/mask/burst/control/status | `safety_island_axi_config_slave.v` 实现专用寄存器 map | 符合 |
| 5 路 AXI Master 监控接口 | 64bit 数据、32bit 地址，读取外部安全寄存器 | `safety_island_top.v` 实例化 5 路 `safety_island_axi_read_engine` | 符合 |
| AXI 基本读写 | 支持基本 AXI 访问 | 配置 slave 支持读写；监控 read engine 支持 AR/R 读通道 | 符合 |
| AXI outstanding | 必须支持 outstanding | 顶层默认 `SUPPORT_OUTSTANDING=1`、`MAX_OUTSTANDING=4`；read engine 和 core pending FIFO 支持同一路 master 多个未完成读请求 | 符合 |
| out-of-order | 可选加分 | 未实现 AXI ID 重排；乱序 ID/响应按错误或 AoU 限制处理 | 可选未支持 |
| interleaving | 可选加分 | 未实现 read response interleaving 重组 | 可选未支持 |
| OK/Error response | 支持 OKAY/Error response | RRESP 非 OKAY、ID 不匹配、timeout 均上报 bus fault | 符合 |
| WRAP/INCR burst | 支持 WRAP/INCR | 配置项透传到 ARBURST；core 检查合法性；TB 覆盖 INCR 和 WRAP | 符合 |
| 至少 16 beat burst | 支持不小于 16 beat burst | 8bit ARLEN；TB 覆盖 16 beat INCR burst | 符合 |
| Timeout | master 读超时置故障 | read engine 内部计数超时，core 归类为 bus fault，错误码 `0x21` | 符合 |
| fault_detect | 外部/总线/配置故障汇总输出 | `fault_detect = external_fault_event | bus_fault_event | cfg_fault_event` | 符合 |
| safety_island_fault_detect | 安全岛自身故障输出 | core 内部 FSM/反码/pending/outstanding/累加保护触发 `safety_island_fault_event` | 符合 |
| safety_island_latent_fault_detect | latent fault 输出 | 配置 shadow/反码错误或 core 内部安全岛故障触发 latent 输出；`STATUS[6]` 可读 | 已实现 |
| 周期读取任务 | 按配置间隔周期扫描 | `read_interval`、`enable`、`scan_once` 和扫描 FSM 已实现 | 符合 |
| 读取地址配置 | 5 个 base、每 master 64 个 offset | 配置 slave 提供 5 个 base 和 5*64 个 entry offset | 符合 |
| Mask 处理 | 使用 mask 屏蔽无效 bit | core 对 read data 执行 `read_data & mask` | 符合 |
| OR 累加 | 多 entry 读回结果按位 OR | core 使用 `fault_or_accum` 汇总，输出 `fault_or_result` | 符合 |
| 配置保护 | lock 后写保护，非法配置触发故障 | lock 后写返回 SLVERR 并置配置故障；非法 burst、WRAP length、interval=0 均检测 | 符合 |
| 配置 shadow/反码保护 | 关键配置寄存器反码校验 | enable/lock/illegal/read_interval/base/offset/mask/burst/valid 均有反码校验 | 符合基本要求 |
| 内部安全保护 | 内部永久/瞬时故障可被检测 | core 有 FSM 反码、累加反码、index/pending FIFO/outstanding 检查；fault injection TB 覆盖配置 shadow、FSM 反码、累加反码、pending 指针、瞬时翻转、AXI timeout | 基础注错符合，完整随机覆盖率统计待扩展 |
| 注错验证 | timeout/error/stuck/transient 注入与统计 | full TB 覆盖 bus error/timeout/配置错误；fault injection TB 覆盖 6 类注错并输出 detected/undetected 统计 | 基础符合 |

## 已实现模块说明

### `safety_island_top.v`

- 默认参数：
  - `NUM_MASTERS=5`
  - `NUM_ENTRIES=64`
  - `DATA_W=64`
  - `ADDR_W=32`
  - `SUPPORT_OUTSTANDING=1`
  - `MAX_OUTSTANDING=4`
- 连接配置 AXI slave、core 和 5 路 read engine。
- 监控 AXI 写通道固定 tie-off，只实现监控读路径。
- 顶层输出：
  - `fault_detect`
  - `safety_island_fault_detect`
  - `safety_island_latent_fault_detect`
  - `fault_or_result`
  - `core_error_code`

### `safety_island_axi_config_slave.v`

寄存器 map：

| 地址 | 名称 | 说明 |
|---|---|---|
| `0x0000_0000` | CONTROL | enable、scan_once、clear、lock |
| `0x0000_0008` | READ_INTERVAL | 周期扫描间隔 |
| `0x0000_0010` | STATUS | busy/done/external/bus/cfg/safety/latent |
| `0x0000_0018` | FAULT_RESULT | Mask+OR 结果 |
| `0x0000_0020` | ERROR_CODE | core 错误码 |
| `0x0000_0028` | INDEX_STATUS | 当前 master/entry |
| `0x0000_0030` | OUTSTANDING | 当前 outstanding 数 |
| `0x0000_0100 + n*8` | BASE[n] | master base address |
| `0x0000_1000 + master*0x1000 + entry*0x20 + 0x0` | ENTRY_OFFSET | entry offset |
| `... + 0x8` | ENTRY_MASK | entry mask |
| `... + 0x10` | ENTRY_BURST | burst type/len/valid |

保护机制：

- lock 后禁止改配置，写返回 `SLVERR` 并置配置故障。
- 配置寄存器有反码 shadow 校验。
- 非法 AXI size/burst/len、非法地址返回 `SLVERR`。
- status 可读出 fault 分类和 latent fault。

### `safety_island_axi_read_engine.v`

- 只实现 AXI read master AR/R 通道。
- 支持最多 `MAX_OUTSTANDING` 个未完成 AR。
- 每个 burst 内对 RDATA 做 OR 汇总，RLAST 后返回一次完成响应。
- 支持 INCR/WRAP 参数透传。
- 支持 RRESP 错误、ID 不匹配、timeout 检测。
- 不支持 out-of-order/interleaving，要求同一路 master 响应按发起顺序返回。

### `safety_island_core_logic.v`

- 执行周期/单次扫描。
- 遍历 5 路 master、每路 64 个 entry。
- 地址生成：`base_addr[master] + offset[master][entry]`。
- 对 read data 做 `mask & data` 后 OR 累加。
- 区分 external fault、bus fault、config fault、safety island fault。
- 检查非法 burst type、WRAP 非法 length、interval=0。
- 内部保护包括 FSM 反码、累加反码、index 范围、pending FIFO、outstanding 数检查。

## 仿真验证状态

### Smoke Test

脚本：

```powershell
cd D:\studydoc\competition\PIC\SafeIsland\sim\modelsim
& 'D:\software\modelism\MODELISM\win64\vsim.exe' -c -do run_safety_island_top_basic_tb.do
```

结果：

```text
PASS: safety_island_top basic config/read/fault flow
Errors: 0, Warnings: 0
```

### Full Test

脚本：

```powershell
cd D:\studydoc\competition\PIC\SafeIsland\sim\modelsim
& 'D:\software\modelism\MODELISM\win64\vsim.exe' -c -do run_safety_island_top_full_tb.do
```

覆盖场景：

| Testcase | 覆盖点 | 当前结果 |
|---|---|---|
| `basic_fault_flow` | 1 个 entry 外部非零 fault | PASS |
| `no_fault_flow` | 外部返回 0，扫描完成但不置 fault | PASS |
| `multi_master_flow` | 至少 2 路 master、多个 entry、Mask+OR | PASS |
| `burst_16_incr_flow` | 16 beat INCR burst OR 汇总 | PASS |
| `wrap_burst_flow` | 合法 WRAP burst | PASS |
| `bus_error_flow` | RRESP=SLVERR，总线故障 | PASS |
| `timeout_flow` | R 通道不返回，timeout 故障 | PASS |
| `outstanding_flow` | 同一路 master 4 个 outstanding 后顺序返回 | PASS |
| `config_error_flow` | interval=0、非法 burst、非法 WRAP、lock 后写 | PASS |
| `latent_fault_flow` | 配置 shadow/反码注错，latent fault | PASS |

结果：

```text
PASS: safety_island_top full test completed, cases=10
Errors: 0, Warnings: 0
```

波形输出：

- `SafeIsland/sim/out/safety_island_top_full/safety_island_top_full.wlf`
- `SafeIsland/sim/out/safety_island_top_full/safety_island_top_full.vcd`

### Fault Injection Test

脚本：

```powershell
cd D:\studydoc\competition\PIC\SafeIsland\sim\modelsim
& 'D:\software\modelism\MODELISM\win64\vsim.exe' -c -do run_safety_island_fault_injection_tb.do
```

覆盖场景：

| Fault case | 类型 | 期望结果 | 当前结果 |
|---|---|---|---|
| `cfg_shadow_read_interval_stuck` | 配置寄存器反码 stuck fault | 10 cycle 内 `fault_detect`/latent 置位 | DETECTED, 2 cycles |
| `core_state_inv_stuck` | FSM 反码 stuck fault | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 3 cycles |
| `core_accum_inv_stuck` | 累加器反码 stuck fault | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 3 cycles |
| `pending_wr_ptr_stuck` | pending FIFO 指针 stuck fault | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 3 cycles |
| `transient_state_inv_flip` | FSM 反码瞬时翻转 | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 2 cycles |
| `axi_timeout` | 外部总线 timeout | `fault_detect` 置位，错误码 `0x21` | DETECTED |

统计结果：

```text
FI_SUMMARY: total=6 corrected=0 detected=6 undetected=0
PASS: safety_island fault injection campaign completed
Errors: 0, Warnings: 0
```

波形输出：

- `SafeIsland/sim/out/safety_island_fault_injection/safety_island_fault_injection.wlf`
- `SafeIsland/sim/out/safety_island_fault_injection/safety_island_fault_injection.vcd`

## 剩余限制和建议

### 当前限制

- 不支持 AXI out-of-order response。
- 不支持 AXI interleaving。
- 配置 AXI slave 当前是单事务响应模型，不做配置侧 outstanding。
- 已有基础 fault injection campaign，但未做全网表/全寄存器随机 fault campaign 和 SPFM/LFM 概率统计。
- 未做 formal/property 级 AXI 协议检查。

### 建议写入设计文档的 AoU

1. 监控 AXI read response 必须在同一路 master 内按 AR 发起顺序返回。
2. 不使用 AXI read interleaving。
3. `MAX_OUTSTANDING` 默认为 4，可参数化调整。
4. `safety_island_latent_fault_detect` 当前覆盖配置 shadow/反码错误和 core 内部安全岛故障，不代表完整 ASIL-D 诊断覆盖率证明。

### 后续可选增强

1. 实现 AXI out-of-order：按 ARID 建表，R 通道按 ID 匹配返回 entry。
2. 实现 interleaving：支持多个 burst 的 R beat 交错，并维护每个 ID 的 burst OR accumulator。
3. 增加 fault campaign：自动 force/release 关键寄存器、FIFO、状态机、配置表 bit，统计检测周期和覆盖率。
4. 加 AXI protocol assertion 或 formal lint，证明握手和 burst 行为。
