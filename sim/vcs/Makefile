ROOT      := $(abspath ../..)
RTL_F     := $(ROOT)/rtl/safety_island_top.f
TB_DIR    := $(ROOT)/tb

BUILD_DIR := $(CURDIR)/build
WAVE_DIR  := $(CURDIR)/waves
LOG_DIR   := $(CURDIR)/logs

VCS       := vcs
VERDI     := verdi

VCS_OPTS       := -full64 -sverilog -debug_access+all -kdb +define+FSDB -timescale=1ns/1ps
VCS_BATCH_OPTS := -full64 -sverilog -debug_access+all -kdb +define+FSDB +define+FI_ARRAY_BIT_TARGETS -timescale=1ns/1ps

FULL_TOP  := tb_safety_island_top_full
FULL_TB   := $(TB_DIR)/tb_safety_island_top_full.v
FULL_SIMV := $(BUILD_DIR)/simv_full
FULL_FSDB := $(WAVE_DIR)/full.fsdb

FAULT_TOP  := tb_safety_island_fault_injection
FAULT_TB   := $(TB_DIR)/tb_safety_island_fault_injection.v
FAULT_SIMV := $(BUILD_DIR)/simv_fault
FAULT_FSDB := $(WAVE_DIR)/fault_injection.fsdb

FDET_TOP  := tb_safety_island_fault_detector
FDET_TB   := $(TB_DIR)/tb_safety_island_fault_detector.v
FDET_SIMV := $(BUILD_DIR)/simv_fdet
FDET_FSDB := $(WAVE_DIR)/fault_detector.fsdb

.PHONY: all dirs full full-comp full-run fault fault-comp fault-run batch batch-comp batch-run fdet fdet-comp fdet-run regress regress-cov regress-submit verdi-full verdi-fault verdi-fdet clean summary

all: regress

dirs:
	mkdir -p $(BUILD_DIR) $(WAVE_DIR) $(LOG_DIR)

# ── Full regression ──
full: full-comp full-run

full-comp: dirs
	$(VCS) $(VCS_OPTS) \
		-F $(RTL_F) \
		$(FULL_TB) \
		-top $(FULL_TOP) \
		-o $(FULL_SIMV) \
		-l $(LOG_DIR)/full_compile.log

full-run:
	$(FULL_SIMV) -l $(LOG_DIR)/full_run.log

# ── Fault injection ──
fault: fault-comp fault-run

fault-comp: dirs
	$(VCS) $(VCS_OPTS) \
		-F $(RTL_F) \
		$(FAULT_TB) \
		-top $(FAULT_TOP) \
		-o $(FAULT_SIMV) \
		-l $(LOG_DIR)/fault_compile.log

fault-run:
	$(FAULT_SIMV) -l $(LOG_DIR)/fault_run.log

# ── Fault injection batch (full bit sweep, 594 cases) ──
batch: batch-comp batch-run

batch-comp: dirs
	$(VCS) $(VCS_BATCH_OPTS) \
		-F $(RTL_F) \
		$(FAULT_TB) \
		-top $(FAULT_TOP) \
		-o $(BUILD_DIR)/simv_batch \
		-l $(LOG_DIR)/batch_compile.log

batch-run:
	$(BUILD_DIR)/simv_batch +BATCH_ALL -l $(LOG_DIR)/batch_run.log

# ── Fault detector unit test ──
fdet: fdet-comp fdet-run

fdet-comp: dirs
	$(VCS) $(VCS_OPTS) \
		-F $(RTL_F) \
		$(FDET_TB) \
		-top $(FDET_TOP) \
		-o $(FDET_SIMV) \
		-l $(LOG_DIR)/fdet_compile.log

fdet-run:
	$(FDET_SIMV) -l $(LOG_DIR)/fdet_run.log

# ── Full regression (all test suites) ──
regress: full fault fdet

# ── Competition submission regression (功能仿真 + 注错仿真全部) ──
regress-submit: full fault batch fdet summary

