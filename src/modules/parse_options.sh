# Required for options parsing
parse_options(){
	# Option parsing
	while (( $# > 0 )); do
		case "$1" in
		--config | -c | --config=* )
			# Assign value from option to variable using 'cmdline_get' function
			passed_check='config_is_passed' \
			passed_set='config' \
			passed_option='--config' \
			passed_short_option='-c' \
			cmdline_get "$@"
			# Forget first N command line options after storing value to variable, function returns count of times to shift depending by option type
			shift "$once_shift"
			# Get absolute path to config in case it is specified as relative
			if [[ -n "$config" ]]; then
				config="$(get_realpath "$config")"
			fi
		;;
		--focus | -f | --pick | -p )
			# Check for X11 session
			if ! x11_session_check; then
				# Fail if something wrong with X server
				once_fail='1'
			fi
			# Select command depending by type of option
			case "$1" in
			--focus | -f )
				# Check for failure related to X server check
				if [[ -n "$once_fail" ]]; then
					# Exit with an error if something wrong with X server
					message --error "Unable to get info about focused window, something is wrong with X11 session!"
					exit 1
				else
					# Get output of xprop containing window ID
					window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
					# Extract ID of focused window
					window_id="${window_id/*\# /}"
				fi
			;;
			--pick | -p )
				# Exit with an error if something wrong with X server
				if [[ -n "$once_fail" ]]; then
					message --error "Unable to call window picker, something is wrong with X11 session!"
					exit 1
				else
					# Get xwininfo output containing window ID
					if ! xwininfo_output="$(xwininfo 2>/dev/null)"; then
						message --error "Unable to grab cursor to pick a window!"
						exit 1
					else
						# Extract ID of focused window
						while read -r temp_xwininfo_output_line; do
							if [[ "$temp_xwininfo_output_line" == 'xwininfo: Window id: '* ]]; then
								window_id="${temp_xwininfo_output_line/xwininfo: Window id: /}"
								window_id="${window_id/ */}"
								break
							fi
						done <<< "$xwininfo_output"
						unset temp_xwininfo_output_line
					fi
				fi
			esac
			# Get process info and print it in a way to easy use it in config
			if get_process_info; then
				echo "name = '"$process_name"'
executable = '"$process_executable"'
command = '"$process_command"'
owner = "$process_owner"
"
				exit 0
			else
				message --error "Unable to create template for window with ID $window_id as it does not report its PID!"
				exit 1
			fi
		;;
		--help | -h | --usage | -u )
			echo "Usage: flux [OPTIONS]

Options and values:
  -c, --config <path>        Specify path to config file
                             (default: \$XDG_CONFIG_HOME/flux.ini; \$HOME/.config/flux.ini; /etc/flux.ini)
  -f, --focused              Display info about focused window in compatible with config way and exit
  -h, --help                 Display this help and exit
  -H, --hot                  Apply actions to already unfocused windows before handling events
  -l, --lazy                 Avoid focus and unfocus commands on hot (use only with '--hot')
  -L, --log <path>           Store messages to specified file
  -n, --notifications        Display messages as notifications
  -p, --pick                 Display info about picked window in usable for config file way and exit
  -q, --quiet                Display errors and warnings only
  -u, --usage                Alias for '--help'
  -v, --verbose              Detailed output
  -V, --version              Display release information and exit

Logging configuration (use only with '--log'):
  --log-no-timestamps        Do not add timestamps to messages in log (do not use with '--log-timestamp')
  --log-overwrite            Recreate log file before start
  --log-timestamp <format>   Set timestamp format (default: [%Y-%m-%dT%H:%M:%S%z])

Prefixes configuration:
  --prefix-error <prefix>    Set prefix for error messages (default: [x])
  --prefix-info <prefix>     Set prefix for info messages (default: [i])
  --prefix-verbose <prefix>  Set prefix for verbose messages (default: [~])
  --prefix-warning <prefix>  Set prefix for warning messages (default: [!])

Examples:
  flux -Hlv
  flux -HlL ~/.flux.log --log-overwrite --log-timestamp '[%d.%m.%Y %H:%M:%S]'
  flux -qL ~/.flux.log --log-no-timestamps
  flux -c ~/.config/flux.ini.bak
