# ==========================================
# elaborate.tcl — RTL syntax check (non-project)
# ==========================================
create_project -in_memory -part xc7z020clg400-1

proc load_rtl {} {
    set pkg_files [glob -nocomplain ../rtl/*_pkg.sv]
    if {[llength $pkg_files] > 0} {
        read_verilog -sv $pkg_files
        puts "Loaded packages: $pkg_files"
    }
    set design_files {}
    foreach f [glob -nocomplain ../rtl/*.sv] {
        if {[string first "_pkg.sv" $f] == -1} { lappend design_files $f }
    }
    if {[llength $design_files] > 0} {
        read_verilog -sv $design_files
        puts "Loaded design: [llength $design_files] files"
    }
}

load_rtl

synth_design -top ring_flasher -rtl -name rtl_1
