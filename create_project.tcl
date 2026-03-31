# ==========================================
# create_project.tcl
# ==========================================
set project_name [file tail [file dirname [pwd]]]

# Tạo project (Ghi đè nếu đã tồn tại)
create_project ${project_name} . -force -part xc7z020clg400-1

# 1. Nạp toàn bộ cây thư mục RTL và ép kiểu SystemVerilog
add_files ../rtl
add_files -fileset constrs_1 -norecurse ../constrs/timing.xdc
set_property file_type SystemVerilog [get_files -filter {NAME =~ *.sv}]

# 2. Nạp toàn bộ cây thư mục Testbench
if {[file exists ../tb]} {
    add_files -fileset sim_1 ../tb
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] -filter {NAME =~ *.sv}]
}

# 3. Yêu cầu Vivado tự động tính toán thứ tự biên dịch (Tự nhận diện _pkg.sv)
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "SUCCESS: Project created and source files added recursively."
close_project
