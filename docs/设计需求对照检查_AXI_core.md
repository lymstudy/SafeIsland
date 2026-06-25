# AXI 与 Core 设计需求对照检查

检查对象：

- RTL：`SafeIsland/rtl/safety_island_top.v`
- Core：`SafeIsland/rtl/safety_island_core_logic.v`
- 配置 AXI Slave：`SafeIsland/rtl/safety_island_axi_config_slave.v`
- 监控 AXI Read Engine：`SafeIsland/rtl/safety_island_axi_read_engine.v`
- Filelist：`SafeIsland/rtl/safety_island_top.f`
- 仿真：`SafeIsland/tb/tb_safety_island_top_basic.v`、`SafeIsland/tb/tb_safety_island_top_full.v`、`SafeIsland/tb/tb_safety_island_fault_injection.v`
- ModelSim 脚本：`SafeIsland/sim/modelsim/run_safety_island_top_basic_tb.do`、`SafeIsland/sim/modelsim/run_safety_island_top_full_tb.do`、`SafeIsland/sim/modelsim/run_safety_island_fault_injection_tb.do`
- VCS/Verdi 模板：`SafeIsland/sim/vcs/`
- 测试要求来源：`D:/studydoc/competition/PIC/设计测试文档.md`

## 当前结论

当前安全岛顶层已经形成完整主路径：

- 1 路 64bit AXI 配置 Slave。
- 5 路 64bit AXI read master 监控接口。
- Core、配置寄存器、AXI read engine 已在顶层连接。
- 支持配置寄存器、周期/单次扫描、Mask+OR、INCR/WRAP burst、16 beat burst、OK/Error/Timeout、lock 写保护、非法配置检测。
- 支持同一路 master 内最多 `MAX_OUTSTANDING=4` 个未完成 read 请求。
- 提供 `fault_detect`、`safety_island_fault_detect`、`safety_island_latent_fault_detect`。
- 已建立 ModelSim full TB、fault injection TB 和波形脚本；当前 full TB 为 `17/17 PASS`，fault injection 工程版 campaign 为 `18/18 detected`，保护率统计为 `100%`。

强制功能按当前设计边界完成；AXI out-of-order response 和 read interleaving 两个可选加分项已补充完成并通过 ModelSim full TB 覆盖。

当前 AoU 要求：每一路 AXI read master 为独立通道；外部返回的 `RID` 必须对应该 read engine 已发出的未完成 `ARID`，并且每个 R beat 必须提供 CRC-8 校验位 `m_axi_rcheck`。CRC-8 校验范围为 `{RID, RDATA, RRESP, RLAST}`，校验错误按 bus fault 处理。

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
| out-of-order | 可选加分 | read engine 按 slot 分配 ARID，R 通道按 RID 匹配并缓存乱序完成结果，再按请求顺序回放给 core | 已支持 |
| interleaving | 可选加分 | 每个 outstanding slot 独立维护 beat count、OR accumulator 和错误状态，支持不同 RID 的 R beat 交错返回 | 已支持 |
| AoU 总线校验位 | 可选加分，外部模块配合校验码传递 | 监控 R 通道新增 `m_axi_rcheck_flat`，read engine 对 `{RID,RDATA,RRESP,RLAST}` 做 CRC-8 校验，错误归类 bus fault | 已支持 |
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
| 内部安全保护 | 内部永久/瞬时故障可被检测 | core 有 FSM 反码、累加反码、index/pending FIFO/outstanding 检查；fault injection TB 覆盖配置 shadow、FSM 反码、累加反码、pending 指针、outstanding、瞬时翻转、AXI timeout/error/RID mismatch/CRC mismatch | 工程版符合；认证级随机覆盖率统计为扩展 |
| 注错验证 | timeout/error/stuck/transient 注入与统计 | full TB 覆盖 bus error/timeout/配置错误/AoU CRC 错误；fault injection TB 覆盖 18 个工程版注错 case 并输出 `corrected/detected/undetected/protection_rate` 统计 | 工程版完成 |

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
- 支持同一路 master 内 out-of-order response 和 read interleaving；非法 RID 按 bus fault 处理。
- 支持 AoU CRC-8 校验位 `m_axi_rcheck`，校验对象为 `{RID,RDATA,RRESP,RLAST}`，CRC mismatch 按 bus fault 处理。

