#!/usr/bin/bash

# Set default prefix path if it is not specified
if [[ -z "$PREFIX" ]]; then
	PREFIX='/usr/local'
fi

# Required to uninstall daemon from prefix
uninstall_from_prefix(){
	# Remove executable from prefix
	rm -v "$PREFIX/bin/flux" || return 1
	# Remove modules from prefix
	rm -vrf "$PREFIX/share/flux" || return 1
}

# Ask user before continue
if [[ -z "$CONFIRM" ]]; then
	echo "[info] Daemon will be uninstalled from '$PREFIX' prefix."
	echo "[tip] You may want to use 'CONFIRM=1' to avoid interactive behavior."
	echo "[tip] You may want to use 'PREFIX=<path>' to change path where daemon should be uninstalled from."
	read -p "[question] Continue? [y/N]: " continue
else
	continue='yes'
fi

# Continue if user allowed uninstallation
if [[ "${continue,,}" =~ ^(yes|y)$ ]]; then
	# Execute function to uninstall daemon
	echo "[info] Uninstalling daemon from '$PREFIX' prefix…"
	# Message and exit code depends by result
	if uninstall_from_prefix; then
		echo "[info] Daemon has been uninstalled from '$PREFIX' prefix successfully."
		exit 0
	else
		echo "[error] An error occured trying uninstall daemon from '$PREFIX' prefix!" >&2
		exit 1
	fi
else # Exit if did not
	echo "[info] Daemon uninstallation from '$PREFIX' prefix has been cancelled."
	exit 0
fi