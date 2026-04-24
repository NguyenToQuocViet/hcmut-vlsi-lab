# ==========================================
# sim.tcl — Simulation (non-project, xsim flow)
# Recursive traversal of ../rtl/ and ../tb/.
# TB selection: -tclargs <tb_name> overrides DEFAULT_TB from config.tcl.
#   make run                 -> uses DEFAULT_TB
#   make run TB=spi_master_tb -> Makefile passes "-tclargs spi_master_tb"
# ==========================================
source ../tcl/config.tcl

set tb_top [resolve_top $DEFAULT_TB]

puts "========== Gathering sources =========="
# RTL: packages -> modules (recursive)
lassign [gather_sv ../rtl] rtl_pkgs rtl_mods
# TB: packages -> modules (recursive) — TB may declare its own helper packages
lassign [gather_sv ../tb]  tb_pkgs  tb_mods

if {[llength $rtl_pkgs] == 0 && [llength $rtl_mods] == 0} {
    puts "ERROR: No RTL .sv found under ../rtl/"
    exit 1
}
if {[llength $tb_mods] == 0} {
    puts "ERROR: No testbench .sv found under ../tb/. Create ../tb/${tb_top}.sv first."
    exit 1
}

# Sanity check: warn if requested TB is not present as a file
set tb_found 0
foreach f $tb_mods {
    if {[file rootname [file tail $f]] eq $tb_top} { set tb_found 1; break }
}
if {!$tb_found} {
    puts "WARNING: No file ${tb_top}.sv found explicitly under ../tb/."
    puts "         xelab will fail unless module '$tb_top' is declared in another file."
}

# Compile order: RTL pkgs -> RTL mods -> TB pkgs -> TB mods
set all_files [concat $rtl_pkgs $rtl_mods $tb_pkgs $tb_mods]
puts "Compile order ([llength $all_files] files):"
foreach f $all_files { puts "  - $f" }

puts "========== Compiling (xvlog) =========="
exec xvlog -sv -d SIMULATION {*}$all_files >@stdout 2>@stderr

puts "========== Elaborating (xelab top=$tb_top) =========="
exec xelab -debug typical $tb_top -s ${tb_top}_snap >@stdout 2>@stderr

puts "========== Simulating =========="
if {[string match -nocase "*gui*" $rdi::mode]} {
    exec xsim ${tb_top}_snap -gui >@stdout 2>@stderr
    puts "Waveform closed. Exit."
} else {
    exec xsim ${tb_top}_snap -R >@stdout 2>@stderr
    puts "SUCCESS: Simulation completed (tb=$tb_top)."
}
