quietly set script_dir [pwd]
quietly set sim_root [file normalize ../out/safety_island_top_basic]
quietly set rtl_dir [file normalize ../../rtl]
quietly set tb_dir [file normalize ../../tb]
quietly set sim_lib [file join $sim_root work]

if {[file exists $sim_root]} {
    file delete -force $sim_root
}
file mkdir $sim_root

vlib $sim_lib
vmap work $sim_lib

cd $rtl_dir
vlog -work $sim_lib -f safety_island_top.f
cd $script_dir
vlog -work $sim_lib [file join $tb_dir tb_safety_island_top_basic.v]

vsim -lib $sim_lib tb_safety_island_top_basic
run -all
quit -f
