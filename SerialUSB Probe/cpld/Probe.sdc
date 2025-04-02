#************************************************************
# THIS IS A WIZARD-GENERATED FILE.                           
#
# Version 13.0.1 Build 232 06/12/2013 Service Pack 1 SJ Web Edition
#
#************************************************************

# Copyright (C) 1991-2013 Altera Corporation
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, Altera MegaCore Function License 
# Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the 
# applicable agreement for further details.

set_time_format -unit ns -decimal_places 3

# Clock constraints

#create_clock -name {CLK12M} -period 80.000 -waveform { 0.000 40.000 } [get_ports {CLK12M}]
create_clock -name {PHI_0} -period 975.000 -waveform { 0.000 487.500 } [get_ports {PHI_0}]

# Automatically constrain PLL and other generated clocks
#derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
#derive_clock_uncertainty
# Not supported for family MAX7000S

# tsu/th constraints

# tco constraints

# tpd constraints

