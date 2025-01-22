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

# Set path to built 'flux' executable
FLUX_OUTPUT_PATH = $(OUTPUT_PATH)/flux

# Set path to compiled 'flux-event-reader' binary
FLUX_EVENT_READER_OUTPUT_PATH = $(OUTPUT_PATH)/flux-event-reader

# Build daemon if option is not specified
all:
	mkdir -p "$(OUTPUT_PATH)"
	echo '#!/usr/bin/bash' > $(FLUX_OUTPUT_PATH)
	for module in "$(BASH_MODULES_PATH)"/*.sh; do \
		echo >> "$(FLUX_OUTPUT_PATH)"; \
		cat $$module >> "$(FLUX_OUTPUT_PATH)"; \
	done
	echo >> "$(FLUX_OUTPUT_PATH)"
	cat src/main.sh >> "$(FLUX_OUTPUT_PATH)"
	chmod +x "$(FLUX_OUTPUT_PATH)"
	$(CXX) $(CXXFLAGS) -o $(FLUX_EVENT_READER_OUTPUT_PATH) $(CPP_MODULES_PATH)/flux_event_reader.cpp -lX11 -lXext -lXRes

# Remove build result if 'clean' option is passed
clean:
	rm -rf $(OUTPUT_PATH)

# Install daemon to prefix if 'install' option is passed
install:
	mkdir -p $(PREFIX)/bin
	mkdir -p $(PREFIX)/lib/flux
	install -Dm 755 $(FLUX_EVENT_READER_OUTPUT_PATH) $(PREFIX)/lib/flux/
	install -Dm 755 $(FLUX_OUTPUT_PATH) $(PREFIX)/bin/

# Uninstall daemon from prefix if 'uninstall' option is passed
uninstall:
	rm -rf $(PREFIX)/lib/flux
	rm $(PREFIX)/bin/flux

# Define sections as Makefile options
.PHONY: all clean install uninstall