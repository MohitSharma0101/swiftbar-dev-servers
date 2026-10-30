.PHONY: build lint test check install uninstall clean

SHELL_FILES := src/dev-servers.sh scripts/build.sh scripts/cask.sh install.sh tests/smoke.sh

build:
	./scripts/build.sh

lint:
	shellcheck --severity=warning $(SHELL_FILES)
	ruff check src/settings
	ruff format --check src/settings

test:
	./tests/smoke.sh

check: lint test

install:
	./install.sh

uninstall:
	./install.sh --uninstall

clean:
	rm -rf dist
