quietly set sim_root ../../out/axi_master

if {![file exists $sim_root]} {
    file mkdir $sim_root
}

quietly set run_tag [format "%s_%s" [clock seconds] [pid]]
quietly set sim_lib [file join $sim_root [format "run_work_%s" $run_tag]]
quietly set log_file [file join $sim_root [format "transcript_%s.log" $run_tag]]

vlib $sim_lib
transcript file $log_file

vlog -work $sim_lib ../../../tb/axi/axi_slave_mem_model.v ../../../rtl/AXI/axi_master.v ../../../tb/axi/tb_axi_master.v
vsim -lib $sim_lib tb_axi_master
run -all
if {[file exists transcript]} {
    file delete -force transcript
}
quit -f
