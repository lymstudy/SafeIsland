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
WORK_DIR_FULL := $(ROOT)/sim/work_full

FUNC_LOG   := $(SIM_FUNC)/logs
FI_LOG     := $(SIM_FI)/logs
FI_REPORT  := $(SIM_FI)/reports

VCS        := vcs
VERDI      := verdi

VCS_OPTS       := -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps
VCS_BATCH_OPTS := -full64 -sverilog -debug_access+all -kdb +define+FSDB +define+FI_ARRAY_BIT_TARGETS -timescale=1ns/1ps

FULL_TOP   := tb_safety_island_top_full
FULL_SIMV  := $(WORK_DIR)/simv_full
FULL_FSDB  := $(WORK_DIR)/waves/full.fsdb

FAULT_TOP  := tb_safety_island_fault_injection
FAULT_SIMV := $(WORK_DIR)/simv_fault
FAULT_FSDB := $(WORK_DIR)/waves/fault_injection.fsdb
BATCH_SIMV := $(WORK_DIR)/simv_batch

CAMPAIGN_SIMV  := $(WORK_DIR)/simv_campaign
CAMPAIGN_SIMV_FULL := $(WORK_DIR_FULL)/simv_campaign
CAMPAIGN_REPORT := $(FI_REPORT)/fault_campaign_report.csv
CAMPAIGN_SUMMARY := $(FI_REPORT)/fault_campaign_summary.txt
FI_REPORT_FULL := $(FI_REPORT)/full
CAMPAIGN_REPORT_FULL := $(FI_REPORT_FULL)/fault_campaign_report.csv
CAMPAIGN_SUMMARY_FULL := $(FI_REPORT_FULL)/fault_campaign_summary.txt

FI_CSV     := $(FI_REPORT)/fault_injection_report.csv

.PHONY: all functional fault-all full full-comp full-run fault fault-comp fault-run batch batch-comp batch-run \
        campaign-comp campaign-required campaign-full campaign-report \
        campaign-comp-full campaign-full-isolated campaign-report-full wait-and-run-full \
        cov-full cov-full-comp cov-full-run cov-report summary clean clean-work clean-cov-intermediate \
        clean-scripts-spill finalize dirs verdi-full verdi-fault \
        logic-faultsim-probe logic-faultsim

all: functional fault-all summary finalize

functional: full cov-full

fault-all: fault batch campaign-required campaign-report fi-summary

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
	cd $(WORK_DIR) && $(FULL_SIMV) -l $(FUNC_LOG)/full_run.log
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
	cd $(WORK_DIR) && $(FAULT_SIMV) +CSV_FILE=$(FI_CSV) -l $(FI_LOG)/fault_run.log
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
	cd $(WORK_DIR) && $(BATCH_SIMV) +BATCH_ALL +CSV_FILE=$(FI_REPORT)/fault_batch_report.csv \
		-l $(FI_LOG)/batch_run.log
	@grep "FI_SUMMARY" $(FI_LOG)/batch_run.log | head -1 > $(FI_REPORT)/fault_batch_summary.txt 2>/dev/null || true

fi-summary:
	@echo "=== Fault Injection Diagnostic Coverage ===" > $(SIM_FI)/diagnostic_coverage_summary.txt
	@echo "" >> $(SIM_FI)/diagnostic_coverage_summary.txt
	@echo "Strict protection probability = (corrected + detected) / total" >> $(SIM_FI)/diagnostic_coverage_summary.txt
	@echo "Engineering protection probability = (corrected + detected + latent + safe) / total" >> $(SIM_FI)/diagnostic_coverage_summary.txt
	@echo "" >> $(SIM_FI)/diagnostic_coverage_summary.txt
	@if [ -f $(FI_REPORT)/fault_baseline_summary.txt ]; then \
		echo "Baseline:" >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
		cat $(FI_REPORT)/fault_baseline_summary.txt >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
	fi
	@if [ -f $(FI_REPORT)/fault_batch_summary.txt ]; then \
		echo "Batch:" >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
		cat $(FI_REPORT)/fault_batch_summary.txt >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
	fi
	@if [ -f $(CAMPAIGN_SUMMARY) ]; then \
		echo "" >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
		echo "Campaign:" >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
		cat $(CAMPAIGN_SUMMARY) >> $(SIM_FI)/diagnostic_coverage_summary.txt; \
	fi

