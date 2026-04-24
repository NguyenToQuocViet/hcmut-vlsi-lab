# ==========================================
# synth.tcl — Synthesis (non-project)
# Recursive traversal of ../rtl/ and ../constrs/. Override TOP via -tclargs.
# -mode out_of_context: skip I/O buffers → measures pure core Fmax.
# ==========================================
source ../tcl/config.tcl

set TOP [resolve_top $TOP]

create_project -in_memory -part $PART

load_rtl_sources ../rtl

# Load XDC constraints (recursive)
set xdc_files [find_files ../constrs xdc]
if {[llength $xdc_files] > 0} {
    read_xdc $xdc_files
    puts "Loaded [llength $xdc_files] XDC file(s):"
    foreach x $xdc_files { puts "  - $x" }
} else {
    puts "NOTE: No XDC constraints found under ../constrs/ (timing will be unconstrained)"
}

file mkdir reports
file mkdir checkpoints

puts "========== Running Synthesis (top=$TOP) =========="
synth_design -top $TOP -part $PART -mode out_of_context

write_checkpoint -force checkpoints/post_synth.dcp
puts "Checkpoint saved: checkpoints/post_synth.dcp"

report_utilization    -file reports/utilization_synth.txt
report_timing_summary -file reports/timing_synth.txt
puts "SUCCESS: Synthesis completed (top=$TOP). Reports: reports/"
