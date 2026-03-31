# ==========================================
# synth.tcl — Synthesis (non-project)
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

# Load constraints nếu có
set xdc_files [glob -nocomplain ../constrs/*.xdc]
if {[llength $xdc_files] > 0} {
    read_xdc $xdc_files
    puts "Loaded constraints: $xdc_files"
}

file mkdir reports
file mkdir checkpoints

puts "========== Running Synthesis =========="
# -mode out_of_context: bỏ I/O buffer, đo Fmax lõi thuần túy
synth_design -top ring_flasher -part xc7z020clg400-1 -mode out_of_context

write_checkpoint -force checkpoints/post_synth.dcp
puts "Checkpoint saved: checkpoints/post_synth.dcp"

report_utilization    -file reports/utilization_synth.txt
report_timing_summary -file reports/timing_synth.txt
puts "SUCCESS: Synthesis completed. Reports: reports/"
