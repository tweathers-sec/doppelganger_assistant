PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin

install:
	@echo "Installing doppelganger_assistant to $(BINDIR)"
	@mkdir -p $(BINDIR)
	@cp doppelganger_assistant $(BINDIR)/
	@chmod +x $(BINDIR)/doppelganger_assistant
	@echo "Installation complete"

uninstall:
	@echo "Removing doppelganger_assistant from $(BINDIR)"
	@rm -f $(BINDIR)/doppelganger_assistant
	@echo "Uninstallation complete"
