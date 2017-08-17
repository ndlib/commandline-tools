
INSTALL_PATH=/usr/local/bin
COMMANDS:=$(wildcard ./bin/*)

install:
	mkdir -p $(INSTALL_PATH)
	install $(COMMANDS) $(INSTALL_PATH)


.PHONY: install
