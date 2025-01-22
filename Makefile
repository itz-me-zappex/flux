# Configure compiler
CXXFLAGS ?= -O2 -s
CXX ?= g++

# Configure installation path
PREFIX ?= /usr/local

# Set current directory
PWD ?= $(shell pwd)

# Set path to source code
SRC_PATH = $(PWD)/src

# Set path to bash modules
BASH_MODULES_PATH = $(SRC_PATH)/modules/bash
CPP_MODULES_PATH = $(SRC_PATH)/modules/cpp

# Set output directory
OUTPUT_PATH = $(PWD)/out

# Set path to built 'flux' executable
FLUX_OUTPUT_PATH = $(OUTPUT_PATH)/flux

# Set path to compiled 'flux-event-reader' binary
FLUX_EVENT_READER_OUTPUT_PATH = $(OUTPUT_PATH)/flux-event-reader

# Set path to limits config
FLUX_LIMITS_CONF_OUTPUT_PATH = $(OUTPUT_PATH)/10-flux-rtprio.conf

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
	cp $(SRC_PATH)/10-flux-rtprio.conf $(FLUX_LIMITS_CONF_OUTPUT_PATH)

# Remove build result if 'clean' option is passed
clean:
	rm -rf $(OUTPUT_PATH)

# Install daemon to prefix if 'install' option is passed
install:
	mkdir -p $(PREFIX)/bin
	mkdir -p $(PREFIX)/lib/flux
	install -Dm 755 $(FLUX_EVENT_READER_OUTPUT_PATH) $(PREFIX)/lib/flux/
	install -Dm 755 $(FLUX_OUTPUT_PATH) $(PREFIX)/bin/

# Install limits config if 'install-rtprio' option is passed
install-rtprio:
	install -Dm 644 $(FLUX_LIMITS_CONF_OUTPUT_PATH) /etc/security/limits.d/

# Uninstall daemon from prefix if 'uninstall' option is passed
uninstall:
	rm -rf $(PREFIX)/lib/flux
	rm $(PREFIX)/bin/flux

# Remove limits config if 'uninstall-rtprio' option is passed
uninstall-rtprio:
	rm /etc/security/limits.d/10-flux-rtprio.conf

# Define sections as Makefile options
.PHONY: all clean install uninstall install-rtprio uninstall-rtprio