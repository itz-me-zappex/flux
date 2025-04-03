PREFIX ?= /usr/local

CC ?= gcc
CFLAGS ?= -O2 -s

PWD = $(shell pwd)

CMODULES_DIR = $(PWD)/src/modules
CFUNCTIONS_DIR = $(CMODULES_DIR)/functions

BUILD_DIR = $(PWD)/build

FLUX_BUILD = $(BUILD_DIR)/flux

all:
	mkdir -p $(BUILD_DIR)

	echo '#!/usr/bin/bash' > $(FLUX_BUILD)

	for module in $(PWD)/src/functions/*.sh; do \
		echo >> $(FLUX_BUILD); \
		cat $$module >> $(FLUX_BUILD); \
	done

	echo >> $(FLUX_BUILD)
	cat src/main.sh >> $(FLUX_BUILD)

	chmod +x $(FLUX_BUILD)

	$(CC) $(CFLAGS) -o $(BUILD_DIR)/flux-event-reader $(CMODULES_DIR)/flux_event_reader.c \
	$(CFUNCTIONS_DIR)/check_wm_restart.c \
	$(CFUNCTIONS_DIR)/get_active_window.c \
	$(CFUNCTIONS_DIR)/get_input_focus.c \
	$(CFUNCTIONS_DIR)/get_opened_windows.c \
	$(CFUNCTIONS_DIR)/get_window_process.c \
	$(CFUNCTIONS_DIR)/get_wm_window.c \
	-lX11 -lXext -lXRes

	$(CC) $(CFLAGS) -o $(BUILD_DIR)/window-minimize $(CMODULES_DIR)/window_minimize.c \
	$(CFUNCTIONS_DIR)/get_opened_windows.c \
	-lX11

	$(CC) $(CFLAGS) -o $(BUILD_DIR)/window-fullscreen $(CMODULES_DIR)/window_fullscreen.c \
	$(CFUNCTIONS_DIR)/get_opened_windows.c \
	-lX11

clean:
	rm -rf $(BUILD_DIR)

groupadd:
	groupadd -r flux

install:
	mkdir -p $(PREFIX)/bin/
	mkdir -p $(PREFIX)/lib/flux/
	install -Dm 755 $(FLUX_BUILD) $(PREFIX)/bin/
	install -Dm 755 $(BUILD_DIR)/flux-event-reader $(PREFIX)/lib/flux/
	install -Dm 755 $(BUILD_DIR)/window-minimize $(PREFIX)/lib/flux/

install-bypass:
	mkdir -p /etc/security/limits.d/
	install -Dm 644 $(PWD)/10-flux.conf /etc/security/limits.d/

groupdel:
	groupdel flux

uninstall:
	rm $(PREFIX)/bin/flux
	rm -rf $(PREFIX)/lib/flux/

uninstall-bypass:
	rm /etc/security/limits.d/10-flux.conf
