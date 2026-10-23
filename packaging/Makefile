# =============================================================================
# Lint targets for the packaging bash scripts.
#
#   make lint-script-compile   bash -n syntax check on every .sh
#   make lint-script-shellcheck shellcheck on every .sh
#   make lint-script-help      run --help on every script that supports it
#   make lint-script-dryrun    run --dry-run on every script that supports it
#   make lint-script           run all of the above
# =============================================================================

SHELL := /bin/bash

# Every bash script under packaging/ that is under git control, plus the
# shared lib (lib/pause.sh) that the build/demo scripts source.
SCRIPTS := \
    ./appimage/build-appimage.sh \
    ./appimage/demo-appimage.sh \
    ./build_ocio.sh \
    ./containers/build-package.sh \
    ./containers/setup-builder.sh \
    ./deb/build-deb.sh \
    ./deb/demo-deb.sh \
    ./flatpak/build-flatpak.sh \
    ./flatpak/demo-flatpak.sh \
    ./lib/pause.sh \
    ./packator.sh \
    ./rpm/build-rpm.sh \
    ./rpm/demo-rpm.sh

# Scripts that accept --help and exit 0.
HELP_SCRIPTS := \
    ./build_ocio.sh \
    ./packator.sh \
    ./deb/build-deb.sh \
    ./deb/demo-deb.sh \
    ./appimage/build-appimage.sh \
    ./appimage/demo-appimage.sh \
    ./rpm/build-rpm.sh \
    ./rpm/demo-rpm.sh \
    ./flatpak/build-flatpak.sh

# Scripts that accept --dry-run and complete without requiring build artifacts.
DRYRUN_SCRIPTS := \
    ./rpm/demo-rpm.sh \
    ./appimage/demo-appimage.sh \
    ./deb/demo-deb.sh \
    ./flatpak/demo-flatpak.sh \
    ./flatpak/build-flatpak.sh

.PHONY: lint-script lint-script-compile lint-script-shellcheck lint-script-help lint-script-dryrun

lint-script: lint-script-compile lint-script-shellcheck lint-script-help lint-script-dryrun
	@echo "==> lint-script: all checks passed"

lint-script-compile:
	@echo "==> bash -n (syntax check)"
	@for s in $(SCRIPTS); do \
	    echo "  $$s"; \
	    bash -n "$$s" || { echo "  SYNTAX FAIL: $$s" >&2; exit 1; }; \
	done
	@echo "  OK: $(words $(SCRIPTS)) scripts"

lint-script-shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not installed; skipping" >&2; exit 0; }
	@echo "==> shellcheck"
	@shellcheck -S warning $(SCRIPTS)
	@echo "  OK"

lint-script-help:
	@echo "==> --help"
	@for s in $(HELP_SCRIPTS); do \
	    echo "  $$s"; \
	    bash "$$s" --help >/dev/null || { echo "  HELP FAIL: $$s" >&2; exit 1; }; \
	done
	@echo "  OK: $(words $(HELP_SCRIPTS)) scripts"

lint-script-dryrun:
	@echo "==> --dry-run"
	@for s in $(DRYRUN_SCRIPTS); do \
	    echo "  $$s"; \
	    bash "$$s" --dry-run >/dev/null || { echo "  DRYRUN FAIL: $$s" >&2; exit 1; }; \
	done
	@echo "  OK: $(words $(DRYRUN_SCRIPTS)) scripts"
