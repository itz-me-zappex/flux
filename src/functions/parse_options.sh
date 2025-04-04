# Required for options parsing
parse_options(){
  # Continue until count of passed command line options is greater than zero
  while (( $# > 0 )); do
    case "$1" in
    --color | -C | --color=* )
      passed_check='color_is_passed' \
      passed_set='color' \
      passed_option='--color' \
      passed_short_option='-C' \
      cmdline_get "$@"

      shift "$shift"
    ;;
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
    --get | -g | --get=* )
      passed_check='get_is_passed' \
      passed_set='get' \
      passed_option='--get' \
      passed_short_option='-g' \
      cmdline_get "$@"

      shift "$shift"

      if [[ -z "$get" ]]; then
        message --error-opt "Option '--get' is specified without how to obtain window process info!"
        exit 1
      elif [[ ! "${get,,}" =~ ^('pick'|'focus')$ ]]; then
        message --error-opt "Specified action '$get' in '--get' option is not supported!"
        exit 1
      fi

      if ! window_info="$("$select_window_path" "${get,,}" 2>/dev/null)"; then
        message --error "Unable to obtain process info because of either bad event, issue with X server or inability to grab mouse for picker!"
        exit 1
      else
        window_xid="${window_info/'='*/}"
        process_pid="${window_info/*'='/}"

        get_process_info

        if (( get_process_info_exit_code == 1 )); then
          message --error "Unable to obtain info about process with PID $process_pid of window with XID $window_xid! Probably process has been terminated during check."
          exit 1
        elif (( get_process_info_exit_code == 2 )); then
          message --error "Unable to obtain owner username of process $process_name with PID $process_pid of window with XID $window_xid!"
          exit 1
        fi

        echo "Window XID (decimal):     $window_xid
Window XID (hexadecimal): $(printf "0x%x\n" $window_xid)
Process PID:              $process_pid
Process name:             $process_name
Process owner (UID):      $process_owner
Process owner (username): $process_owner_username
Process command:          "$process_command"
"
      fi

      exit 0
    ;;
    --help | -h | --usage | -u )
      echo "Usage: flux [-C <when>] [-c <path>] [-g <how>] [-l <path>] [-T <format>] [-Pe/-Pi/-Pv/-Pw <prefix>] [options]

Options and values:
  -C, --color <when>                  Color mode, either 'always', 'auto' or 'never'
                                      default: 'auto'
  -c, --config <path>                 Specify path to config file
                                      default: '\$XDG_CONFIG_HOME/flux.ini' or '\$HOME/.config/flux.ini' or '/etc/flux.ini'
  -g, --get <how>                     Display window process info and exit, accepts either 'focus' or 'pick'
  -h, --help                          Display this help and exit
  -H, --hot                           Apply actions to already unfocused windows before handling events
  -l, --log <path>                    Store messages to specified file
  -L, --log-overwrite                 Recreate log file before start, requires '--log'
  -n, --notifications                 Display messages as notifications
  -q, --quiet                         Display errors and warnings only
  -T, --timestamp-format <format>     Set timestamp format, requires '--timestamps'
                                      default: '[%Y-%m-%dT%H:%M:%S%z]'
  -t, --timestamps                    Add timestamps to messages
  -u, --usage                         Alias for '--help'
  -v, --verbose                       Detailed output
  -V, --version                       Display release information and exit

Prefixes configuration:
  -Pe, --prefix-error <prefix>        Set prefix for error messages
                                      default: '[x]'
  -Pi, --prefix-info <prefix>         Set prefix for info messages
                                      default: '[i]'
  -Pv, --prefix-verbose <prefix>      Set prefix for verbose messages
                                      default: '[~]'
  -Pw, --prefix-warning <prefix>      Set prefix for warning messages
                                      default: '[!]'

Examples:
  flux -Hvt
  flux -HtLl ~/.flux.log -T '[%d.%m.%Y %H:%M:%S]'
  flux -ql ~/.flux.log
  flux -c ~/.config/flux.ini.bak
  flux -tT '(\e[1;4;36m%d.%m.%Y\e[0m \e[1;4;31m%H:%M:%S\e[0m)'
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
Advanced daemon for X11 desktops and window managers, designed to automatically limit FPS/CPU usage of
unfocused windows and run commands on focus and unfocus events. Written in Bash and partially in C.
License: GPL-3.0-only
Author: $author_github_link
Repository: ${author_github_link}/flux
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
"
      exit 0
    ;;
    --prefix-error | -Pe | --prefix-error=* )
      passed_check='prefix_error_is_passed' \
      passed_set='new_prefix_error' \
      passed_option='--prefix-error' \
      passed_short_option='-Pe' \
      cmdline_get "$@"

      shift "$shift"
    ;;
    --prefix-info | -Pi | --prefix-info=* )
      passed_check='prefix_info_is_passed' \
      passed_set='new_prefix_info' \
      passed_option='--prefix-info' \
      passed_short_option='-Pi' \
      cmdline_get "$@"

      shift "$shift"
    ;;
    --prefix-verbose | -Pv | --prefix-verbose=* )
      passed_check='prefix_verbose_is_passed' \
      passed_set='new_prefix_verbose' \
      passed_option='--prefix-verbose' \
      passed_short_option='-Pv' \
      cmdline_get "$@"

      shift "$shift"
    ;;
    --prefix-warning | -Pw | --prefix-warning=* )
      passed_check='prefix_warning_is_passed' \
      passed_set='new_prefix_warning' \
      passed_option='--prefix-warning' \
      passed_short_option='-Pw' \
      cmdline_get "$@"

      shift "$shift"
    ;;
    * )
      # First regexp means 2+ symbols after hyphen (combined short options)
      # Second regexp avoids long options
      if [[ "$1" =~ ^-.{2,}$ &&
            ! "$1" =~ ^--.* ]]; then
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
