# ==========================================
# create_project.tcl — project-mode scaffold (.xpr for GUI)
# Invoked by `make create` from <lab>/work/.
# Expected cwd: <lab>/work/   →   RTL at ../rtl, TB at ../tb, XDC at ../constrs
# ==========================================
set project_name [file tail [file dirname [pwd]]]

# Create project (overwrite if exists)
create_project ${project_name} . -force -part xc7z020clg400-1

# 1. Load RTL tree (recursive) and force SystemVerilog file type
if {[file isdirectory ../rtl]} {
    add_files ../rtl
} else {
    puts "WARNING: ../rtl not found — skipping RTL add_files"
}

# 2. Load constraints (entire directory, any *.xdc) — conditional
if {[file isdirectory ../constrs]} {
    set xdc_files [glob -nocomplain ../constrs/*.xdc]
    if {[llength $xdc_files] > 0} {
        add_files -fileset constrs_1 -norecurse $xdc_files
        puts "Loaded [llength $xdc_files] XDC file(s)"
    } else {
        puts "NOTE: ../constrs exists but contains no *.xdc — skipping"
    }
} else {
    puts "NOTE: ../constrs not found — timing will be unconstrained"
}

# 3. Load testbench tree (recursive)
if {[file isdirectory ../tb]} {
    add_files -fileset sim_1 ../tb
}

# Force SystemVerilog on all .sv files across all filesets
set all_sv [get_files -filter {NAME =~ *.sv}]
if {[llength $all_sv] > 0} {
    set_property file_type SystemVerilog $all_sv
}

# 4. Auto-compute compile order (Vivado detects *_pkg.sv dependencies)
update_compile_order -fileset sources_1
if {[llength [get_filesets -quiet sim_1]] > 0} {
    update_compile_order -fileset sim_1
}

puts "SUCCESS: Project '$project_name' created. Open via: make open"
close_project
