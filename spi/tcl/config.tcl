# ==========================================
# config.tcl — Per-lab configuration + shared helpers
# Sourced by all other TCL scripts. Edit the "LAB CONFIG" section
# when moving this tcl/ folder into a new lab.
# ==========================================

# ------------------------------------------
# LAB CONFIG (change when copying to a new lab)
# ------------------------------------------
set TOP        "spi_top"
set DEFAULT_TB "spi_top_tb"
set PART       "xc7z020clg400-1"

# ------------------------------------------
# Shared helpers (do not edit per-lab)
# ------------------------------------------

# Recursively find files by extension under a directory.
# - Skips hidden dirs (leading ".") and the build output dir "work/".
# - Returns absolute-normalized, lexicographically sorted list.
proc find_files {dir ext} {
    set result {}
    if {![file isdirectory $dir]} { return $result }
    foreach item [glob -nocomplain -directory $dir *] {
        set base [file tail $item]
        if {[string index $base 0] eq "."} { continue }
        if {[file isdirectory $item]} {
            if {$base eq "work"} { continue }
            lappend result {*}[find_files $item $ext]
        } elseif {[file extension $item] eq ".$ext"} {
            lappend result $item
        }
    }
    return [lsort $result]
}

# Gather SystemVerilog files from a directory tree.
# Returns {pkg_list mod_list}: packages (*_pkg.sv) come first in compile order.
# NOTE: if packages have inter-dependency, rename them so alphabetical order
# matches dependency order (e.g. 0_base_pkg.sv before 1_derived_pkg.sv).
proc gather_sv {dir} {
    set all_sv [find_files $dir sv]
    set pkgs {}
    set mods {}
    foreach f $all_sv {
        if {[string match "*_pkg.sv" [file tail $f]]} {
            lappend pkgs $f
        } else {
            lappend mods $f
        }
    }
    return [list $pkgs $mods]
}

# Load RTL sources into the current in-memory Vivado project.
# Aborts (exit 1) if no .sv found.
proc load_rtl_sources {rtl_dir} {
    lassign [gather_sv $rtl_dir] pkgs mods
    if {[llength $pkgs] == 0 && [llength $mods] == 0} {
        puts "ERROR: No .sv files found under $rtl_dir"
        exit 1
    }
    if {[llength $pkgs] > 0} {
        read_verilog -sv $pkgs
        puts "Loaded [llength $pkgs] package file(s):"
        foreach p $pkgs { puts "  - $p" }
    }
    if {[llength $mods] > 0} {
        read_verilog -sv $mods
        puts "Loaded [llength $mods] RTL module file(s):"
        foreach m $mods { puts "  - $m" }
    }
}

# Resolve TOP override from -tclargs (Makefile can pass "TOP=spi_master", etc.)
# Call pattern:
#   vivado -source ... -tclargs spi_master
# Returns the first argv entry if present, else the given default.
proc resolve_top {default_top} {
    if {[info exists ::argv] && [llength $::argv] > 0} {
        set override [lindex $::argv 0]
        if {[string length $override] > 0} {
            puts "NOTE: TOP overridden via -tclargs: $override (default was $default_top)"
            return $override
        }
    }
    return $default_top
}
