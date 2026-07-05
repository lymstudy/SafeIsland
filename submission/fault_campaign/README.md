# Fault Campaign 注错配置

## 文件说明

| 文件 | 说明 |
|------|------|
| `Register_fault_list.csv` | post-TMR 寄存器故障清单（208182 行，bit 级） |
| `Logic_fault_list.csv` | post-TMR 逻辑故障清单（6641 行，460 信号点 bit 级展开） |
| `legacy_logic_signal_list.csv` | 升级前 459 信号级逻辑清单（`gen_fault_lists.py` 输入，勿删） |
| `fault_smoke_tmr.csv` | 升级后 smoke 用例（14 项，待 FI TB 接入） |
| `Register_fault_summary.txt` | 寄存器清单汇总 |
| `Logic_fault_summary.txt` | 逻辑清单汇总 |
| `safety_metrics_report.csv` | SPFM/LFM 指标（campaign 待重跑） |

## 生成与统计

```bash
cd submission

python tools/gen_fault_lists.py

python tools/analyze_fi_report.py \
  --input sim/fault_injection/reports/fault_injection_report.csv \
  --output sim/fault_injection/reports/safety_report.csv

python tools/gen_safety_report.py \
  --fi-report sim/fault_injection/reports/fault_injection_report.csv

python tools/update_safety_docs.py
```

## 注错分母合计

Register 208182 + Logic 6641 = **214823** 行

## 待办（FI TB 升级后）

1. 扩展 `tb_safety_island_fault_injection.v` 支持 TMR 路径
2. 接入 `fault_smoke_tmr.csv` 首批回归
3. 重跑 `make fault-all`，更新 `sim/fault_injection/diagnostic_coverage_summary.txt`