### `safety_island_core_logic.v`

- 执行周期/单次扫描。
- 遍历 5 路 master、每路 64 个 entry。
- 地址生成：`base_addr[master] + offset[master][entry]`。
- 对 read data 做 `mask & data` 后 OR 累加。
- 区分 external fault、bus fault、config fault、safety island fault。
- 检查非法 burst type、WRAP 非法 length、interval=0。
- 内部保护包括 FSM 反码、累加反码、index 范围、pending FIFO、outstanding 数检查。

## 设计测试文档要求对照

本节按根目录 `设计测试文档.md` 中列出的测试点整理当前完成状态。

### 基本功能测试点

| 测试要求 | 当前覆盖位置 | 状态 |
|---|---|---|
| AXI Slave 配置接口测试 | `tb_safety_island_top_basic.v`、`tb_safety_island_top_full.v` | 已完成 |
| 写入读取间隔、基地址、偏移地址、Mask | `basic_fault_flow`、`multi_master_flow`、`config_error_flow` | 已完成 |
| 验证 64bit 数据位宽和 32bit 地址位宽 | 顶层参数 `DATA_W=64`、`ADDR_W=32`；full TB 64bit 数据检查 | 已完成 |
| 5 路 AXI Master 监控接口测试 | 顶层 5 路接口实例化；`multi_master_flow` 覆盖至少 2 路；接口完整性由顶层连接覆盖 | 基本完成 |
| Master 接口正确发起读请求 | `basic_fault_flow`、`multi_master_flow`、`outstanding_flow` | 已完成 |
| Timeout 机制测试 | `timeout_flow`、`run_axi_timeout_fault` | 已完成 |
| AXI 基本读写操作 | 配置 AXI slave 读写任务；AXI master/slave unit tests | 已完成 |
| OK/Error response 处理 | `bus_error_flow`、AXI unit tests | 已完成 |
| WRAP/INCR burst 支持 | `burst_16_incr_flow`、`wrap_burst_flow` | 已完成 |
| AXI outstanding 操作 | `outstanding_flow`，同一路 master 4 个 outstanding | 已完成 |
| 不小于 16 length burst | `burst_16_incr_flow`，16 beat INCR | 已完成 |
| 周期读取任务 | `no_fault_flow`、状态寄存器 scan done 检查 | 已完成 |
| 读回数据按位 OR | `multi_master_flow`、`burst_16_incr_flow` | 已完成 |
| fault_detect 故障判定 | `basic_fault_flow`、`bus_error_flow`、`timeout_flow`、`config_error_flow` | 已完成 |

### 功能安全需求测试点

| 测试要求 | 当前覆盖位置 | 状态 |
|---|---|---|
| 内部 stuck-at-0/1 注错 | `tb_safety_island_fault_injection.v` 覆盖配置 shadow、FSM 反码、累加反码、pending 指针、outstanding stuck fault | 工程版完成 |
| Memory 注错 | 当前无独立 memory 阵列；配置表寄存器 shadow 注错覆盖配置存储类故障 | 工程版完成 |
| Combi logic 注错 | 通过反码比较路径和安全故障组合逻辑间接覆盖；未做随机组合逻辑全覆盖 | 工程版完成；随机全覆盖为认证级扩展 |
| Port 注错 | AXI timeout、RRESP error、RID mismatch、CRC mismatch 覆盖外部接口异常；未做所有端口 stuck-at campaign | 工程版完成 |
| Register 注错 | FSM 反码、累加器反码、pending 指针、outstanding、配置 shadow | 工程版完成 |
| 10 cycle 内置位 `safety_island_fault_detect` | fault injection TB 对内部 fault 检查 10 cycle 内检测，当前内部 fault 2-3 cycle 检出 | 已完成 |
| 瞬时翻转故障 | `transient_state_inv`、`transient_fault_or_accum_inv`、`transient_config_shadow` | 工程版完成 |
| AXI 总线 timeout | `timeout_flow`、`axi_timeout` 注错 | 已完成 |
| AXI Error Response | `bus_error_flow` | 已完成 |
| 非法配置导致 `fault_detect` | `config_error_flow` | 已完成 |
| 配置寄存器写保护或校验机制 | lock 后写保护、配置 shadow/反码校验、`latent_fault_flow` | 已完成 |
| 注错结果分类 | fault injection TB 输出 `corrected/detected/undetected/protection_rate` 统计 | 工程版完成 |
| 错误保护列表 | 本文档 Fault Injection Test 表格列出已覆盖 fault case | 工程版完成 |
| 保护概率统计 | 当前工程版 campaign 统计 `detected=18/18`、`undetected=0`、`protection_rate=100%` | 工程版完成；大规模随机概率统计为认证级扩展 |
| SPFM/LFM 证明 | 未进行 ISO 26262 级完整 SPFM/LFM 统计计算 | 认证级扩展 |

