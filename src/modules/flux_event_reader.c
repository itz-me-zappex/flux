#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/extensions/XRes.h>
#include <unistd.h>

#include "functions/check_wm_restart.h"
#include "functions/get_active_window.h"
#include "functions/get_input_focus.h"
#include "functions/get_opened_windows.h"
#include "functions/get_window_process.h"
#include "functions/get_wm_window.h"

// Daemon
int main() {
  // Use line buffer to make output readable from command substitution in Bash
  setlinebuf(stdout);

  // Store obtained data here
  Window active_window;
  pid_t active_window_process;
  pid_t opened_window_process;
  Window wm_window;
  Window *opened_windows = NULL;
  unsigned long opened_windows_count, previous_opened_windows_count;

  // Bitwise difference between current and previous atom states
  unsigned long active_window_xor, opened_windows_xor, wm_window_xor;
  unsigned long previous_active_window_xor, previous_opened_windows_xor, previous_wm_window_xor;

  // Attempt to open display
  Display *display = XOpenDisplay(NULL);
  if (!display) {
    return 1;
  }

  // Declare needed atoms
  Atom net_active_window = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
  Atom wm_s0 = XInternAtom(display, "WM_S0", False);
  Atom net_supporting_wm_check = XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", False);
  Atom net_client_list_stacking = XInternAtom(display, "_NET_CLIENT_LIST_STACKING", False);

  // Get root window
  Window root = DefaultRootWindow(display);

  // Exit with an error if window manager is not running
  if (get_wm_window(display, root, net_supporting_wm_check) == None) {
    return 1;
  }

  // Get and print its own PID, needed to make daemon receive it as event and make it able to terminate this process on exit
  const pid_t event_reader_pid = getpid();
  printf("%d\n", event_reader_pid);

  // Listen changes in atoms
  XSelectInput(display, root, PropertyChangeMask);
  XEvent event;

  // Simulate event to handle current atoms state immediately
  bool fake_event = true;

  // Mark needed to remember and handle WM restart
  bool wm_restart_mark = false;

  // Handle changes in atom states
  while (true) {
    // Do not wait for event if there is fake one
    if (!fake_event) {
      XNextEvent(display, &event);
      // Handle only needed events
      if (event.type != PropertyNotify &&
          event.xproperty.atom != net_active_window &&
          event.xproperty.atom != net_client_list_stacking) {
        continue;
      }
    } else if (fake_event) {
      fake_event = false;
    }

    // Do not check 'WM_S0' if WM restart has been detected
    if (!wm_restart_mark) {
      // Set mark and skip loop if WM has been restarted
      if (check_wm_restart(display, root, wm_s0)) {
        // Remember opened windows count and skip events until current value equals before restart one
        previous_opened_windows_count = opened_windows_count;

        // Remember that WM has been restarted as this event appears only once
        wm_restart_mark = true;

        // Skip event
        continue;
      } else {
        // Wait 50ms before handle event and unset pending events after delay
        usleep(50000);
        while (XPending(display)) {
          XNextEvent(display, &event);
        }
      }
    }

    // Unset bits as I need new value instead of increasing it
    active_window_xor = 0;
    opened_windows_xor = 0;
    wm_window_xor = 0;

    // Freeing here because of a bunch of 'continue' below
    XFree(opened_windows);

    // Get list of opened windows from '_NET_CLIENT_LIST_STACKING'
    opened_windows = get_opened_windows(display, root, &opened_windows_count, net_client_list_stacking);

    // Skip event if list of opened windows appears blank
    if (!opened_windows) {
      continue;
    }

    // Check for WM restart
    if (wm_restart_mark) {
      // Skip loops until '_NET_CLIENT_LIST_STACKING' become adequate
      if (previous_opened_windows_count != opened_windows_count) {
        continue;
      } else {
        // Unset mark and handle this event
        wm_restart_mark = false;
      }
    }

    // Get window XID from '_NET_ACTIVE_WINDOW'
    active_window = get_active_window(display, root, net_active_window);
    // Get window manager XID from '_NET_SUPPORTING_WM_CHECK'
    wm_window = get_wm_window(display, root, net_supporting_wm_check);
    // Fallback
    if (active_window == None) {
      // Use 'XGetInputFocus()' if '_NET_ACTIVE_WINDOW' is zero
      active_window = get_input_focus(display);
      // Skip loop if 'XGetInputFocus()' did not return window manager XID
      if (active_window != wm_window) {
        continue;
      }
    }
    // Used to check difference between previous and current states
    active_window_xor ^= active_window;
    wm_window_xor ^= wm_window;
    for (unsigned long i = 0; i < opened_windows_count; i++) {
      opened_windows_xor ^= opened_windows[i];
    }

    // Print atom states if at least one has been changed
    if (active_window_xor != previous_active_window_xor ||
        opened_windows_xor != previous_opened_windows_xor ||
        wm_window_xor != previous_wm_window_xor) {
      // Get and print info about focused window
      active_window_process = get_window_process(display, active_window);
      // Skip event if XRes returned zero PID for active window
      if (active_window_process != 0) {
        printf("%ld=%d\n", active_window, active_window_process);
      } else {
        continue;
      }

      // Get and print info about opened windows
      for (unsigned long i = 0; i < opened_windows_count; i++) {
        if (opened_windows[i] != None &&
            opened_windows[i] != active_window) {
          opened_window_process = get_window_process(display, opened_windows[i]);
          // Do not print info about window if XRes returned zero PID
          if (opened_window_process != 0) {
            printf("%ld=%d ", opened_windows[i], opened_window_process);
          }
        } else if (opened_windows[i] == active_window) {
          printf("%ld=%d ", active_window, active_window_process);
        }
      }

      // Get and print window manager info
      opened_window_process = get_window_process(display, wm_window);
      if (wm_window != None) {
        printf("%ld=%d\n", wm_window, opened_window_process);
      } else {
        printf("\n");
      }

      previous_active_window_xor = active_window_xor;
      previous_opened_windows_xor = opened_windows_xor;
      previous_wm_window_xor = wm_window_xor;
    }
  }

  // Unreachable because 'XNextEvent()' locks loop up
  // Handling SIGINT/SIGTERM also impossible because of that
  return 0;
}
