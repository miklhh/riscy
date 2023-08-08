#!/usr/bin/env python3

from vunit import VUnit
from os import listdir, path
from sys import argv

# Absolute path of the testbench directory
tb_path = path.dirname(path.abspath(__file__))

# VUnit test object
vu = VUnit.from_argv(argv=['--output-path', f'{tb_path}/vunit_out'] + argv[1:])


lib = vu.add_library("lib")
lib.add_source_files([

    # CPU RTL files
    f"{tb_path}/../rtl/*.vhdl",

    # Testbench files
    f"{tb_path}/../tb/rv32ui_p_tb.vhdl",
    f"{tb_path}/../tb/ram_generic.vhdl",
])
lib.set_compile_option("modelsim.vcom_flags", ["-2008", "-check_synthesis", "+acc=rnb"])
#lib.set_sim_option("modelsim.vsim_flags", ["-novopt"])


rv32ui_p_tb = lib.test_bench("rv32ui_p_tb")
for filename in sorted(listdir(f"{tb_path}/hex/rv32ui-p-simple")):
    if filename.endswith(".hex"):
        rv32ui_p_tb.add_config(
            name=filename.replace('.hex', '').replace('rv32ui-p-', ''),
            generics={ "hex_dump_filename": filename }
        )


vu.main()
