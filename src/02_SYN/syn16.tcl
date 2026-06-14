set company {NTUGIEE}
set designer {student}

# set hdlin_translate_off_ship_text "TRUE"
# set edifout_netlist_only "TRUE"
set verilogout_no_tri TRUE

# set hdlin_enable_presto_for_vhdl "TRUE"
set sh_enable_line_editing true
set sh_line_editing_mode emacs
history keep 100
alias h history

############################################
# set libraries
############################################
set search_path    "/usr/cad/ADFP/Executable_Package/Collaterals/IP/stdcell/N16ADFP_StdCell/CCS/ \
                    /usr/cad/ADFP/Executable_Package/Collaterals/IP/stdio/N16ADFP_StdIO/NLDM/ \
                    /usr/cad/ADFP/Executable_Package/Collaterals/IP/sram/N16ADFP_SRAM/NLDM/ \
                    $search_path .\
                    "

set target_library "N16ADFP_StdCellff0p88v125c_ccs.db \
                    N16ADFP_StdCellff0p88vm40c_ccs.db \
                    N16ADFP_StdCellss0p72v125c_ccs.db \
                    N16ADFP_StdCellss0p72vm40c_ccs.db \
                    N16ADFP_StdCelltt0p8v25c_ccs.db \
                    N16ADFP_StdIOff0p88v1p98v125c.db \
                    N16ADFP_StdIOff0p88v1p98vm40c.db \
                    N16ADFP_StdIOss0p72v1p62v125c.db \
                    N16ADFP_StdIOss0p72v1p62vm40c.db \
                    N16ADFP_StdIOtt0p8v1p8v25c.db \
                    N16ADFP_SRAM_ff0p88v0p88v125c_100a.db \
                    N16ADFP_SRAM_ff0p88v0p88vm40c_100a.db \
                    N16ADFP_SRAM_ss0p72v0p72v125c_100a.db \
                    N16ADFP_SRAM_ss0p72v0p72vm40c_100a.db \
                    N16ADFP_SRAM_tt0p8v0p8v25c_100a.db \
                    "

set link_library "* $target_library dw_foundation.sldb"
set symbol_library "generic.sdb"
set synthetic_library "dw_foundation.sldb"

############################################
# create path
############################################
sh mkdir -p Netlist
sh mkdir -p Report

############################################
# import design
############################################
set DESIGN "EVD"

analyze -f sverilog -vcs "-f file.f"
elaborate $DESIGN
link
current_design $DESIGN

############################################
# set Clock
############################################
set cycle 1.0

create_clock -period $cycle -name clk   [get_ports clk]
set_dont_touch_network                  [get_clocks clk]
set_fix_hold                            [get_clocks clk]
set_ideal_network                       [get_ports clk]
set_clock_uncertainty -hold 0.005       [get_clocks clk]
set_clock_uncertainty -setup 0.1        [get_clocks clk]
set_clock_latency 0.5                   [get_clocks clk]

############################################
# set max delay from input to output
############################################
set MAX_Delay 0
set_max_delay $MAX_Delay -from [all_inputs] -to [all_outputs]

############################################
# input drive and output load
############################################
set_drive 1 [all_inputs]
set_load 0.05 [all_outputs]

############################################
# set i/o delay
############################################
set_input_delay  [expr $cycle * 0.5] -clock clk [remove_from_collection [all_inputs] {clk}]
set_output_delay [expr $cycle * 0.5] -clock clk [all_outputs]

check_design > Report/check_design.txt
check_timing > Report/check_timing.txt

############################################
# compile
############################################
uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
compile_ultra
compile -inc

############################################
# report output
############################################
current_design $DESIGN
report_timing > Report/${DESIGN}_syn.timing
report_area   > Report/${DESIGN}_syn.area

############################################
# output design
############################################
current_design $DESIGN

set bus_inference_style {%s[%d]}
set bus_naming_style {%s[%d]}
set hdlout_internal_busses true

change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _} -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]} -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive
change_names -hierarchy -rules name_rule

remove_unconnected_ports -blast buses [get_cells -hierarchical *]
set verilogout_higher_designs_first true
write -format ddc      -hierarchy -output "./Netlist/${DESIGN}.ddc"
write -format verilog  -hierarchy -output "./Netlist/${DESIGN}_syn.v"
write_sdf -version 3.0 -context verilog ./Netlist/${DESIGN}.sdf
write_sdc ./Netlist/${DESIGN}_syn.sdc -version 1.8
sh sed -i {6i \`timescale 1ns/1ps} ./Netlist/${DESIGN}_syn.v

report_timing
report_area
