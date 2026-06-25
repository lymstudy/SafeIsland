//=============================================================================
// axi_safety_island_pkg.vh — AXI Safety Island 公共定义头文件
//=============================================================================
// 符合 AXI4 协议规范 (ARM IHI0022H)
// 目标安全等级: ASIL-D (ISO 26262-5)
//=============================================================================

//-----------------------------------------------------------------------------
// 全局参数
//-----------------------------------------------------------------------------
`define AXI_DATA_WIDTH    64
`define AXI_ADDR_WIDTH    32
`define AXI_ID_WIDTH      8
`define AXI_STRB_WIDTH    (`AXI_DATA_WIDTH / 8)  // 8

//-----------------------------------------------------------------------------
// AXI Burst 类型 (ARBURST / AWBURST[1:0])
//-----------------------------------------------------------------------------
`define AXI_BURST_FIXED    2'b00
`define AXI_BURST_INCR     2'b01
`define AXI_BURST_WRAP     2'b10
`define AXI_BURST_RESERVED 2'b11

//-----------------------------------------------------------------------------
// AXI Response 编码 (RRESP / BRESP[1:0])
//-----------------------------------------------------------------------------
`define AXI_RESP_OKAY      2'b00
`define AXI_RESP_EXOKAY    2'b01
`define AXI_RESP_SLVERR    2'b10
`define AXI_RESP_DECERR    2'b11

//-----------------------------------------------------------------------------
// AXI Burst Size 编码 (ARSIZE / AWSIZE[2:0])
//-----------------------------------------------------------------------------
`define AXI_SIZE_1B        3'b000   //   8-bit (1 byte)
`define AXI_SIZE_2B        3'b001   //  16-bit (2 bytes)
`define AXI_SIZE_4B        3'b010   //  32-bit (4 bytes)
`define AXI_SIZE_8B        3'b011   //  64-bit (8 bytes)
`define AXI_SIZE_16B       3'b100   // 128-bit
`define AXI_SIZE_32B       3'b101   // 256-bit

//-----------------------------------------------------------------------------
// Safety Island 结构参数
//-----------------------------------------------------------------------------
`define NUM_MONITOR_CH      5        // 5路 AXI Master 监控通道
`define NUM_OFFSETS         64       // 每通道64个偏移地址
`define OFFSET_ADDR_WIDTH   6        // log2(64) = 6

//-----------------------------------------------------------------------------
// 配置寄存器地址映射 (64-bit 对齐, 字节地址)
//-----------------------------------------------------------------------------
// 控制寄存器组
`define ADDR_CTRL                64'h0000  // 控制寄存器 (enable, soft_reset, write_protect, fault_clear_policy)
`define ADDR_READ_INTERVAL       64'h0008  // 读取间隔 (时钟周期数)
`define ADDR_CONFIG_LOCK         64'h0010  // 配置锁定状态
`define ADDR_TIMEOUT_THRESHOLD   64'h0018  // AXI超时阈值 (时钟周期数)
`define ADDR_MAX_OUTSTANDING     64'h0020  // 最大 outstanding 事务数

// 基地址寄存器 (5路)
`define ADDR_BASE_ADDR_BASE      64'h0100  // BASE_ADDR[0] @ 0x0100
                                           // BASE_ADDR[1] @ 0x0108
                                           // BASE_ADDR[2] @ 0x0110
                                           // BASE_ADDR[3] @ 0x0118
                                           // BASE_ADDR[4] @ 0x0120

// 偏移地址寄存器组 (每路64个, 每个64-bit)
`define ADDR_OFFSET_BASE         64'h1000  // CH0 offsets start @ 0x1000
                                           // 64 entries × 8 bytes = 0x200 per channel
                                           // CH0: 0x1000 - 0x11F8
                                           // CH1: 0x1200 - 0x13F8
                                           // CH2: 0x1400 - 0x15F8
                                           // CH3: 0x1600 - 0x17F8
                                           // CH4: 0x1800 - 0x19F8

// Burst Type 寄存器组 (每路64个)
`define ADDR_BURST_TYPE_BASE     64'h2000  // 5 channels × 64 entries × 8 bytes

// Burst Length 寄存器组 (每路64个)
`define ADDR_BURST_LEN_BASE      64'h3000

// Mask 寄存器组 (每路64个)
`define ADDR_MASK_BASE           64'h4000

// Expected 寄存器组 (每路64个)
`define ADDR_EXPECTED_BASE       64'h5000

// 故障状态寄存器
`define ADDR_FAULT_STATUS        64'h6000  // 故障状态 (sticky, W1C)
`define ADDR_FAULT_COUNTER_BASE  64'h6100  // 故障计数器

// AoU 配置寄存器
`define ADDR_AOU_CONFIG          64'h7000  // AoU 校验配置

// 寄存器地址空间上限
`define ADDR_MAX_VALID           32'h7FFF

//-----------------------------------------------------------------------------
// CTRL 寄存器字段定义
//-----------------------------------------------------------------------------
`define CTRL_ENABLE_BIT          0         // bit 0: 安全岛使能
`define CTRL_SOFT_RESET_BIT      1         // bit 1: 软件复位
`define CTRL_WRITE_PROTECT_BIT   2         // bit 2: 写保护
`define CTRL_FAULT_CLEAR_BIT     3         // bit 3: 故障清除策略 (0=W1C, 1=auto)
`define CTRL_AOU_ENABLE_BIT      4         // bit 4: AoU 校验使能
`define CTRL_LATENT_CHECK_BIT    5         // bit 5: 潜在故障检测使能

//-----------------------------------------------------------------------------
// OFFSET 寄存器字段定义 (每个 offset 项 64-bit)
//-----------------------------------------------------------------------------
// [31:0]  : 偏移地址 (字节地址)
// [34:32] : 保留
// [35]    : 使能位 (1=启用此offset)
// [37:36] : Burst Type 覆写 (0=使用BURST_TYPE寄存器, 1=FIXED, 2=INCR, 3=WRAP)
// [45:38] : Burst Length 覆写 (0=使用BURST_LEN寄存器)
// [63:46] : 保留

`define OFFSET_ADDR_MASK          64'h00000000_FFFFFFFF
`define OFFSET_ENABLE_BIT         35
`define OFFSET_BURST_TYPE_LO      36
`define OFFSET_BURST_TYPE_HI      37
`define OFFSET_BURST_LEN_LO       38
`define OFFSET_BURST_LEN_HI       45

//-----------------------------------------------------------------------------
// 故障类型编码
//-----------------------------------------------------------------------------
`define FAULT_TYPE_EXTERNAL_MISMATCH    4'h0   // 外部寄存器 mismatch
`define FAULT_TYPE_AXI_TIMEOUT          4'h1   // AXI 超时
`define FAULT_TYPE_AXI_ERROR_RESP       4'h2   // AXI 错误响应 (SLVERR/DECERR)
`define FAULT_TYPE_ILLEGAL_CONFIG       4'h3   // 非法配置
`define FAULT_TYPE_INTERNAL_STUCK_AT    4'h4   // 内部 stuck-at 故障
`define FAULT_TYPE_INTERNAL_TRANSIENT   4'h5   // 内部瞬时翻转
`define FAULT_TYPE_AOU_ERROR            4'h6   // AoU 校验错误
`define FAULT_TYPE_LATENT_FAULT         4'h7   // 潜在故障
`define FAULT_TYPE_CONFIG_WRITE_PROTECT 4'h8   // 写保护违规
`define FAULT_TYPE_ADDR_MISALIGN        4'h9   // 地址非对齐
`define FAULT_TYPE_ADDR_OUT_OF_RANGE    4'hA   // 地址越界
`define FAULT_TYPE_BURST_NOT_SUPPORTED  4'hB   // burst 参数不支持

//-----------------------------------------------------------------------------
// 故障分类 (用于统计)
//-----------------------------------------------------------------------------
`define FAULT_CLASS_CORRECTED       2'b00  // 被自动纠正
`define FAULT_CLASS_DETECTED        2'b01  // 被 fault_detect 捕获
`define FAULT_CLASS_LATENT_DETECTED 2'b10  // 被 latent_fault_detect 捕获
`define FAULT_CLASS_NOT_DETECTED    2'b11  // 未检测到

//-----------------------------------------------------------------------------
// 故障注入类型
//-----------------------------------------------------------------------------
`define FAULT_INJ_STUCK_AT_0    3'b000
`define FAULT_INJ_STUCK_AT_1    3'b001
`define FAULT_INJ_TRANSIENT     3'b010
`define FAULT_INJ_TIMEOUT       3'b011
`define FAULT_INJ_ERROR_RESP    3'b100
`define FAULT_INJ_AOU_ERR       3'b101

//-----------------------------------------------------------------------------
// 调度器状态机
//-----------------------------------------------------------------------------
`define SCH_STATE_IDLE          3'b000
`define SCH_STATE_READING       3'b001
`define SCH_STATE_INTERVAL      3'b010
`define SCH_STATE_DRAIN         3'b011   // 安全停止中
`define SCH_STATE_ERROR         3'b100

//-----------------------------------------------------------------------------
// AXI Master 通道状态机
//-----------------------------------------------------------------------------
`define MST_STATE_IDLE          3'b000
`define MST_STATE_ADDR          3'b001   // 发送读地址
`define MST_STATE_DATA          3'b010   // 等待/接收读数据
`define MST_STATE_DONE          3'b011
`define MST_STATE_TIMEOUT       3'b100
`define MST_STATE_ERROR         3'b101

//=============================================================================
// AXI 通道信号宏 (便于实例化时统一接口)
//=============================================================================

// AXI Slave 接口信号 (从设备接收, 即上级配置源 → 本模块)
`define AXI_SLAVE_PORTS(dir, name) \
    input  wire                        clk,                    \
    input  wire                        rst_n,                  \
    /* Write Address Channel */                                \
    input  wire [`AXI_ID_WIDTH-1:0]    ``name``_awid,          \
    input  wire [`AXI_ADDR_WIDTH-1:0]  ``name``_awaddr,        \
    input  wire [7:0]                  ``name``_awlen,         \
    input  wire [2:0]                  ``name``_awsize,        \
    input  wire [1:0]                  ``name``_awburst,       \
    input  wire                        ``name``_awvalid,       \
    output wire                        ``name``_awready,       \
    /* Write Data Channel */                                   \
    input  wire [`AXI_DATA_WIDTH-1:0]  ``name``_wdata,         \
    input  wire [`AXI_STRB_WIDTH-1:0]  ``name``_wstrb,         \
    input  wire                        ``name``_wlast,         \
    input  wire                        ``name``_wvalid,        \
    output wire                        ``name``_wready,        \
    /* Write Response Channel */                               \
    output wire [`AXI_ID_WIDTH-1:0]    ``name``_bid,           \
    output wire [1:0]                  ``name``_bresp,         \
    output wire                        ``name``_bvalid,        \
    input  wire                        ``name``_bready,        \
    /* Read Address Channel */                                 \
    input  wire [`AXI_ID_WIDTH-1:0]    ``name``_arid,          \
    input  wire [`AXI_ADDR_WIDTH-1:0]  ``name``_araddr,        \
    input  wire [7:0]                  ``name``_arlen,         \
    input  wire [2:0]                  ``name``_arsize,        \
    input  wire [1:0]                  ``name``_arburst,       \
    input  wire                        ``name``_arvalid,       \
    output wire                        ``name``_arready,       \
    /* Read Data Channel */                                    \
    output wire [`AXI_ID_WIDTH-1:0]    ``name``_rid,           \
    output wire [`AXI_DATA_WIDTH-1:0]  ``name``_rdata,         \
    output wire [1:0]                  ``name``_rresp,         \
    output wire                        ``name``_rlast,         \
    output wire                        ``name``_rvalid,        \
    input  wire                        ``name``_rready

