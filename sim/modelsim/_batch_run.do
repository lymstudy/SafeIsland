
quietly set script_dir [pwd]
quietly set sim_root [file normalize ../out/safety_island_fault_injection]
quietly set rtl_dir [file normalize ../../rtl]
quietly set tb_dir [file normalize ../../tb]
quietly set sim_lib [file join $sim_root work]

if {[file exists $sim_root]} { file delete -force $sim_root }
file mkdir $sim_root
vlib $sim_lib
vmap work $sim_lib

cd $rtl_dir
vlog -work $sim_lib +define+FI_ARRAY_BIT_TARGETS -f safety_island_top.f
cd $script_dir
vlog -work $sim_lib +define+FI_ARRAY_BIT_TARGETS [file join $tb_dir tb_safety_island_fault_injection.v]

vsim -lib $sim_lib -voptargs=+acc -c tb_safety_island_fault_injection +BATCH_ALL
log -r /*
run -all
quit -f
