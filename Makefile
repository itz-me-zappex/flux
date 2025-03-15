PREFIX ?= /usr/local

CC ?= gcc
CFLAGS ?= -O2 -s

PWD = $(shell pwd)

BUILD_DIR = $(PWD)/build

FLUX_BUILD = $(BUILD_DIR)/flux

FLUX_EVENT_READER_BUILD = $(BUILD_DIR)/flux-event-reader
WINDOW_MINIMIZE_BUILD = $(BUILD_DIR)/window-minimize

all:
	mkdir -p $(BUILD_DIR)

	echo '#!/usr/bin/bash' > $(FLUX_BUILD)
	echo >> $(FLUX_BUILD)
	echo 'PREFIX="$(PREFIX)"' >> $(FLUX_BUILD)

	for module in $(PWD)/src/functions/*.sh; do \
		echo >> $(FLUX_BUILD); \
		cat $$module >> $(FLUX_BUILD); \
	done

	echo >> $(FLUX_BUILD)
	cat src/main.sh >> $(FLUX_BUILD)

	$(CC) $(CFLAGS) -o $(FLUX_EVENT_READER_BUILD) $(PWD)/src/modules/flux_event_reader.c \
	$(PWD)/src/modules/functions/check_wm_restart.c \
	$(PWD)/src/modules/functions/get_active_window.c \
	$(PWD)/src/modules/functions/get_input_focus.c \
	$(PWD)/src/modules/functions/get_opened_windows.c \
	$(PWD)/src/modules/functions/get_window_process.c \
	$(PWD)/src/modules/functions/get_wm_window.c \
	-lX11 -lXext -lXRes

	$(CC) $(CFLAGS) -o $(WINDOW_MINIMIZE_BUILD) $(PWD)/src/modules/window_minimize.c \
	$(PWD)/src/modules/functions/get_opened_windows.c \
	-lX11

clean:
	rm -rf $(BUILD_DIR)

groupadd:
	groupadd -r flux

install:
	mkdir -p $(PREFIX)/bin/
	mkdir -p $(PREFIX)/lib/flux/
	install -Dm 755 $(FLUX_BUILD) $(PREFIX)/bin/
	install -Dm 755 $(FLUX_EVENT_READER_BUILD) $(PREFIX)/lib/flux/
	install -Dm 755 $(WINDOW_MINIMIZE_BUILD) $(PREFIX)/lib/flux/

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
