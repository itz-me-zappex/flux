# Required to check whether daemon able to change and restore scheduling policy or not
# Executed once before event reading if there is section with 'idle' set to 'true'
sched_validate(){
  # Do not run checks if running as root
  if (( UID == 0 )); then
    sched_change_is_supported='1'
    sched_realtime_is_supported='1'
  else
    # Attempt to change scheduling policy to idle and restore it to check whether daemon can restore it on focus or not
    sleep 999 &
    local local_sleep_pid="$!"
    chrt --idle --pid 0 "$local_sleep_pid" > /dev/null 2>&1

    if ! chrt --other --pid 0 "$local_sleep_pid" > /dev/null 2>&1; then
      sched_change_is_supported='0'
      kill "$local_sleep_pid" > /dev/null 2>&1
      return 1
    else
      sched_change_is_supported='1'
      kill "$local_sleep_pid" > /dev/null 2>&1
    fi

    # Attempt to execute command with realtime scheduling policy to check whether daemon can restore it on focus or not
    if ! chrt --fifo 1 echo > /dev/null 2>&1; then
      sched_realtime_is_supported='0'
      return 1
    else
      sched_realtime_is_supported='1'
    fi
  fi
}