#!/usr/bin/bash

# Required to merge modules into single 'flux' executable
build(){
	local local_modules_path \
	local_modules_list \
	local_temp_module
	# Path to modules
	local_modules_path="$PWD/src/modules"
	# List of modules
	local_modules_list=(
		actions_on_exit.sh
		auxiliary.sh
		background_cpu_limit.sh
		background_fps_limit.sh
		background_freeze.sh
		background_sched_idle.sh
		calculate_max_limit.sh
		daemon_prepare.sh
		event_source.sh
		exec_focus.sh
		exec_unfocus.sh
		find_matching_section.sh
		focus_unset_limit.sh
		get_process_info.sh
		handle_terminated_windows.sh
		mangohud_fps_set.sh
		message.sh
		parse_config.sh
		parse_options.sh
		set_requested_limits.sh
		unfocus_request_limit.sh
		unfreeze_process.sh
		unset_cpu_limit.sh
		unset_fps_limit.sh
		unset_sched_idle.sh
		validate_config_keys.sh
		validate_config.sh
		validate_log.sh
		validate_options.sh
	)
	# Exit with an error if that is not directory with source
	if [[ "$(dirname "$0")" != '.' ]]; then
		echo "[x] You need to change directory to one with source code!" >&2
		return 1
	fi
	# Check for all modules existence
	for local_temp_module in "${local_modules_list[@]}"; do
		if [[ ! -f "$local_modules_path/$local_temp_module" ]]; then
			echo "[x] Module '$local_temp_module' does not exist!" >&2
			module_error='1'
		fi
	done
	# Exit with an error if module is missed
	if [[ -n "$module_error" ]]; then
		return 1
	fi
	# Exit with an error if 'flux' already exists
	if [[ -f 'flux' ]]; then
		echo "[x] Generated executable 'flux' already exists, rename or remove it before build!" >&2
		return 1
	fi
	# Add shebang to 'flux'
	echo "[i] Adding shebang to 'flux'..."
	echo '#!/usr/bin/bash' > flux || return 1
	# Merge modules and store them to 'flux'
	echo "[i] Merging modules..."
	for local_temp_module in "${local_modules_list[@]}"; do
		echo "[i] Adding content of '$local_temp_module' module to 'flux'..."
		echo >> flux || return 1
		echo "$(<"$local_modules_path/$local_temp_module")" >> flux || return 1
	done
	# Merge 'main.sh' with 'flux'
	echo "[i] Adding content of 'main.sh' to 'flux'.."
	echo >> flux || return 1
	echo "$(<'src/main.sh')" >> flux || return 1
	# Make it executable
	echo "[i] Making 'flux' file executable..."
	chmod +x flux || return 1
}

# Build executable
if build; then
	echo "[i] Executable has been built successfuly."
else
	echo "[x] An error occured trying build executable!"
	exit 1
fi