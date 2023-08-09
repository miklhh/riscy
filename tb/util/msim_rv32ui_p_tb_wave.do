onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Test info:}
add wave -noupdate /rv32ui_p_tb/hex_dump_file
add wave -noupdate /rv32ui_p_tb/test_name
add wave -noupdate -divider Top:
add wave -noupdate /rv32ui_p_tb/clk
add wave -noupdate /rv32ui_p_tb/rst
add wave -noupdate -divider {Core #0:}
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/hartid
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/PC(0)
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/skip_PC
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/IR
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/rs1_data
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/rs2_data
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/o_instr_mem_addr
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/i_instr_mem_data
add wave -noupdate -divider {Core #0 (debug):}
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/PC(0)
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/skip_PC
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/inst
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_regfile/regs
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/rs1_data
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/rs2_data
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/alu_o
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/branch_take
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/branch_adr
add wave -noupdate -divider {Core #0 (ALU)}
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/skip
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/alu_fwd_a_p1
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/alu_fwd_a_p2
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/i_data1
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/i_data2
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/i_opcode
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/i_funct3
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/i_funct7
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/o_data
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/result
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/add_opa
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/add_opb
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/add_res
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/sub
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/add_signed
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/slt
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/lshift_in
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/lshift_amnt
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/lshift_out
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/rshift_in
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/rshift_amnt
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/rshift_out
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/rshift_arith
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/and_out
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/or_out
add wave -noupdate /rv32ui_p_tb/DUT/riscy_core/riscy_alu/xor_out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 169
configure wave -valuecolwidth 148
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
WaveRestoreZoom {0 ps} {81777778 ps}
