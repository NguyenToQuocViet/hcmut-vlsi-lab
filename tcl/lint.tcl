# ==========================================
# lint.tcl — RTL lint (non-project)
# ==========================================
create_project -in_memory -part xc7z020clg400-1

proc load_rtl {} {
    set pkg_files [glob -nocomplain ../rtl/*_pkg.sv]
    if {[llength $pkg_files] > 0} { read_verilog -sv $pkg_files }
    foreach f [glob -nocomplain ../rtl/*.sv] {
        if {[string first "_pkg.sv" $f] == -1} { read_verilog -sv $f }
    }
}

load_rtl
file mkdir reports

puts "========== Running RTL Lint =========="
synth_design -top ring_flasher -rtl -name rtl_lint

# 1. Latch check
set latches [get_cells -hierarchical -filter {IS_LATCH == "TRUE"}]
if {[llength $latches] > 0} {
    puts "CRITICAL WARNING: Latches detected: $latches"
} else {
    puts "OK: No latches detected."
}

# 2. Methodology
report_methodology -file reports/lint_methodology.txt
puts "Methodology report: reports/lint_methodology.txt"

# 3. DRC
report_drc -checks {HDRC-1} -file reports/lint_drc.txt
puts "DRC report: reports/lint_drc.txt"

close_design
