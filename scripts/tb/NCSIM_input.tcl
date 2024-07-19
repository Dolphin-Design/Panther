# Disable asserts from std_logic_arith and numeric_std packages 
# (suppress unrelevant warnings at simulation start) 
set severity_pack_assert_off { warning }
set pack_assert_off { std_logic_arith numeric_std }

#run the simulation
run
exit
