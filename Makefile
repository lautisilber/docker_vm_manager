SCRIPT      := vm
MARKER      := vmm.managed=true
PREFIX      ?= $(HOME)/.local
BINDIR      ?= $(PREFIX)/bin
INSTALL_PATH := $(BINDIR)/$(SCRIPT)

.PHONY: install uninstall

install:
	@mkdir -p "$(BINDIR)"
	install -m 755 $(SCRIPT) "$(INSTALL_PATH)"
	@echo "Installed to $(INSTALL_PATH)"
	@case ":$$PATH:" in \
		*":$(BINDIR):"*) ;; \
		*) echo "Warning: $(BINDIR) is not on your PATH."; \
		   echo "  Add this to your shell profile (e.g. ~/.zshrc):"; \
		   echo "    export PATH=\"$(BINDIR):\$$PATH\""; ;; \
	esac

uninstall:
	@removed=0; \
	candidates="$(BINDIR) $$(echo "$$PATH" | tr ':' ' ')"; \
	seen=""; \
	for dir in $$candidates; do \
		case " $$seen " in *" $$dir "*) continue ;; esac; \
		seen="$$seen $$dir"; \
		f="$$dir/$(SCRIPT)"; \
		if [ -f "$$f" ] && grep -q '$(MARKER)' "$$f" 2>/dev/null; then \
			echo "Removing $$f"; \
			rm -f "$$f"; \
			removed=1; \
		fi; \
	done; \
	if [ "$$removed" -eq 0 ]; then \
		echo "No installed '$(SCRIPT)' found on PATH or in $(BINDIR)."; \
	fi
