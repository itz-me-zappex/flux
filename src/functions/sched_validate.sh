# Required to check whether daemon able to change and restore scheduling policy or not
# Executed once before event reading if there is section with 'idle' set to 'true'
sched_validate(){
  # Skip checks if running as root
  if (( UID == 0 )); then
    sched_change_is_supported='1'
    sched_realtime_is_supported='1'
  else
    # Attempt to change scheduling policy to 'idle' and restore it to check whether daemon can restore it on focus or not
    sleep 999 &
    local local_sleep_pid="$!"
    chrt --idle --pid 0 "$local_sleep_pid" > /dev/null 2>&1
    if ! chrt --other --pid 0 "$local_sleep_pid" > /dev/null 2>&1; then
      message --warning "Daemon has insufficient rights to change scheduling policies! To make 'idle' config key work, add your user to 'flux' group and reboot."
    else
      sched_change_is_supported='1'
    fi
    kill "$local_sleep_pid" > /dev/null 2>&1

    # Attempt to execute command with realtime scheduling policy to check whether daemon can restore it on focus or not
    if [[ -n "$sched_change_is_supported" ]] &&
       ! chrt --fifo 1 echo > /dev/null 2>&1; then
      # Adding user to 'flux' group already allows using these scheduling policies
      # This message will appear in case user configured '/etc/security/limits.conf' manually just to allow support of 'SCHED_IDLE', 'SCHED_BATCH' and 'SCHED_OTHER'
      message --info "Daemon has insufficient rights to support 'RR' (round robin) and 'FIFO' (first in first out) scheduling policies. If you need this feature, then add your user to 'flux' group and reboot!"
    else
      sched_realtime_is_supported='1'
    fi
  fi
}
