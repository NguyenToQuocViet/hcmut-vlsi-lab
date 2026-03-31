# ==========================================
# sim.tcl — Simulation (non-project, xsim flow)
# ==========================================
set top "ring_flasher_tb"

# Thu thập file RTL (pkg trước)
set src_files [glob -nocomplain ../rtl/*_pkg.sv]
foreach f [glob -nocomplain ../rtl/*.sv] {
    if {[string first "_pkg.sv" $f] == -1} { lappend src_files $f }
}

# Thu thập testbench
set tb_files [glob -nocomplain ../tb/*.sv]
if {[llength $tb_files] == 0} {
    puts "ERROR: No testbench found in ../tb/. Create ../tb/${top}.sv first."
    exit 1
}

set all_files [concat $src_files $tb_files]
puts "Files: $all_files"

puts "========== Compiling =========="
exec xvlog -sv -d SIMULATION {*}$all_files >@stdout 2>@stderr

puts "========== Elaborating =========="
exec xelab -debug typical $top -s ${top}_snap >@stdout 2>@stderr

puts "========== Simulating =========="
if {[string match "*gui*" $rdi::mode]} {
    exec xsim ${top}_snap -gui >@stdout 2>@stderr
    puts "Waveform opened. Close manually when done."
} else {
    exec xsim ${top}_snap -R >@stdout 2>@stderr
    puts "SUCCESS: Simulation completed."
}
