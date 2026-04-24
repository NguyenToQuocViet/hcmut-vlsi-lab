# Makefile for Vivado TCL workflow
# Copy into each lab subdir. Per-lab TOP/TB is set in tcl/config.tcl.
#
# Override examples:
#   make run TB=spi_master_tb        # pick a specific testbench
#   make sim TB=spi_slave_tb         # same, GUI waveform
#   make synth TOP=spi_master        # synthesize a sub-module instead of lab TOP
#   make lint TOP=spi_slave

PROJECT_NM = $(shell basename $(CURDIR))
VIVADO = vivado
MODE = -mode batch

# Optional overrides (empty -> TCL uses config.tcl defaults)
TB  ?=
TOP ?=

# Convert TB / TOP into -tclargs form used by config.tcl::resolve_top
SIM_ARGS   = $(if $(TB),-tclargs $(TB),)
BUILD_ARGS = $(if $(TOP),-tclargs $(TOP),)

.PHONY: all create build lint run sim synth impl clean distclean open help

# Default target
all: build

# Create project (project-mode, generates .xpr for GUI)
# NOTE: create_project.tcl lives at vlsi_lab root, not per-lab.
# From work/ (= <lab>/work/), root is two levels up.
create:
	@mkdir -p work
	@echo "Creating Vivado Project..."
	cd work && $(VIVADO) $(MODE) -source ../../create_project.tcl -tclargs $(PROJECT_NM)

# Elaborate design (syntax check)
build:
	@mkdir -p work
	@echo "Elaborating design (checking syntax)..."
	cd work && $(VIVADO) $(MODE) -source ../tcl/elaborate.tcl $(BUILD_ARGS)

# Linting (Check synthesizability and quality)
lint:
	@mkdir -p work
	@echo "Running RTL Linting..."
	cd work && $(VIVADO) $(MODE) -source ../tcl/lint.tcl $(BUILD_ARGS)

# Run simulation (batch mode)
run:
	@mkdir -p work
	@echo "Running simulation$(if $(TB), (TB=$(TB)),)..."
	cd work && $(VIVADO) $(MODE) -source ../tcl/sim.tcl $(SIM_ARGS)

# Simulation with waveform GUI
sim:
	@mkdir -p work
	@echo "Opening simulation waveform$(if $(TB), (TB=$(TB)),)..."
	cd work && $(VIVADO) -mode gui -source ../tcl/sim.tcl $(SIM_ARGS)

# Synthesis
synth:
	@mkdir -p work
	@echo "Running Synthesis$(if $(TOP), (TOP=$(TOP)),)..."
	cd work && $(VIVADO) $(MODE) -source ../tcl/synth.tcl $(BUILD_ARGS)

# Implementation
impl:
	@mkdir -p work
	@echo "Running Implementation..."
	cd work && $(VIVADO) $(MODE) -source ../tcl/impl.tcl

# Clean simulation files
clean:
	@echo "Cleaning simulation files..."
	@rm -rf work/.Xil work/xsim.dir work/*.wdb work/*.jou work/*.log work/xvlog.pb work/xelab.pb 2>/dev/null || true
	@echo "Project files kept intact"

# Deep clean (remove everything)
distclean:
	@echo "Deep cleaning..."
	@rm -rf work/* *.log *.jou .Xil/ 2>/dev/null || true

# Open Vivado GUI
open:
	@echo "Opening Vivado GUI..."
	cd work && $(VIVADO) $(PROJECT_NM).xpr &

# Help menu
help:
	@echo "=========================================="
	@echo "RTL Development Workflow:"
	@echo "  make create            - Create new Vivado project"
	@echo "  make build [TOP=..]    - Elaborate design (syntax check)"
	@echo "  make lint  [TOP=..]    - RTL Linting (latch + methodology + DRC)"
	@echo "  make run   [TB=..]     - Run simulation (batch mode)"
	@echo "  make sim   [TB=..]     - Open simulation waveform GUI"
	@echo ""
	@echo "Synthesis & Implementation:"
	@echo "  make synth [TOP=..]    - Synthesis + reports"
	@echo "  make impl              - Implementation + timing + power"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean             - Clean sim junk files"
	@echo "  make distclean         - Wipe work/ directory"
	@echo "  make open              - Open Vivado Project GUI"
	@echo ""
	@echo "Per-lab defaults (TOP, DEFAULT_TB, PART) live in tcl/config.tcl"
	@echo "=========================================="
