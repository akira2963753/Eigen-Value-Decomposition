set toplevel EVD 
# set filelist {../RTL/}
set sh_continue_on_error false
set compile_preserve_subdesign_interfaces true
define_design_lib work -path work

analyze -f sverilog -vcs "-f file.f"
# analyze -f verilog $filelist
elaborate $toplevel

set filename [format "%s%s" $toplevel "_raw.ddc"]
write -format ddc -hierarchy -output $filename

link
check_design

# Set the clock period
set period 10
set io_delay [expr {$period * 0.5}]
# set io_delay 

set_operating_conditions -min fast  -max slow
set_wire_load_model -name tsmc090_wl10 -library slow

create_clock -name clk -period $period  [get_ports clk] 
set_ideal_network         [get_ports clk]
# set_ideal_network         [get_ports rst_n]
set_dont_touch_network                  [get_clocks clk]
# set_fix_hold                            [get_clocks clk]

set_clock_uncertainty       0.5    [get_clocks clk]
set_clock_latency -source   0      [get_clocks clk]
set_clock_latency           0.1    [get_clocks clk] 
set_clock_transition        0.1    [all_clocks]

set_input_transition    0.2 [all_inputs]

set_input_delay -clock clk -max ${io_delay} [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -clock clk -min 0 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk -max ${io_delay} [all_outputs]
set_output_delay -clock clk -min 0 [all_outputs]

set_driving_cell -library tpzn90gv3wc -lib_cell PDIDGZ_33 -pin {C} [all_inputs]
set_load [load_of "tpzn90gv3wc/PDO16CDG_33/I"] [all_outputs]

set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
set_max_area        0
set_max_capacitance 0.1 [remove_from_collection [all_inputs] [get_ports clk]]
set_max_fanout      10    [remove_from_collection [all_inputs] [get_ports clk]]
set_max_transition  0.2  [all_inputs]

#set effort high
#compile -exact_map -boundary_optimization -map_effort $effort -area_effort $effort -power_effort $effort

compile_ultra -no_autoungroup 

set bus_inference_style {%s[%d]}
set bus_naming_style    {%s[%d]}
set hdlout_internal_busses true

change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed "A-Za-z0-9_" -max_length 255 -type cell
define_name_rules name_rule -allowed "A-Za-z0-9_[]" -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive
change_names -hierarchy -rules name_rule

sh mkdir -p Netlist
sh mkdir -p Report

set filename [format "%s%s" $toplevel "_opt.ddc"]
write -format ddc -hierarchy -output ./Netlist/$filename

set filename [format "%s%s" $toplevel ".sdf"]
write_sdf -version 2.1 -load_delay net ./Netlist/$filename

set filename [format "%s%s" $toplevel "_syn.v"]
write -format verilog -hierarchy -output ./Netlist/$filename
sh sed -i {6i \`timescale 1ns/1ps} ./Netlist/${toplevel}_syn.v

set filename [format "%s%s" $toplevel ".sdc"]
write_sdc ./Netlist/$filename

redirect ./Report/power.txt      { report_power }
redirect ./Report/area.txt       { report_area }
redirect ./Report/area_hier.txt  { report_area -hierarchy }
redirect ./Report/timing.txt     { report_timing }

remove_design -all

file delete -force default.svf
file delete -force filenames.log
file delete -force command.log

