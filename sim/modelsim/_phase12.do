quietly set sim_root [file normalize D:/studydoc/competition/PIC/SafeIsland-main/sim/out/safety_island_fault_injection]
quietly set sim_lib [file join $sim_root work]
if {[file exists $sim_root]} { file delete -force $sim_root }
file mkdir $sim_root
vlib $sim_lib
vmap work $sim_lib
cd D:/studydoc/competition/PIC/SafeIsland-main/rtl
vlog -work $sim_lib +define+FI_ARRAY_BIT_TARGETS -f safety_island_top.f

cd D:/studydoc/competition/PIC/SafeIsland-main/sim/modelsim
vlog -work $sim_lib +define+FI_ARRAY_BIT_TARGETS D:/studydoc/competition/PIC/SafeIsland-main/tb/tb_safety_island_fault_injection.v
vsim -lib $sim_lib -voptargs=+acc -c tb_safety_island_fault_injection +BATCH_ALL
log -r /*
run -all
quit -f
