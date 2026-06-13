set source_filelist "file.f"
set top_designs [list csd_scale direct_mult_scale]

set max_path_delay 8.0
set input_transition 0.2
set max_capacitance 0.1
set max_fanout 10
set max_transition 0.2

set sh_continue_on_error false
set compile_preserve_subdesign_interfaces true

file mkdir work
file mkdir Netlist
file mkdir Report

define_design_lib work -path work

analyze -format verilog -vcs "-f ${source_filelist}"

define_name_rules name_rule \
	-allowed "A-Za-z0-9_" \
	-max_length 255 \
	-type cell
define_name_rules name_rule \
	-allowed "A-Za-z0-9_[]" \
	-max_length 255 \
	-type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive

set area_compare_file "./Report/area_compare.txt"
file delete -force ${area_compare_file}

foreach toplevel ${top_designs} {
	elaborate ${toplevel}
	current_design ${toplevel}

	link
	check_design

	set_operating_conditions -min fast -max slow
	set_wire_load_model -name tsmc090_wl10 -library slow

	set_input_transition ${input_transition} [all_inputs]
	set_driving_cell \
		-library tpzn90gv3wc \
		-lib_cell PDIDGZ_33 \
		-pin C \
		[all_inputs]
	set_load [load_of "tpzn90gv3wc/PDO16CDG_33/I"] [all_outputs]

	set_max_delay ${max_path_delay} \
		-from [all_inputs] \
		-to [all_outputs]
	set_max_area 0
	set_max_capacitance ${max_capacitance} [current_design]
	set_max_fanout ${max_fanout} [current_design]
	set_max_transition ${max_transition} [current_design]

	set_fix_multiple_port_nets -all -buffer_constants [get_designs *]

	compile_ultra -no_autoungroup
	compile_ultra -incremental

	set bus_inference_style {%s[%d]}
	set bus_naming_style {%s[%d]}
	set hdlout_internal_busses true

	change_names -hierarchy -rule verilog
	change_names -hierarchy -rules name_rule

	set netlist_dir "./Netlist/${toplevel}"
	set report_dir "./Report/${toplevel}"
	file mkdir ${netlist_dir}
	file mkdir ${report_dir}

	write \
		-format ddc \
		-hierarchy \
		-output "${netlist_dir}/${toplevel}_opt.ddc"
	write_sdf \
		-version 2.1 \
		-load_delay net \
		"${netlist_dir}/${toplevel}.sdf"
	write \
		-format verilog \
		-hierarchy \
		-output "${netlist_dir}/${toplevel}_syn.v"
	write_sdc "${netlist_dir}/${toplevel}.sdc"

	redirect "${report_dir}/area.txt" {
		report_area
	}
	redirect "${report_dir}/timing.txt" {
		report_timing
	}
	redirect "${report_dir}/power.txt" {
		report_power
	}
	redirect "${report_dir}/resources.txt" {
		report_resources
	}
	redirect "${report_dir}/references.txt" {
		report_reference
	}

	set compare_handle [open ${area_compare_file} a]
	puts ${compare_handle} \
		"================================================================"
	puts ${compare_handle} "Design: ${toplevel}"
	puts ${compare_handle} \
		"================================================================"
	close ${compare_handle}

	redirect -append ${area_compare_file} {
		report_area
	}

	remove_design -all
}

exit
