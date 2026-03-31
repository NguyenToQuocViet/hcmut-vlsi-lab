# Makefile for Vivado TCL workflow
PROJECT_NM = $(shell basename $(CURDIR))
VIVADO = vivado
MODE = -mode batch

.PHONY: all create build lint run sim synth impl clean distclean open help

# Default target
all: build

# Create project
create:
	@echo "Creating Vivado Project..."
	cd work && $(VIVADO) $(MODE) -source ../create_project.tcl -tclargs $(PROJECT_NM)

# Elaborate design (syntax check)
build:
	@echo "Elaborating design (checking syntax)..."
	cd work && $(VIVADO) $(MODE) -source ../tcl/elaborate.tcl

# Linting (Check synthesizability and quality)
lint:
	@echo "Running RTL Linting..."
	cd work && $(VIVADO) $(MODE) -source ../tcl/lint.tcl

# Run simulation (batch mode)
run:
	@echo "Running simulation..."
	cd work && $(VIVADO) $(MODE) -source ../tcl/sim.tcl

# Simulation with waveform GUI
sim:
	@echo "Opening simulation waveform..."
	cd work && $(VIVADO) -mode gui -source ../tcl/sim.tcl

# Synthesis
synth:
	@echo "Running Synthesis..."
	cd work && $(VIVADO) $(MODE) -source ../tcl/synth.tcl

# Implementation
impl:
	@echo "Running Implementation..."
	cd work && $(VIVADO) $(MODE) -source ../tcl/impl.tcl

# Clean simulation files
clean:
	@echo "Cleaning simulation files..."
	@rm -rf work/.Xil work/xsim.dir work/*.wdb work/*.jou work/*.log 2>/dev/null || true
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
	@echo "  make create    - Create new Vivado project"
	@echo "  make build     - Elaborate design (check syntax)"
	@echo "  make lint      - RTL Linting (check latches & quality)"
	@echo "  make run       - Run simulation (batch mode)"
	@echo "  make sim       - Open simulation waveform GUI"
	@echo ""
	@echo "Synthesis & Implementation:"
	@echo "  make synth     - Run synthesis & generate reports"
	@echo "  make impl      - Run implementation & timing analysis"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean     - Clean simulation junk files"
	@echo "  make distclean - Deep clean (remove work directory)"
	@echo "  make open      - Open Vivado Project GUI"
	@echo "=========================================="
