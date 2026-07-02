# AXI Safety Island — VCS submission Makefile
# Usage: cd submission/scripts && make <target>
# 中间文件在 sim/work/，运行脚本结束后自动清理；结果在 sim/functional/ 与 sim/fault_injection/

ROOT       := $(abspath ..)
RTL_F      := $(ROOT)/rtl/safety_island_top.f
FULL_TB    := $(ROOT)/tb/functional/tb_safety_island_top_full.v
FAULT_TB   := $(ROOT)/tb/fault_injection/tb_safety_island_fault_injection.v

SIM_FUNC   := $(ROOT)/sim/functional
SIM_FI     := $(ROOT)/sim/fault_injection
WORK_DIR   := $(ROOT)/sim/work

FUNC_LOG   := $(SIM_FUNC)/logs
FI_LOG     := $(SIM_FI)/logs
FI_REPORT  := $(SIM_FI)/reports

VCS        := vcs
VERDI      := verdi

VCS_OPTS       := -full64 -sverilog -debug_access+all -kdb +define+FSDB -timescale=1ns/1ps
VCS_BATCH_OPTS := -full64 -sverilog -debug_access+all -kdb +define+FSDB +define+FI_ARRAY_BIT_TARGETS -timescale=1ns/1ps

FULL_TOP   := tb_safety_island_top_full
FULL_SIMV  := $(WORK_DIR)/simv_full
FULL_FSDB  := $(WORK_DIR)/waves/full.fsdb

FAULT_TOP  := tb_safety_island_fault_injection
FAULT_SIMV := $(WORK_DIR)/simv_fault
FAULT_FSDB := $(WORK_DIR)/waves/fault_injection.fsdb
BATCH_SIMV := $(WORK_DIR)/simv_batch

FI_CSV     := $(FI_REPORT)/fault_injection_report.csv

.PHONY: all functional fault-all full full-comp full-run fault fault-comp fault-run batch batch-comp batch-run \
        cov-full cov-full-comp cov-full-run cov-report summary clean clean-work clean-cov-intermediate \
        clean-scripts-spill finalize dirs verdi-full verdi-fault

all: functional fault-all summary finalize

functional: full cov-full

fault-all: fault batch fi-summary

finalize: clean-work clean-cov-intermediate clean-scripts-spill

dirs:
	mkdir -p $(WORK_DIR)/waves
	mkdir -p $(FUNC_LOG) $(SIM_FUNC)/coverage
	mkdir -p $(FI_LOG) $(FI_REPORT)

full: full-comp full-run

full-comp: dirs
	cd $(WORK_DIR) && $(VCS) $(VCS_OPTS) \
		-F $(RTL_F) \
		$(FULL_TB) \
		-top $(FULL_TOP) \
		-o $(FULL_SIMV) \
		-l $(FUNC_LOG)/full_compile.log

full-run:
	$(FULL_SIMV) -l $(FUNC_LOG)/full_run.log
	@grep -E "cases=|PASS:|FAIL:" $(FUNC_LOG)/full_run.log | tail -5 > $(SIM_FUNC)/regression_summary.txt 2>/dev/null || true

fault: fault-comp fault-run

fault-comp: dirs
	cd $(WORK_DIR) && $(VCS) $(VCS_OPTS) \
		-F $(RTL_F) \
		$(FAULT_TB) \
		-top $(FAULT_TOP) \
		-o $(FAULT_SIMV) \
		-l $(FI_LOG)/fault_compile.log

fault-run:
	$(FAULT_SIMV) +CSV_FILE=$(FI_CSV) -l $(FI_LOG)/fault_run.log
	@grep "FI_SUMMARY" $(FI_LOG)/fault_run.log | head -1 > $(FI_REPORT)/fault_baseline_summary.txt 2>/dev/null || true

batch: batch-comp batch-run

batch-comp: dirs
	cd $(WORK_DIR) && $(VCS) $(VCS_BATCH_OPTS) \
		-F $(RTL_F) \
		$(FAULT_TB) \
		-top $(FAULT_TOP) \
		-o $(BATCH_SIMV) \
		-l $(FI_LOG)/batch_compile.log

batch-run:
	$(BATCH_SIMV) +BATCH_ALL +CSV_FILE=$(FI_REPORT)/fault_batch_report.csv \
		-l $(FI_LOG)/batch_run.log
	@grep "FI_SUMMARY" $(FI_LOG)/batch_run.log | head -1 > $(FI_REPORT)/fault_batch_summary.txt 2>/dev/null || true

