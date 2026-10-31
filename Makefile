.PHONY: build lint test check settings install uninstall clean

SHELL_FILES := src/dev-servers.sh scripts/build.sh scripts/cask.sh scripts/settings-dev.sh install.sh tests/smoke.sh

build:
	./scripts/build.sh

lint:
	shellcheck --severity=warning $(SHELL_FILES)
	ruff check src/settings
	ruff format --check src/settings

test:
	./tests/smoke.sh

check: lint test

settings:
	./scripts/settings-dev.sh

install:
	./install.sh

uninstall:
	./install.sh --uninstall

clean:
	rm -rf dist
