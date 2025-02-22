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
      kill "$local_sleep_pid" > /dev/null 2>&1
      message --warning "Daemon has insufficient rights to restore scheduling policies, including 'other', add your user to 'flux' group and reboot!"
      return 0
    else
      sched_change_is_supported='1'
      kill "$local_sleep_pid" > /dev/null 2>&1
    fi

    # Attempt to execute command with realtime scheduling policy to check whether daemon can restore it on focus or not
    if ! chrt --fifo 1 echo > /dev/null 2>&1; then
      message --warning "Daemon has insufficient rights to restore 'RR' (round robin) and 'FIFO' (first in first out) scheduling policies, add your user to 'flux' group and reboot!"
      return 0
    else
      sched_realtime_is_supported='1'
    fi

    # Warn user about inablity to restore 'SCHED_DEADLINE' in case daemon runs without root rights
    if (( UID != 0 )); then
      message --warning "Daemon has insufficient rights to restore 'deadline' scheduling policy! If you need that feature, run daemon as root."
    fi
  fi
}