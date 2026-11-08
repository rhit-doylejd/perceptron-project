# ####################################################################

#  Created by RTL Compiler (RC) 05.20-p002 on Wed Feb 22 10:43:54 AM CST 2006

# ####################################################################

set sdc_version 1.4
#Set Parameters
set CIN_INV_PF		0.05
set MAX_TRAN_NS		0.03
set MAX_CAP_PF		0.02
set MAX_FANOUT		10
set SIG_INPUTS 		[remove_from_collection [all_inputs] [get_ports globalClk]]	
set MY_LIB 		slow_vdd1v0_basicCells.lib
# Set the current design
current_design perceptron

create_clock -name "clk" -add -period 4.0 -waveform {0.0 2.0} [get_ports globalClk]
set_clock_transition 0.01 [get_clocks clk]
set_clock_uncertainty -setup 0.15 [get_clocks clk]
set_clock_uncertainty -hold  0.15 [get_clocks clk]

# If we also had a combinational through path that bypassed the registers, these would be useful.
# Since all signals are going through registers, we won't use these.
#set_max_delay 3.5 -from [remove_from_collection [all_inputs] [get_ports globalClk]]
#set_max_delay 3.5 -to [all_outputs]

# External launching circuitry: earliest/latest arrival at this block.
set_input_delay -clock [get_clocks clk] -rise -max 0.2 $SIG_INPUTS
set_input_delay -clock [get_clocks clk] -rise -min 0.1 $SIG_INPUTS

# External receiving circuitry: setup/hold timing budget.
set_output_delay -clock [get_clocks clk] -rise -max 1 [all_outputs]
set_output_delay -clock [get_clocks clk] -rise -min 0.0 [all_outputs]

set_driving_cell -lib_cell INVX4 [remove_from_collection [all_inputs] [get_ports globalClk]]

set_load $CIN_INV_PF [all_outputs]
set_max_transition $MAX_TRAN_NS [current_design]
set_max_capacitance $MAX_CAP_PF [current_design]
set_max_fanout $MAX_FANOUT [current_design]

#set_max_leakage_power 150.0 nW [current_design]
#set_max_dynamic_power 150.0 uW [current_design]
#set_db lp_power_optimization_weight 0.2 [current_design]
#set_db leakage_power_effort low
#set_db dynamic_power_effort low
#set_db lp_insert_clock_gating true
