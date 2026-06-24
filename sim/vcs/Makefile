ROOT      := $(abspath ../..)
RTL_F     := $(ROOT)/rtl/safety_island_top.f
TB_DIR    := $(ROOT)/tb

BUILD_DIR := $(CURDIR)/build
WAVE_DIR  := $(CURDIR)/waves
LOG_DIR   := $(CURDIR)/logs

VCS       := vcs
VERDI     := verdi

VCS_OPTS  := -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps

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

.PHONY: all dirs full full-comp full-run fault fault-comp fault-run fdet fdet-comp fdet-run regress verdi-full verdi-fault verdi-fdet clean

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
	$(FULL_SIMV) +FSDB=$(FULL_FSDB) -l $(LOG_DIR)/full_run.log

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
	$(FAULT_SIMV) +FSDB=$(FAULT_FSDB) -l $(LOG_DIR)/fault_run.log

# ── Fault detector unit test (NEW) ──
fdet: fdet-comp fdet-run

fdet-comp: dirs
	$(VCS) $(VCS_OPTS) \
		-F $(RTL_F) \
		$(FDET_TB) \
		-top $(FDET_TOP) \
		-o $(FDET_SIMV) \
		-l $(LOG_DIR)/fdet_compile.log

fdet-run:
	$(FDET_SIMV) +FSDB=$(FDET_FSDB) -l $(LOG_DIR)/fdet_run.log

# ── Full regression (all test suites) ──
regress: full fault fdet

verdi-full:
	$(VERDI) -ssf $(FULL_FSDB) -sv -f $(RTL_F) $(FULL_TB) -top $(FULL_TOP) &

verdi-fault:
	$(VERDI) -ssf $(FAULT_FSDB) -sv -f $(RTL_F) $(FAULT_TB) -top $(FAULT_TOP) &

verdi-fdet:
	$(VERDI) -ssf $(FDET_FSDB) -sv -f $(RTL_F) $(FDET_TB) -top $(FDET_TOP) &

clean:
	rm -rf $(BUILD_DIR) $(WAVE_DIR) $(LOG_DIR)
	rm -rf csrc simv simv.daidir *.daidir novas.* verdiLog ucli.key DVEfiles