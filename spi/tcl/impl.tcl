# ==========================================
# impl.tcl — Implementation (non-project)
# Requires: make synth first (reads checkpoints/post_synth.dcp)
# ==========================================
source ../tcl/config.tcl

if {![file exists checkpoints/post_synth.dcp]} {
    puts "ERROR: checkpoints/post_synth.dcp not found. Run 'make synth' first."
    exit 1
}

open_checkpoint checkpoints/post_synth.dcp
file mkdir reports
file mkdir checkpoints

puts "========== Running Implementation (top=$TOP) =========="

opt_design          -directive Explore
place_design        -directive Explore
phys_opt_design     -directive AggressiveExplore
route_design        -directive Explore
phys_opt_design     -directive Explore

write_checkpoint -force checkpoints/post_impl.dcp
puts "Checkpoint saved: checkpoints/post_impl.dcp"

report_utilization    -file reports/utilization_impl.txt
report_timing_summary -file reports/timing_impl.txt
report_power          -file reports/power.txt
puts "SUCCESS: Implementation completed. Reports: reports/"
