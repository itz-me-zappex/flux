# To parse command line options
parse_options(){
  local local_shift_request

  # Continue until count of passed command line options become zero
  while (( $# > 0 )); do
    case "$1" in
    --color | -C | --color=* )
      cmdline_get 'local_shift_request' 'color_is_passed' '--color' '-C' 'color' "$@"
      shift "$local_shift_request"
    ;;
    --config | -c | --config=* )
      cmdline_get 'local_shift_request' 'config_is_passed' '--config' '-c' 'config' "$@"
      shift "$local_shift_request"

      if [[ -n "$config" ]]; then
        local local_get_realpath_result
        get_realpath "$config"
        config="$local_get_realpath_result"
      fi
    ;;
    --get | -g | --get=* )
      cmdline_get 'local_shift_request' 'get_is_passed' '--get' '-g' 'get' "$@"
      shift "$local_shift_request"

      # 'PiCk' -> 'pick' etc.
      get="${get,,}"

      if [[ -z "$get" ]]; then
        message --error-opt "Option '--get' requires a method!"
        exit 1
      elif [[ ! "$get" =~ ^('pick'|'focus')$ ]]; then
        message --error-opt "Specified method '$get' in '--get' option is not supported!"
        exit 1
      fi

      check_x11

      # Execute module responsible for getting window info and remember output
      window_info="$(select-window "$get" 2>/dev/null)"
      select_window_exit_code="$?"

      # Define message depending on exit code
      if (( select_window_exit_code > 0 )) ; then
        case "$get" in
        focus )
          case "$select_window_exit_code" in
          3 )
            message --error "Unable to obtain PID and XID of focused window, window is not stacking one!"
          ;;
          4 )
            message --error "Unable to obtain PID and XID of focused window, probably window closed too early!"
          ;;
          * )
            message --error "Unexpected error occured trying to obtain PID and XID of focused window!"
          esac
        ;;
        pick )
          case "$select_window_exit_code" in
          2 )
            message --error "Unable to create window picker, cursor is already grabbed by another window!"
          ;;
          3 )
            message --error "Unable to obtain PID and XID of picked window, window is not stacking one!"
          ;;
          4 )
            message --error "Unable to obtain PID and XID of picked window, probably window closed too early!"
          ;;
          * )
            message --error "Unexpected error occured trying to create window picker!"
          esac
        esac

        exit 1
      else
        window_xid="${window_info/'='*/}"
        pid="${window_info/*'='/}"

        get_process_info_msg_type='--error'
        if ! get_process_info; then
          exit 1
        fi

        echo "XID (decimal): "$window_xid"
XID (hexadecimal): "$(printf "0x%x\n" "$window_xid")"
PID: "$pid"
Name: "$process_name"
Owner (UID): "$process_owner"
Owner (username): "$process_owner_username"
Command: "$process_command"
" | less_or_echo
      fi

      exit 0
    ;;
    --help | -h | --usage | -u )
      echo "Usage: flux [-C <mode>] [-c <file>] [-g <method>] [-l <file>] [-T <format>] [--pe/--pi/--pv/--pw <text>] [options]

Options and values:
  -C, --color <mode>                  Color mode, either 'always', 'auto' or 'never'
                                      default: auto
  -c, --config <file>                 Change path to config file
                                      default: 1) \$XDG_CONFIG_HOME/flux.ini
                                               2) \$HOME/.config/flux.ini
                                               3) /etc/flux.ini
  -g, --get <method>                  Display window process info and exit, method either 'focus' or 'pick'
  -h, --help                          Display this help and exit
  -H, --hot                           Apply actions to already unfocused windows before handling events
  -l, --log <file>                    Enable logging and set path to log file
  -L, --log-overwrite                 Recreate log file before start, depends on '--log' option
  -n, --notifications                 Display notifications
  -q, --quiet                         Display errors and warnings only
  -T, --timestamp-format <format>     Set timestamp format, depends on '--timestamps' option
                                      default: [%Y-%m-%dT%H:%M:%S%z]
  -t, --timestamps                    Include timestamps in messages
  -u, --usage                         Alias for '--help'
  -v, --verbose                       Detailed output
  -V, --version                       Display release information and exit

Prefixes configuration:
  --pe, --prefix-error <text>         Change prefix for error messages
                                      default: [x]
  --pi, --prefix-info <text>          Change prefix for info messages
                                      default: [i]
  --pv, --prefix-verbose <text>       Change prefix for verbose messages
                                      default: [~]
  --pw, --prefix-warning <text>       Change prefix for warning messages
                                      default: [!]

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
      cmdline_get 'local_shift_request' 'log_is_passed' '--log' '-l' 'log' "$@"
      shift "$local_shift_request"

      if [[ -n "$log" ]]; then
        local local_get_realpath_result
        get_realpath "$log"
        log="$local_get_realpath_result"
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
      cmdline_get 'local_shift_request' 'timestamp_is_passed' '--timestamp-format' '-T' 'new_timestamp_format' "$@"
      shift "$local_shift_request"
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
      echo "flux v$daemon_version
FLawless User eXperience
An advanced automation daemon for X11 desktops and window managers.
Designed to limit FPS/CPU usage and run commands on window focus and unfocus events.
Provides gaming-oriented features.
Written mostly in Bash and partially in C.
License: GPL-3.0-only
Author: $author_github_link
Repository: ${author_github_link}/flux
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
"
      exit 0
    ;;
    --prefix-error | --pe | --prefix-error=* )
      cmdline_get 'local_shift_request' 'prefix_error_is_passed' '--prefix-error' '--pe' 'new_prefix_error' "$@"
      shift "$local_shift_request"
    ;;
    --prefix-info | --pi | --prefix-info=* )
      cmdline_get 'local_shift_request' 'prefix_info_is_passed' '--prefix-info' '--pi' 'new_prefix_info' "$@"
      shift "$local_shift_request"
    ;;
    --prefix-verbose | --pv | --prefix-verbose=* )
      cmdline_get 'local_shift_request' 'prefix_verbose_is_passed' '--prefix-verbose' '--pv' 'new_prefix_verbose' "$@"
      shift "$local_shift_request"
    ;;
    --prefix-warning | --pw | --prefix-warning=* )
      cmdline_get 'local_shift_request' 'prefix_warning_is_passed' '--prefix-warning' '--pw' 'new_prefix_warning' "$@"
      shift "$local_shift_request"
    ;;
    * )
      # First regexp means 2+ symbols after hyphen (combined short options)
      # Second regexp avoids long options
      if [[ "$1" =~ ^-.{2,}$ &&
            ! "$1" =~ ^--.* ]]; then
        # Split combined option and add result to array,
        # also skip first symbol as that is hypen
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
}