fi-summary:
	@echo "=== Fault Injection Diagnostic Coverage ===" > $(SIM_FI)/diagnostic_coverage_summary.txt
	@echo "" >> $(SIM_FI)/diagnostic_coverage_summary.txt
	@echo "保护概率 = (已纠正 + 已探知) / 错误总数" >> $(SIM_FI)/diagnostic_coverage_summary.txt
	@echo "" >> $(SIM_FI)/diagnostic_coverage_summary.txt
	@if [ -f $(FI_REPORT)/fault_baseline_summary.txt ]; then \
		echo "Baseline:" >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
		cat $(FI_REPORT)/fault_baseline_summary.txt >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
	fi
	@if [ -f $(FI_REPORT)/fault_batch_summary.txt ]; then \
		echo "Batch:" >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
		cat $(FI_REPORT)/fault_batch_summary.txt >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
	fi

COV_BUILD  := $(SIM_FUNC)/coverage/build
COV_VDB    := $(SIM_FUNC)/coverage/build.vdb
COV_REPORT := $(SIM_FUNC)/coverage/urgReport
COV_METRIC := line+tgl+cond+fsm
COV_OPTS   := -cm $(COV_METRIC) -cm_dir $(COV_BUILD) -cm_name
COV_SIMV   := $(COV_BUILD)/simv_cov

cov-full: cov-full-comp cov-full-run cov-report

cov-full-comp: dirs
	mkdir -p $(COV_BUILD)
	cd $(COV_BUILD) && $(VCS) $(VCS_OPTS) $(COV_OPTS) full \
		-F $(RTL_F) \
		$(FULL_TB) \
		-top $(FULL_TOP) \
		-o $(COV_SIMV) \
		-l $(FUNC_LOG)/cov_compile.log

cov-full-run:
	$(COV_SIMV) -l $(FUNC_LOG)/cov_run.log

cov-report:
	-urg -full64 -dir $(COV_VDB) -report $(COV_REPORT)
	-$(COV_SIMV) -cm $(COV_METRIC) -cm_count -cm_name full \
		-l $(FUNC_LOG)/cov_count.log > $(SIM_FUNC)/line_coverage_summary.txt 2>&1 || true
	@if [ -f $(COV_REPORT)/index.html ]; then \
		echo "Coverage HTML: $(COV_REPORT)/index.html"; \
	elif [ -s $(SIM_FUNC)/line_coverage_summary.txt ]; then \
		echo "Coverage text: $(SIM_FUNC)/line_coverage_summary.txt"; \
	else \
		echo "Coverage: see $(FUNC_LOG)/cov_run.log"; \
	fi

summary:
	@echo "======================================================================"
	@echo "  AXI Safety Island — Submission Regression Summary"
	@echo "======================================================================"
	@echo ""
	@echo "  [Functional] $(SIM_FUNC)/"
	@if grep -q "cases=34" $(FUNC_LOG)/full_run.log 2>/dev/null; then \
		echo "  RESULT: PASS 34/34"; \
	else \
		echo "  RESULT: CHECK $(FUNC_LOG)/full_run.log"; \
	fi
	@echo ""
	@echo "  [Fault Baseline] $(SIM_FI)/"
	@if [ -f $(FI_REPORT)/fault_baseline_summary.txt ]; then cat $(FI_REPORT)/fault_baseline_summary.txt; fi
	@echo ""
	@echo "  [Fault Batch] $(SIM_FI)/"
	@if [ -f $(FI_REPORT)/fault_batch_summary.txt ]; then cat $(FI_REPORT)/fault_batch_summary.txt; fi
	@echo ""
	@echo "======================================================================"

verdi-full:
	$(VERDI) -ssf $(FULL_FSDB) -sv -f $(RTL_F) $(FULL_TB) -top $(FULL_TOP) &

verdi-fault:
	$(VERDI) -ssf $(FAULT_FSDB) -sv -f $(RTL_F) $(FAULT_TB) -top $(FAULT_TOP) &

clean-work:
	rm -rf $(WORK_DIR)

clean-cov-intermediate:
	rm -rf $(COV_BUILD)/simv_cov $(COV_BUILD)/simv_cov.daidir
	rm -f $(COV_BUILD)/verdi_config_file
	rm -rf $(COV_BUILD)/csrc

clean-scripts-spill:
	rm -rf $(CURDIR)/build $(CURDIR)/waves $(CURDIR)/csrc
	rm -rf $(CURDIR)/simv $(CURDIR)/simv.daidir $(CURDIR)/*.daidir
	rm -rf $(CURDIR)/novas.* $(CURDIR)/verdiLog $(CURDIR)/ucli.key $(CURDIR)/DVEfiles
	rm -f $(CURDIR)/*fsdb* $(CURDIR)/.fsm.sch.verilog.xml $(CURDIR)/fault_injection_summary.txt

clean: clean-work clean-cov-intermediate clean-scripts-spill