// AXI Master 接口信号 (主设备发出, 即本模块 → 外部)
`define AXI_MASTER_PORTS(dir, name) \
    /* Read Address Channel */                                 \
    output wire [`AXI_ID_WIDTH-1:0]   ``name``_arid,           \
    output wire [`AXI_ADDR_WIDTH-1:0] ``name``_araddr,         \
    output wire [7:0]                 ``name``_arlen,          \
    output wire [2:0]                 ``name``_arsize,         \
    output wire [1:0]                 ``name``_arburst,        \
    output wire                       ``name``_arvalid,        \
    input  wire                       ``name``_arready,        \
    /* Read Data Channel */                                    \
    input  wire [`AXI_ID_WIDTH-1:0]   ``name``_rid,            \
    input  wire [`AXI_DATA_WIDTH-1:0] ``name``_rdata,          \
    input  wire [1:0]                 ``name``_rresp,          \
    input  wire                       ``name``_rlast,          \
    input  wire                       ``name``_rvalid,         \
    output wire                       ``name``_rready

//=============================================================================
// 仿真辅助宏
//=============================================================================
`define PASS(msg)  $display("[PASS] %s", msg)
`define FAIL(msg)  begin $display("[FAIL] %s", msg); error_count = error_count + 1; end
`define CHECK(cond, msg) if (cond) `PASS(msg) else `FAIL(msg)

// 颜色输出 (仿真器终端支持)
`define COLOR_RED    "\033[31m"
`define COLOR_GREEN  "\033[32m"
`define COLOR_YELLOW "\033[33m"
`define COLOR_RESET  "\033[0m"

//-----------------------------------------------------------------------------
// Clean macro overrides for corrupted definitions above.
// Keep these at the end so the compiler uses the corrected values.
//-----------------------------------------------------------------------------
`undef ADDR_CTRL
`undef ADDR_READ_INTERVAL
`undef ADDR_CONFIG_LOCK
`undef ADDR_TIMEOUT_THRESHOLD
`undef ADDR_MAX_OUTSTANDING
`undef ADDR_BASE_ADDR_BASE
`undef ADDR_OFFSET_BASE
`undef ADDR_BURST_TYPE_BASE
`undef ADDR_BURST_LEN_BASE
`undef ADDR_MASK_BASE
`undef ADDR_EXPECTED_BASE
`undef ADDR_FAULT_STATUS
`undef ADDR_FAULT_COUNTER_BASE
`undef ADDR_AOU_CONFIG
`undef ADDR_MAX_VALID
`undef CTRL_ENABLE_BIT
`undef CTRL_SOFT_RESET_BIT
`undef CTRL_WRITE_PROTECT_BIT
`undef CTRL_FAULT_CLEAR_BIT
`undef CTRL_AOU_ENABLE_BIT
`undef CTRL_LATENT_CHECK_BIT
`undef FAULT_TYPE_CONFIG_WRITE_PROTECT
`undef FAULT_TYPE_ADDR_MISALIGN
`undef FAULT_TYPE_ADDR_OUT_OF_RANGE
`undef FAULT_CLASS_CORRECTED
`undef FAULT_CLASS_DETECTED

`define ADDR_CTRL                64'h0000
`define ADDR_READ_INTERVAL       64'h0008
`define ADDR_CONFIG_LOCK         64'h0010
`define ADDR_TIMEOUT_THRESHOLD   64'h0018
`define ADDR_MAX_OUTSTANDING     64'h0020
`define ADDR_BASE_ADDR_BASE      64'h0100
`define ADDR_OFFSET_BASE         64'h1000
`define ADDR_BURST_TYPE_BASE     64'h2000
`define ADDR_BURST_LEN_BASE      64'h3000
`define ADDR_MASK_BASE           64'h4000
`define ADDR_EXPECTED_BASE       64'h5000
`define ADDR_FAULT_STATUS        64'h6000
`define ADDR_FAULT_COUNTER_BASE  64'h6100
`define ADDR_AOU_CONFIG          64'h7000
`define ADDR_MAX_VALID           32'h7FFF

`define CTRL_ENABLE_BIT          0
`define CTRL_SOFT_RESET_BIT      1
`define CTRL_WRITE_PROTECT_BIT   2
`define CTRL_FAULT_CLEAR_BIT     3
`define CTRL_AOU_ENABLE_BIT      4
`define CTRL_LATENT_CHECK_BIT    5

`define FAULT_TYPE_CONFIG_WRITE_PROTECT 4'h8
`define FAULT_TYPE_ADDR_MISALIGN        4'h9
`define FAULT_TYPE_ADDR_OUT_OF_RANGE    4'hA
`define FAULT_CLASS_CORRECTED           2'b00
`define FAULT_CLASS_DETECTED            2'b01