### 验证平台与复现要求

| 测试要求 | 当前实现 | 状态 |
|---|---|---|
| 提交 README 说明目录结构和复现步骤 | `SafeIsland/README.md` | 已完成 |
| 提交运行脚本 | `SafeIsland/sim/modelsim/*.do`、`SafeIsland/sim/modelsim/axi/*.do` | 已完成 |
| 不使用第三方 VIP | TB 为自写 Verilog testbench 和简单 AXI slave model | 已完成 |
| VCS 仿真复现 | `SafeIsland/sim/vcs/` 已提供 `filelist.f`、`run_top_full.sh`、`run_fault_injection.sh` 和 README；当前实际验证以 ModelSim 为主 | 脚本模板完成，ModelSim 已实测 |
| ZOIX 错误仿真 | 文档标为可选/附加分，当前未实现 | 可选未完成 |

### 可选功能测试点

| 可选测试项 | 当前状态 |
|---|---|
| AXI out_of_order 操作 | 已实现，`out_of_order_flow` 覆盖同一路 master 4 个 outstanding 反向返回 |
| AXI interleaving 操作 | 已实现，`interleaving_flow`、`out_of_order_interleaving_flow` 覆盖多 burst beat 交织 |
| `safety_island_latent_fault_detect` | 已实现并由 `latent_fault_flow`、fault injection TB 覆盖 |
| AoU 外部校验位逻辑 | 已实现 CRC-8 R 通道校验，`aou_rcheck_ok_flow`、`aou_rcheck_error_flow`、`aou_rcheck_burst_error_flow` 覆盖正常和错误路径 |

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
| `out_of_order_flow` | 同一路 master 4 个 outstanding 后按 3/2/1/0 乱序返回 | PASS |
| `interleaving_flow` | 同一路 master 多个 burst 的 R beat 按 RID 交错返回 | PASS |
| `out_of_order_interleaving_flow` | 多个 burst 交错返回且后发 burst 先完成 | PASS |
| `invalid_rid_error_flow` | 返回未分配 RID，检查 bus fault | PASS |
| `aou_rcheck_ok_flow` | R 通道 CRC-8 校验正确，功能正常 | PASS |
| `aou_rcheck_error_flow` | 单 beat CRC-8 校验错误，上报 bus fault | PASS |
| `aou_rcheck_burst_error_flow` | 多 beat burst 中间 beat CRC-8 校验错误，上报 bus fault | PASS |
| `config_error_flow` | interval=0、非法 burst、非法 WRAP、lock 后写 | PASS |
| `latent_fault_flow` | 配置 shadow/反码注错，latent fault | PASS |

结果：

