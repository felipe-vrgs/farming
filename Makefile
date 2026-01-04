# Farming Project Makefile

# Path to Godot executable
# - CI will override this (Linux binary under .godot-bin/)
# - On Windows you can override: `make test GODOT_BIN="C:/Program Files/Godot/Godot.exe"`
GODOT_BIN ?= "C:\Program Files\Godot\Godot.exe"
PYTHON ?= python

.PHONY: help install sanity lint format format-check test test-full godot-test all

# Default target
help:
	@echo "Farming Project Makefile"
	@echo "Usage:"
	@echo "  make install      - Install development dependencies"
	@echo "  make lint         - Run sanity checks and lints"
	@echo "  make format       - Run gdformat to apply formatting"
	@echo "  make format-check - Fail if gdformat would change files"
	@echo "  make test         - Run basic headless tests"
	@echo "  make test-full    - Run all headless tests including runtime"
	@echo "  make godot-test   - Run headless tests directly via Godot"
	@echo "  make all          - Run lint and all tests"

# Install dev tooling and pre-commit hooks
install:
	$(PYTHON) -m pip install -r requirements-dev.txt
	pre-commit install

# Run sanity check (checks project structure/uids)
sanity:
	$(PYTHON) tools/ci/sanity_check.py

# Run linter
lint: sanity
	$(PYTHON) tools/lint/lint.py

# Run formatter
format:
	$(PYTHON) tools/lint/format.py

# Check formatter (CI)
format-check:
	$(PYTHON) tools/lint/format.py --check

# Run basic headless tests via Python wrapper
test:
	$(PYTHON) tools/tests/run_headless_tests.py --godot $(GODOT_BIN)

# Run all headless tests including runtime (slower)
test-full:
	$(PYTHON) tools/tests/run_headless_tests.py --godot $(GODOT_BIN) --include-runtime

# Run headless tests directly via Godot
godot-test:
	$(GODOT_BIN) --headless --scene res://tests/headless/test_runner.tscn

# Run everything
all: lint test-full
