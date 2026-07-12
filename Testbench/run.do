vsim +access+r -sv_seed random +UVM_MAX_QUIT_COUNT=1 +CLK_FREQ_MHZ=50 +UVM_TESTNAME=riscv_mixed_test; 
run -all;
acdb save;
acdb report -db fcover.acdb -txt -o cov.txt -verbose
exec cat cov.txt
exit