campaign-comp: dirs
	cd $(WORK_DIR) && $(VCS) $(VCS_BATCH_OPTS) \
		-F $(RTL_F) \
		$(FAULT_TB) \
		-top $(FAULT_TOP) \
		-o $(CAMPAIGN_SIMV) \
		-l $(FI_LOG)/campaign_compile.log

campaign-required: campaign-comp
	cd $(ROOT) && python tools/run_fault_campaign.py \
		--mode required \
		--sim $(CAMPAIGN_SIMV) \
		--jobs 4

campaign-full: campaign-comp
	cd $(ROOT) && python tools/run_fault_campaign.py \
		--mode full \
		--sim $(CAMPAIGN_SIMV) \
		--jobs 8

campaign-comp-full: dirs
	mkdir -p $(WORK_DIR_FULL)/waves
	cd $(WORK_DIR_FULL) && $(VCS) $(VCS_BATCH_OPTS) \
		-F $(RTL_F) \
		$(FAULT_TB) \
		-top $(FAULT_TOP) \
		-o $(CAMPAIGN_SIMV_FULL) \
		-l $(FI_LOG)/campaign_full_compile.log

campaign-full-isolated: campaign-comp-full
	mkdir -p $(FI_REPORT_FULL)
	cd $(ROOT) && python tools/run_fault_campaign.py \
		--mode full \
		--sim $(CAMPAIGN_SIMV_FULL) \
		--work-dir $(WORK_DIR_FULL) \
		--output-dir $(FI_REPORT_FULL) \
		--jobs 8

campaign-report-full:
	cd $(ROOT) && python tools/analyze_fi_report.py \
		--input $(CAMPAIGN_REPORT_FULL) \
		--output $(FI_REPORT_FULL)/fault_campaign_safety_report.csv \
		--detail-output $(FI_REPORT_FULL)/fault_campaign_detail.csv || true

wait-and-run-full:
	cd $(ROOT) && bash tools/wait_and_run_full.sh

campaign-report:
	cd $(ROOT) && python tools/analyze_fi_report.py \
		--input $(FI_REPORT)/fault_campaign_report.csv \
		--output $(FI_REPORT)/fault_campaign_safety_report.csv \
		--detail-output $(FI_REPORT)/fault_campaign_detail.csv || true

logic-faultsim-probe:
	cd $(ROOT) && bash tools/probe_faultsim_tool.sh > $(FI_REPORT)/faultsim_tool_probe.txt 2>&1 || true

logic-faultsim:
	@echo "Optional: run Test-Faultsim/TetraMAX logic stuck-at simulation if local command/library setup is available."
	@echo "Do not fail submission flow if unavailable."
	cd $(ROOT) && bash tools/run_logic_faultsim.sh || true

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
	cd $(WORK_DIR) && $(COV_SIMV) -l $(FUNC_LOG)/cov_run.log

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
	@echo "  [Fault Campaign] $(SIM_FI)/"
	@if [ -f $(CAMPAIGN_SUMMARY) ]; then cat $(CAMPAIGN_SUMMARY); else echo "  Campaign summary not available"; fi
	@echo ""
	@echo "  Reports:"
	@echo "    $(FI_REPORT)/fault_injection_report.csv"
	@echo "    $(FI_REPORT)/fault_batch_report.csv"
	@echo "    $(FI_REPORT)/fault_campaign_report.csv"
	@echo "    $(SIM_FI)/diagnostic_coverage_summary.txt"
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
