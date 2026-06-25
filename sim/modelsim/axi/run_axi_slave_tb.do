quietly set sim_root ../../out/axi_slave

if {![file exists $sim_root]} {
    file mkdir $sim_root
}

quietly set run_tag [format "%s_%s" [clock seconds] [pid]]
quietly set sim_lib [file join $sim_root [format "run_work_%s" $run_tag]]
quietly set vcd_file [file join $sim_root "axi_slave_wave.vcd"]
quietly set log_file [file join $sim_root [format "transcript_%s.log" $run_tag]]

vlib $sim_lib
transcript file $log_file

vlog -work $sim_lib ../../../rtl/AXI/axi_slave.v ../../../tb/axi/tb_axi_slave.v
vsim -lib $sim_lib -voptargs=+acc tb_axi_slave
vcd file $vcd_file
vcd add -r /tb_axi_slave/*
run -all
if {[file exists transcript]} {
    file delete -force transcript
}
quit -f