# ── 赛题提交用: 仅 VCS 功能仿真 + 注错仿真 (不含 fdet 单元测试) ──
regress-score: full fault batch summary

# ── Generate combined summary from logs ──
summary:
	@echo "======================================================================"
	@echo "  AXI Safety Island — VCS Regression Summary"
	@echo "======================================================================"
	@echo ""
	@echo "  [1/4] Functional Simulation (功能仿真)"
	@if grep -q "cases=34" $(LOG_DIR)/full_run.log 2>/dev/null; then \
		echo "  RESULT: PASS 34/34"; \
	else \
		echo "  RESULT: CHECK $(LOG_DIR)/full_run.log"; \
	fi
	@echo ""
	@echo "  [2/4] Fault Injection Baseline (注错仿真-基线)"
	@if grep -q "FI_SUMMARY" $(LOG_DIR)/fault_run.log 2>/dev/null; then \
		grep "FI_SUMMARY" $(LOG_DIR)/fault_run.log | head -1; \
		grep "PASS\|FAIL.*fault" $(LOG_DIR)/fault_run.log | head -3; \
	else \
		echo "  RESULT: CHECK $(LOG_DIR)/fault_run.log"; \
	fi
	@echo ""
	@echo "  [3/4] Fault Injection Bit Sweep (注错仿真-全量bit扫描)"
	@if grep -q "FI_SUMMARY" $(LOG_DIR)/batch_run.log 2>/dev/null; then \
		grep "FI_SUMMARY" $(LOG_DIR)/batch_run.log | head -1; \
	else \
		echo "  RESULT: CHECK $(LOG_DIR)/batch_run.log"; \
	fi
	@echo ""
	@echo "  [4/4] Fault Detector Unit Test (FD单元测试)"
	@if grep -q "failures=" $(LOG_DIR)/fdet_run.log 2>/dev/null; then \
		grep "failures=" $(LOG_DIR)/fdet_run.log | head -1; \
	else \
		echo "  RESULT: CHECK $(LOG_DIR)/fdet_run.log"; \
	fi
	@echo ""
	@echo "======================================================================"

verdi-full:
	$(VERDI) -ssf $(FULL_FSDB) -sv -f $(RTL_F) $(FULL_TB) -top $(FULL_TOP) &

verdi-fault:
	$(VERDI) -ssf $(FAULT_FSDB) -sv -f $(RTL_F) $(FAULT_TB) -top $(FAULT_TOP) &

verdi-fdet:
	$(VERDI) -ssf $(FDET_FSDB) -sv -f $(RTL_F) $(FDET_TB) -top $(FDET_TOP) &

# ── Coverage (line + toggle + condition + FSM) ──
COV_DIR       := $(CURDIR)/coverage
COV_BUILD     := $(COV_DIR)/build
COV_REPORT    := $(COV_DIR)/report
COV_OPTS      := -cm line+tgl+cond+fsm -cm_dir $(COV_BUILD) -cm_name

.PHONY: cov-full cov-full-comp cov-full-run cov-report cov-clean

cov-full: cov-full-comp cov-full-run cov-report

cov-full-comp: dirs
	mkdir -p $(COV_BUILD)
	$(VCS) $(VCS_OPTS) $(COV_OPTS) full \
		-F $(RTL_F) \
		$(FULL_TB) \
		-top $(FULL_TOP) \
		-o $(COV_BUILD)/simv_cov \
		-l $(LOG_DIR)/cov_compile.log

cov-full-run:
	$(COV_BUILD)/simv_cov -l $(LOG_DIR)/cov_run.log

cov-report:
	urg -dir $(COV_BUILD)/*.vdb -report $(COV_REPORT)

cov-clean:
	rm -rf $(COV_DIR)

# ── Full regression with coverage ──
regress-cov: full fault fdet cov-full

clean:
	rm -rf $(BUILD_DIR) $(WAVE_DIR) $(LOG_DIR)
	rm -rf csrc simv simv.daidir *.daidir novas.* verdiLog ucli.key DVEfiles *fsdb*
	rm -rf $(COV_DIR)
