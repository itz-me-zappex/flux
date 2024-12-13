#!/usr/bin/bash

# Set default prefix path if it is not specified
if [[ -z "$PREFIX" ]]; then
	PREFIX='/usr/local'
fi

# Required to install daemon into prefix
install_to_prefix(){
	local local_module
	# Prepare prefix before install
	echo "[info] Creating required directories in '$PREFIX' prefix…"
	mkdir -vp "$PREFIX/"{bin,lib/flux} || return 1

	# Install executable into prefix
	echo "[info] Installing executable into '$PREFIX' prefix…"
	install -vDm 755 'src/flux' "$PREFIX/bin/" || return 1

	# Install modules into prefix
	echo "[info] Installing modules into '$PREFIX' prefix…"
	for local_module in src/modules/*.sh; do
		install -vDm 644 "$local_module" "$PREFIX/lib/flux/" || return 1
	done
}

# Ask user before continue
if [[ -z "$CONFIRM" ]]; then
	echo "[info] Daemon will be installed into '$PREFIX' prefix."
	echo "[tip] You may want to use 'CONFIRM=1' to avoid interactive behavior."
	echo "[tip] You may want to use 'PREFIX=<path>' to change installation path."
	read -p "[question] Continue? [y/N]: " continue
else
	continue='yes'
fi

# Continue if user allowed installation
if [[ "${continue,,}" =~ ^(yes|y)$ ]]; then
	# Execute function to install daemon
	echo "[info] Installing daemon into '$PREFIX' prefix…"
	# Message and exit code depends by result
	if install_to_prefix; then
		echo "[info] Daemon has been installed successfully into '$PREFIX' prefix."
		exit 0
	else
		echo "[error] An error occured trying install daemon into '$PREFIX' prefix!" >&2
		exit 1
	fi
else # Exit if did not
	echo "[info] Daemon installation into '$PREFIX' prefix has been cancelled."
	exit 0
fi