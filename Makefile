# Configure compiler
CXXFLAGS ?= -O2 -s
CXX = g++

# Configure installation path
PREFIX ?= /usr/local

# Set path to bash modules
BASH_MODULES_PATH = $(PWD)/src/modules/bash
CPP_MODULES_PATH = $(PWD)/src/modules/cpp

# Set output directory
OUTPUT_PATH = $(PWD)/out

# Set path to 'flux' executable
FLUX_PATH = $(OUTPUT_PATH)/flux

# Build script
build:
	@mkdir -p "$(OUTPUT_PATH)"
	@echo '#!/usr/bin/bash' > $(FLUX_PATH)
	@for module in "$(BASH_MODULES_PATH)"/*.sh; do \
		echo >> "$(FLUX_PATH)"; \
		cat $$module >> "$(FLUX_PATH)"; \
	done
	@echo >> "$(FLUX_PATH)"
	@cat src/main.sh >> "$(FLUX_PATH)"
	@chmod +x "$(FLUX_PATH)"
	@$(CXX) $(CXXFLAGS) -o $(OUTPUT_PATH)/get_window_pid $(CPP_MODULES_PATH)/get_window_pid.cpp  -lX11 -lXext -lXRes

# make
all: build

# make clean
clean:
	@rm -rf $(OUTPUT_PATH)

# make install
install:
	@mkdir -p $(PREFIX)/{bin,lib/flux}
	@install -Dm 755 $(OUTPUT_PATH)/* $(PREFIX)/lib/flux/
	@ln -s $(PREFIX)/lib/flux/flux $(PREFIX)/bin/flux

# make uninstall
uninstall:
	@rm -rf $(PREFIX)/lib/flux
	@unlink $(PREFIX)/bin/flux

.PHONY: all clean install uninstall