# Configure compiler
CXXFLAGS ?= -O2 -s
CXX ?= g++

# Configure installation path
PREFIX ?= /usr/local

# Set path to bash modules
BASH_MODULES_PATH = $(shell pwd)/src/modules/bash
CPP_MODULES_PATH = $(shell pwd)/src/modules/cpp

# Set output directory
OUTPUT_PATH = $(shell pwd)/out

# Set path to 'flux' executable
FLUX_PATH = $(OUTPUT_PATH)/flux

# Build daemon if option is not specified
all:
	@mkdir -p "$(OUTPUT_PATH)"
	@echo '#!/usr/bin/bash' > $(FLUX_PATH)
	@for module in "$(BASH_MODULES_PATH)"/*.sh; do \
		echo >> "$(FLUX_PATH)"; \
		cat $$module >> "$(FLUX_PATH)"; \
	done
	@echo >> "$(FLUX_PATH)"
	@cat src/main.sh >> "$(FLUX_PATH)"
	@chmod +x "$(FLUX_PATH)"
	@$(CXX) $(CXXFLAGS) -o $(OUTPUT_PATH)/flux_event_reader $(CPP_MODULES_PATH)/flux_event_reader.cpp -lX11 -lXext -lXRes

# Remove build result if 'clean' option is passed
clean:
	@rm -rf $(OUTPUT_PATH)

# Install daemon to prefix if 'install' option is passed
install:
	@mkdir -p $(PREFIX)/{bin,lib/flux}
	@install -Dm 755 $(OUTPUT_PATH)/flux_event_reader $(PREFIX)/lib/flux/flux_event_reader
	@install -Dm 755 $(OUTPUT_PATH)/flux $(PREFIX)/bin/flux

# Uninstall daemon from prefix if 'uninstall' option is passed
uninstall:
	@rm -rf $(PREFIX)/lib/flux
	@unlink $(PREFIX)/bin/flux

# Define sections as Makefile options
.PHONY: all clean install uninstall