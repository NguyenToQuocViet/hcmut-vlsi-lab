# ==========================================
# elaborate.tcl — RTL syntax check (non-project)
# Recursive traversal: loads ALL ../rtl/**/*.sv with packages first.
# Override TOP: vivado -source ../tcl/elaborate.tcl -tclargs <top_name>
# ==========================================
source ../tcl/config.tcl

set TOP [resolve_top $TOP]

create_project -in_memory -part $PART

load_rtl_sources ../rtl

puts "========== Elaborating (top=$TOP) =========="
synth_design -top $TOP -rtl -name rtl_1

puts "SUCCESS: Elaboration completed (top=$TOP)."
