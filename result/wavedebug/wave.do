onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_safety_island_top_full/clk
add wave -noupdate /tb_safety_island_top_full/rst
add wave -noupdate /tb_safety_island_top_full/fault_detect
add wave -noupdate /tb_safety_island_top_full/safety_island_fault_detect
add wave -noupdate /tb_safety_island_top_full/safety_island_latent_fault_detect
add wave -noupdate /tb_safety_island_top_full/fault_or_result
add wave -noupdate /tb_safety_island_top_full/core_error_code
add wave -noupdate -expand -group {AXI SLAVE Wr} /tb_safety_island_top_full/s_axi_awaddr
add wave -noupdate -expand -group {AXI SLAVE Wr} /tb_safety_island_top_full/s_axi_awvalid
add wave -noupdate -expand -group {AXI SLAVE Wr} /tb_safety_island_top_full/s_axi_awready
add wave -noupdate -expand -group {AXI SLAVE Wr} /tb_safety_island_top_full/s_axi_wdata
add wave -noupdate -expand -group {AXI SLAVE Wr} /tb_safety_island_top_full/s_axi_wvalid
add wave -noupdate -expand -group {AXI SLAVE Wr} /tb_safety_island_top_full/s_axi_wready
add wave -noupdate -expand -group {AXI SLAVE Wr} /tb_safety_island_top_full/s_axi_bresp
add wave -noupdate -expand -group {AXI SLAVE Wr} /tb_safety_island_top_full/s_axi_bvalid
add wave -noupdate -expand -group {AXI SLAVE Wr} /tb_safety_island_top_full/s_axi_bready
add wave -noupdate -expand -group {AXI Master Read} /tb_safety_island_top_full/m_axi_araddr_flat
add wave -noupdate -expand -group {AXI Master Read} /tb_safety_island_top_full/m_axi_arlen_flat
add wave -noupdate -expand -group {AXI Master Read} /tb_safety_island_top_full/m_axi_arburst_flat
add wave -noupdate -expand -group {AXI Master Read} /tb_safety_island_top_full/m_axi_arvalid_flat
add wave -noupdate -expand -group {AXI Master Read} /tb_safety_island_top_full/m_axi_arready_flat
add wave -noupdate -expand -group {AXI Master Read} /tb_safety_island_top_full/m_axi_rdata_flat
add wave -noupdate -expand -group {AXI Master Read} /tb_safety_island_top_full/m_axi_rresp_flat
add wave -noupdate -expand -group {AXI Master Read} /tb_safety_island_top_full/m_axi_rlast_flat
add wave -noupdate -expand -group {AXI Master Read} /tb_safety_island_top_full/m_axi_rvalid_flat
add wave -noupdate -expand -group {AXI Master Read} /tb_safety_island_top_full/m_axi_rready_flat
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {6596678 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 182
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {6563738 ps} {7905 ns}
