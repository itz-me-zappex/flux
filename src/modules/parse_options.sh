# Required for options parsing
parse_options(){
	# Continue until count of passed command line options is greater than zero
	while (( $# > 0 )); do
		case "$1" in
		--config | -c | --config=* )
			passed_check='config_is_passed' \
			passed_set='config' \
			passed_option='--config' \
			passed_short_option='-c' \
			cmdline_get "$@"
			shift "$shift"
			if [[ -n "$config" ]]; then
				config="$(get_realpath "$config")"
			fi
		;;
		--focus | -f | --pick | -p )
			# Check for X11 session
			if ! x11_session_check; then
				# Fail if something wrong with X server
				fail='1'
			fi
			# Define way to obtain info about window depending by type of option
			case "$1" in
			--focus | -f )
				# Check for failure related to X server check
				if [[ -n "$fail" ]]; then
					# Exit with an error if something wrong with X server
					message --error "Unable to get info about focused window, something is wrong with X11 session!"
					exit 1
				else
					# Get output of 'xprop' tool containing window ID
					window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null)"
					# Extract ID of focused window
					window_id="${window_id/*\# /}"
				fi
			;;
			--pick | -p )
				# Exit with an error if something wrong with X server
				if [[ -n "$fail" ]]; then
					message --error "Unable to trigger window picker, something is wrong with X11 session!"
					exit 1
				else
					# Get output of 'xwininfo' tool containing window ID
					if ! xwininfo_output="$(xwininfo 2>/dev/null)"; then
						message --error "Unable to grab cursor to pick a window!"
						exit 1
					else
						# Extract ID of focused window from output
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
			# Get process info and print it in compatible with config way
			if get_process_info; then
				echo "name = '"$process_name"'
executable = '"$process_executable"'
command = '"$process_command"'
owner = '"$process_owner_username"'
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
  -l, --log <path>           Store messages to specified file
  -L, --log-overwrite        Recreate log file before start, use only with '--log'
  -n, --notifications        Display messages as notifications
  -p, --pick                 Display info about picked window in usable for config file way and exit
  -q, --quiet                Display errors and warnings only
  -T, --timestamp-format     Set timestamp format, use only with '--timestamps' (default: [%Y-%m-%dT%H:%M:%S%z])
  -t, --timestamps           Add timestamps to messages
  -u, --usage                Alias for '--help'
  -v, --verbose              Detailed output
  -V, --version              Display release information and exit

Prefixes configuration:
  --prefix-error <prefix>    Set prefix for error messages (default: [x])
  --prefix-info <prefix>     Set prefix for info messages (default: [i])
  --prefix-verbose <prefix>  Set prefix for verbose messages (default: [~])
  --prefix-warning <prefix>  Set prefix for warning messages (default: [!])

Examples:
  flux -Hvt
  flux -HtLl ~/.flux.log -T '[%d.%m.%Y %H:%M:%S]'
  flux -ql ~/.flux.log
  flux -c ~/.config/flux.ini.bak
"
			exit 0
		;;
		--hot | -H )
			option_repeat_check hot --hot
			hot='1'
			shift 1
		;;
		--log | -l | --log=* )
			passed_check='log_is_passed' \
			passed_set='log' \
			passed_option='--log' \
			passed_short_option='-l' \
			cmdline_get "$@"
			shift "$shift"
			if [[ -n "$log" ]]; then
				log="$(get_realpath "$log")"
			fi
		;;
		--log-overwrite | -L )
			option_repeat_check log_overwrite --log-overwrite
			log_overwrite='1'
			shift 1
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
		--timestamp-format | -T | --timestamp-format=* )
			passed_check='timestamp_is_passed' \
			passed_set='new_timestamp_format' \
			passed_option='--timestamp-format' \
			passed_short_option='-T' \
			cmdline_get "$@"
			shift "$shift"
		;;
		--timestamps | -t )
			option_repeat_check timestamps --timestamps
			timestamps='1'
			shift 1
		;;
		--verbose | -v )
			option_repeat_check verbose --verbose
			verbose='1'
			shift 1
		;;
		--version | -V )
			author_github_link='https://github.com/itz-me-zappex'
			echo "flux $daemon_version
A daemon for X11 designed to automatically limit FPS or CPU usage
of unfocused windows and run commands on focus and unfocus events.
License: GPL-3.0-only
Author: $author_github_link
Repository: ${author_github_link}/flux
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
"
			exit 0
		;;
		--prefix-error | --prefix-error=* )
			passed_check='prefix_error_is_passed' \
			passed_set='new_prefix_error' \
			passed_option='--prefix-error' \
			cmdline_get "$@"
			shift "$shift"
		;;
		--prefix-info | --prefix-info=* )
			passed_check='prefix_info_is_passed' \
			passed_set='new_prefix_info' \
			passed_option='--prefix-info' \
			cmdline_get "$@"
			shift "$shift"
		;;
		--prefix-verbose | --prefix-verbose=* )
			passed_check='prefix_verbose_is_passed' \
			passed_set='new_prefix_verbose' \
			passed_option='--prefix-verbose' \
			cmdline_get "$@"
			shift "$shift"
		;;
		--prefix-warning | --prefix-warning=* )
			passed_check='prefix_warning_is_passed' \
			passed_set='new_prefix_warning' \
			passed_option='--prefix-warning' \
			cmdline_get "$@"
			shift "$shift"
		;;
		* )
			# First regexp means 2+ symbols after hyphen (combined short options)
			# Second regexp avoids long options
			if [[ "$1" =~ ^-.{2,}$ && ! "$1" =~ ^--.* ]]; then
				# Split combined option and add result to array, also skip first symbol as that is hypen
				for (( i = 1; i < ${#1} ; i++ )); do
					options_array+=("-${1:i:1}")
				done
				# Forget current option
				shift 1
				# Set options obtained after splitting
				set -- "${options_array[@]}" "$@"
				unset options_array i
			else
				message --error-opt "Unknown option '$1'!"
				exit 1
			fi
		esac
	done
	unset shift
}