"
			exit 0
		;;
		--hot | -H )
			option_repeat_check hot --hot
			hot='1'
			shift 1
		;;
		--lazy | -l )
			option_repeat_check lazy --lazy
			lazy='1'
			shift 1
		;;
		--log | -L | --log=* )
			# Assign value from option to variable using 'cmdline_get' function
			passed_check='log_is_passed' \
			passed_set='log' \
			passed_option='--log' \
			passed_short_option='-L' \
			cmdline_get "$@"
			# Forget first N command line options after storing value to variable, function returns count of times to shift depending by option type
			shift "$once_shift"
			# Get absolute path to log file in case it is specified as relative
			if [[ -n "$log" ]]; then
				log="$(get_realpath "$log")"
			fi
		;;
		--notifications | -n )
			option_repeat_check notifications --notifications
			notifications='1'
			shift 1
		;;
		--quiet | -q )
			option_repeat_check quiet --quiet
			quiet='1'
			shift 1
		;;
		--verbose | -v )
			option_repeat_check verbose --verbose
			verbose='1'
			shift 1
		;;
		--version | -V )
			author_github_link='https://github.com/itz-me-zappex'
			echo "flux 1.10.2
A daemon for X11 designed to automatically limit FPS or CPU usage of unfocused windows and run commands on focus and unfocus events.
License: GPL-3.0-only
Author: $author_github_link
Repository: ${author_github_link}/flux
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
"
			exit 0
		;;
		--prefix-error | --prefix-error=* )
			# Assign value from option to variable using 'cmdline_get' function
			passed_check='prefix_error_is_passed' \
			passed_set='new_prefix_error' \
			passed_option='--prefix-error' \
			cmdline_get "$@"
			# Forget first N command line options after storing value to variable, function returns count of times to shift depending by option type
			shift "$once_shift"
		;;
		--prefix-info | --prefix-info=* )
			# Assign value from option to variable using 'cmdline_get' function
			passed_check='prefix_info_is_passed' \
			passed_set='new_prefix_info' \
			passed_option='--prefix-info' \
			cmdline_get "$@"
			# Forget first N command line options after storing value to variable, function returns count of times to shift depending by option type
			shift "$once_shift"
		;;
		--prefix-verbose | --prefix-verbose=* )
			# Assign value from option to variable using 'cmdline_get' function
			passed_check='prefix_verbose_is_passed' \
			passed_set='new_prefix_verbose' \
			passed_option='--prefix-verbose' \
			cmdline_get "$@"
			# Forget first N command line options after storing value to variable, function returns count of times to shift depending by option type
			shift "$once_shift"
		;;
		--prefix-warning | --prefix-warning=* )
			# Assign value from option to variable using 'cmdline_get' function
			passed_check='prefix_warning_is_passed' \
			passed_set='new_prefix_warning' \
			passed_option='--prefix-warning' \
			cmdline_get "$@"
			# Forget first N command line options after storing value to variable, function returns count of times to shift depending by option type
			shift "$once_shift"
		;;
		--log-no-timestamps )
			option_repeat_check log_no_timestamps --log-no-timestamps
			log_no_timestamps='1'
			shift 1
		;;
		--log-overwrite )
			option_repeat_check log_overwrite --log-overwrite
			log_overwrite='1'
			shift 1
		;;
		--log-timestamp | --log-timestamp=* )
			# Assign value from option to variable using 'cmdline_get' function
			passed_check='log_timestamp_is_passed' \
			passed_set='new_log_timestamp' \
			passed_option='--log-timestamp' \
			cmdline_get "$@"
			# Forget first N command line options after storing value to variable, function returns count of times to shift depending by option type
			shift "$once_shift"
		;;
		* )
			# First regexp means 2+ symbols after hyphen (combined short options)
			# Second regexp avoids long options
			if [[ "$1" =~ ^-.{2,}$ && ! "$1" =~ ^--.* ]]; then
				# Split combined option and add result to array, also skip first symbol as that is hypen
				for (( i = 1; i < ${#1} ; i++ )); do
					once_options_array+=("-${1:i:1}")
				done
				# Forget current option
				shift 1
				# Set options obtained after splitting
				set -- "${once_options_array[@]}" "$@"
				unset once_options_array i
			else
				message --error "Unknown option '$1'!$advice_on_option_error"
				exit 1
			fi
		esac
	done
	unset once_shift
}