onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Test info:}
add wave -noupdate /rv32ui_p_tb/tb_path
add wave -noupdate /rv32ui_p_tb/hex_dump_filename
add wave -noupdate -divider Top:
add wave -noupdate /rv32ui_p_tb/clk
add wave -noupdate /rv32ui_p_tb/rst
add wave -noupdate -divider {Core #0:}
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/hartid
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/PC
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/instr
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/rs1_data
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/rs2_data
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/o_instr_mem_addr
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/i_instr_mem_data
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 218
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
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {1199113 ps}
