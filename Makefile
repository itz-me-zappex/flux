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

	for module in $(PWD)/src/functions/*.sh $(PWD)/src/macro/*.sh; do \
		echo >> $(FLUX_BUILD); \
		cat $$module >> $(FLUX_BUILD); \
	done

	echo >> $(FLUX_BUILD)
	cat src/main.sh >> $(FLUX_BUILD)

	chmod +x $(FLUX_BUILD)

	$(CC) $(CFLAGS) -o $(BUILD_DIR)/flux-listener $(CMODULES_DIR)/flux_listener.c \
	-lX11 -lXext -lXRes

	$(CC) $(CFLAGS) -o $(BUILD_DIR)/window-minimize $(CMODULES_DIR)/window_minimize.c \
	-lX11

	$(CC) $(CFLAGS) -o $(BUILD_DIR)/window-fullscreen $(CMODULES_DIR)/window_fullscreen.c \
	-lX11

	$(CC) $(CFLAGS) -o $(BUILD_DIR)/select-window $(CMODULES_DIR)/select_window.c \
	$(CFUNCTIONS_DIR)/third-party/xprop/clientwin.c \
	$(CFUNCTIONS_DIR)/third-party/xprop/dsimple.c \
	-lX11 -lXRes -lXext

	$(CC) $(CFLAGS) -o $(BUILD_DIR)/flux-grab-cursor $(CMODULES_DIR)/flux_grab_cursor.c \
	-lX11 -lXext -lXRes

	$(CC) $(CFLAGS) -o $(BUILD_DIR)/validate-x11-session $(CMODULES_DIR)/validate_x11_session.c \
	-lX11

clean:
	rm -rf $(BUILD_DIR)

install:
	mkdir -p $(PREFIX)/bin/
	mkdir -p $(PREFIX)/lib/flux/
	install -Dm 755 $(FLUX_BUILD) $(PREFIX)/bin/
	install -Dm 755 $(BUILD_DIR)/flux-listener $(PREFIX)/lib/flux/
	install -Dm 755 $(BUILD_DIR)/window-minimize $(PREFIX)/lib/flux/
	install -Dm 755 $(BUILD_DIR)/window-fullscreen $(PREFIX)/lib/flux/
	install -Dm 755 $(BUILD_DIR)/select-window $(PREFIX)/lib/flux/
	install -Dm 755 $(BUILD_DIR)/flux-grab-cursor $(PREFIX)/lib/flux/
	install -Dm 755 $(BUILD_DIR)/validate-x11-session $(PREFIX)/lib/flux/

	@if [[ $(PREFIX) != '/usr' ]]; then \
		echo -e "\nwarning: Unable to install '10-flux.conf' to '/etc/security/limits.d' because that is not '/usr' prefix!\n" >&2; \
	fi

	if [[ $(PREFIX) == '/usr' ]]; then \
		mkdir -p /etc/security/limits.d/; \
		install -Dm 644 $(PWD)/10-flux.conf /etc/security/limits.d/; \
	fi

uninstall:
	rm $(PREFIX)/bin/flux
	rm -rf $(PREFIX)/lib/flux/

	if [[ $(PREFIX) == '/usr' ]]; then \
		rm /etc/security/limits.d/10-flux.conf; \
	fi
