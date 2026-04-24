# ==========================================
# lint.tcl — RTL lint (non-project)
# Recursive traversal of ../rtl/. Override TOP via -tclargs.
# ==========================================
source ../tcl/config.tcl

set TOP [resolve_top $TOP]

create_project -in_memory -part $PART

load_rtl_sources ../rtl
file mkdir reports

puts "========== Running RTL Lint (top=$TOP) =========="
synth_design -top $TOP -rtl -name rtl_lint

# 1. Latch check
set latches [get_cells -hierarchical -filter {IS_LATCH == "TRUE"}]
if {[llength $latches] > 0} {
    puts "CRITICAL WARNING: [llength $latches] latch(es) detected:"
    foreach l $latches { puts "  - $l" }
} else {
    puts "OK: No latches detected."
}

# 2. Methodology (full ruleset)
report_methodology -file reports/lint_methodology.txt
puts "Methodology report: reports/lint_methodology.txt"

# 3. DRC (all default checks, not just HDRC-1)
report_drc -file reports/lint_drc.txt
puts "DRC report: reports/lint_drc.txt"

close_design
puts "SUCCESS: Lint completed."
