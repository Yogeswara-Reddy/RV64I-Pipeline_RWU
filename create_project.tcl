create_project RV_Pipeline ./RWU_RV/RV_Pipeline/vivado -part xc7z010clg400-1
set_property target_language Verilog [current_project]
add_files [glob ./RWU_RV/RV_Pipeline/src/*.sv]
add_files -fileset constrs_1 ./RWU_RV/RV_Pipeline/syn/Zybo-Master.xdc
add_files ./ip_cgu/src ./ip_dmem/src ./ip_gpio/src ./ip_jtag/src
remove_files [get_files as_pack.sv -filter {USED_IN_SIMULATION == 0 && NAME =~ *ip_jtag*}]
add_files -fileset sim_1 [glob ./RWU_RV/RV_Pipeline/tb/*.sv]
set_property top as_top_mem [current_fileset]
set_property top tb_pipeline [get_filesets sim_1]
update_compile_order -fileset sources_1