```text
PASS: safety_island_top full test completed, cases=17
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
| `read_interval_inv` | 配置寄存器 shadow stuck fault | `fault_detect`/latent 置位 | DETECTED, 2 cycles |
| `base_addr_inv_q0` | 配置表 base shadow stuck fault | `fault_detect`/latent 置位 | DETECTED, 2 cycles |
| `offset_inv_q0` | 配置表 offset shadow stuck fault | `fault_detect`/latent 置位 | DETECTED, 2 cycles |
| `mask_inv_q0` | 配置表 mask shadow stuck fault | `fault_detect`/latent 置位 | DETECTED, 2 cycles |
| `burst_type_inv_q0` | 配置表 burst type shadow stuck fault | `fault_detect`/latent 置位 | DETECTED, 2 cycles |
| `entry_valid_inv_q0` | 配置表 entry valid shadow stuck fault | `fault_detect`/latent 置位 | DETECTED, 2 cycles |
| `state_inv` | FSM 反码 stuck fault | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 3 cycles |
| `fault_or_accum_inv` | 累加器反码 stuck fault | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 3 cycles |
| `pending_wr_ptr` | pending FIFO 写指针 stuck fault | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 3 cycles |
| `pending_rd_ptr` | pending FIFO 读指针 stuck fault | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 3 cycles |
| `outstanding_count` | outstanding 计数 stuck fault | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 3 cycles |
| `axi_read_timeout` | 外部总线 timeout | `fault_detect` 置位，错误码 `0x21` | DETECTED |
| `axi_rresp_error` | AXI RRESP error | `fault_detect` 置位，错误码 `0x20` | DETECTED, 9 cycles |
| `axi_rid_mismatch` | AXI RID mismatch | `fault_detect` 置位，错误码 `0x20` | DETECTED, 9 cycles |
| `axi_rcheck_error` | AoU CRC-8 mismatch | `fault_detect` 置位，错误码 `0x20` | DETECTED, 9 cycles |
| `transient_state_inv` | FSM 反码瞬时翻转 | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 2 cycles |
| `transient_fault_or_accum_inv` | 累加器反码瞬时翻转 | 10 cycle 内 `safety_island_fault_detect` 置位 | DETECTED, 2 cycles |
| `transient_config_shadow` | 配置 shadow 瞬时翻转 | `fault_detect`/latent 置位 | DETECTED, 0 cycles |

统计结果：

```text
FI_SUMMARY: total=18 corrected=0 detected=18 undetected=0 protection_rate=100%
PASS: safety_island fault injection campaign completed
Errors: 0, Warnings: 0
```

波形输出：

- `SafeIsland/sim/out/safety_island_fault_injection/safety_island_fault_injection.wlf`
- `SafeIsland/sim/out/safety_island_fault_injection/safety_island_fault_injection.vcd`
- `SafeIsland/sim/out/safety_island_fault_injection/fault_injection_summary.txt`

## 剩余限制和建议

### 当前限制

- 配置 AXI slave 当前是单事务响应模型，不做配置侧 outstanding。
- 已有工程版 fault injection campaign 和保护率统计，但未做全网表/全寄存器随机 fault campaign 和 ISO 26262 级 SPFM/LFM 证明。
- 未做 formal/property 级 AXI 协议检查。

### 建议写入设计文档的 AoU

1. 监控 AXI read response 的 RID 必须匹配该 read engine 已发起且未完成的 ARID。
2. 外部对接模块必须为每个 R beat 生成 CRC-8 校验位，校验对象为 `{RID,RDATA,RRESP,RLAST}`，多项式 `0x07`、初值 `0x00`。
3. 5 路 AXI master 为独立通道，不要求跨 master 共享或重排 ID 空间。
4. `MAX_OUTSTANDING` 默认为 4，可参数化调整。
5. `safety_island_latent_fault_detect` 当前覆盖配置 shadow/反码错误和 core 内部安全岛故障，不代表完整 ASIL-D 诊断覆盖率证明。

### 后续可选增强

1. 补 ZOIX 环境脚本：在有 ZOIX 的环境中执行错误仿真。
2. 扩展认证级 fault campaign：自动遍历全网表/全寄存器 bit，统计 SPFM/LFM 所需覆盖率。
3. 加 AXI protocol assertion 或 formal lint，证明握手、RID 匹配、CRC 校验和 burst 行为。
