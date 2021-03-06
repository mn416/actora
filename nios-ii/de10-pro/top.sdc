#**************************************************************
# This .sdc file is created by Terasic Tool.
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
# CLOCK
create_clock -period "100.0 MHz" [get_ports CLK_100_B3I]
create_clock -period "50.0 MHz" [get_ports CLK_50_B2C]
create_clock -period "50.0 MHz" [get_ports CLK_50_B2L]
create_clock -period "50.0 MHz" [get_ports CLK_50_B3C]
create_clock -period "50.0 MHz" [get_ports CLK_50_B3I]
create_clock -period "50.0 MHz" [get_ports CLK_50_B3L]

create_clock -period "100.0 MHz" [get_ports PCIE_REFCLK_p]

create_clock -period "644.53125 MHz" [get_ports QSFP28A_REFCLK_p]
create_clock -period "644.53125 MHz" [get_ports QSFP28B_REFCLK_p]
create_clock -period "644.53125 MHz" [get_ports QSFP28C_REFCLK_p]
create_clock -period "644.53125 MHz" [get_ports QSFP28D_REFCLK_p]

create_clock -period "300.0 MHz" [get_ports DDR4A_REFCLK_p]
create_clock -period "300.0 MHz" [get_ports DDR4B_REFCLK_p]
create_clock -period "300.0 MHz" [get_ports DDR4C_REFCLK_p]
create_clock -period "300.0 MHz" [get_ports DDR4D_REFCLK_p]

#**************************************************************
# Create Generated Clock
#**************************************************************
derive_pll_clocks


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************
set_false_path -from [get_keepers {*ref_clock_*|counting_now*}] -to [get_keepers {*ref_clock_*|clk2_cnt*}]
set_false_path -from [get_keepers {*ref_clock_*|trigger_send*}] -to [get_keepers {*ref_clock_*|clk2_cnt*}]
set_false_path -from [get_keepers {*ref_clock_*|clk2_cnt*}] -to [get_keepers {*ref_clock_*|s_readdata_out*}]

#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************



