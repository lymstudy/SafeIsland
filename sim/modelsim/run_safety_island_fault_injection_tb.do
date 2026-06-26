quietly set script_dir [pwd]
quietly set sim_root [file normalize ../out/safety_island_fault_injection]
quietly set rtl_dir [file normalize ../../rtl]
quietly set tb_dir [file normalize ../../tb]
quietly set sim_lib [file join $sim_root work]
quietly set wlf_file [file join $sim_root safety_island_fault_injection.wlf]
quietly set vcd_file [file join $sim_root safety_island_fault_injection.vcd]
quietly set summary_file [file join $sim_root fault_injection_summary.txt]
quietly set csv_file [file join $sim_root fault_injection_report.csv]

if {[file exists $sim_root]} {
    file delete -force $sim_root
}
file mkdir $sim_root

vlib $sim_lib
vmap work $sim_lib

cd $rtl_dir
vlog -work $sim_lib -f safety_island_top.f
cd $script_dir
vlog -work $sim_lib [file join $tb_dir tb_safety_island_fault_injection.v]

vsim -lib $sim_lib -voptargs=+acc -wlf $wlf_file tb_safety_island_fault_injection +SUMMARY_FILE=$summary_file +CSV_FILE=$csv_file
log -r /*
vcd file $vcd_file
vcd add -r /*
run -all
vcd flush
quit -f
