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
  Window active_window, wm_window;
  pid_t active_window_process, opened_window_process;
  Window *opened_windows = NULL;
  unsigned long opened_windows_count, previous_opened_windows_count;

  // Bitwise difference between current and previous atom states
  unsigned long active_window_xor, opened_windows_xor, wm_window_xor;
  unsigned long previous_active_window_xor, previous_opened_windows_xor, previous_wm_window_xor;

  Display *display = XOpenDisplay(NULL);
  if (!display) {
    return 1;
  }

  Window root = DefaultRootWindow(display);

  // Exit with an error if window manager is not running
  wm_window = get_wm_window(display, root);
  if (wm_window == None) {
    XCloseDisplay(display);
    return 1;
  }

  // Get its own PID and append it to '/tmp/flux-lock', needed to make daemon able terminate this process on exit
  const pid_t event_reader_pid = getpid();
  FILE *lock_file = fopen("/tmp/flux-lock", "a");
  if (!lock_file) {
    XCloseDisplay(display);
    return 1;
  } else {
    fprintf(lock_file, "%d", event_reader_pid);
    fclose(lock_file);
  }

  // Simulate event to handle current atoms state immediately
  bool fake_event = true;

  // This is needed to remember and handle WM restart
  bool wm_restart_mark = false;

  // Use line buffer to make output readable from command substitution in Bash
  setlinebuf(stdout);

  Atom net_active_window = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
  Atom net_client_list_stacking = XInternAtom(display, "_NET_CLIENT_LIST_STACKING", False);

  XSelectInput(display, root, PropertyChangeMask);
  XEvent event;

  // Handle changes in atom states
  while (true) {
    if (!fake_event) {
      XNextEvent(display, &event);
      // Skip unneeded events
      if (event.type != PropertyNotify &&
          event.xproperty.atom != net_active_window &&
          event.xproperty.atom != net_client_list_stacking) {
        continue;
      }
    } else if (fake_event) {
      // Do not wait for real event if there is fake one
      fake_event = false;
    }

    // Do not check 'WM_S0' if WM restart has been detected
    if (!wm_restart_mark) {
      // Set mark and skip loop if WM has been restarted
      if (check_wm_restart(display, root)) {
        // Remember opened windows count and skip events until current value equals before restart one
        previous_opened_windows_count = opened_windows_count;

        // Remember that WM has been restarted as this event appears only once
        wm_restart_mark = true;

        continue;
      } else {
        // Wait for 100ms before handle event and unset pending events after delay
        // Needed to filter buggy or unwanted X11 events
        // E.g. changing window mode in game (~100ms delay for some games)
        // Or opening app using command runner in Cinnamon DE or from XFCE4 panel etc. (~25ms delay is fine in this case)
        usleep(100000);
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
    if (opened_windows) {
      XFree(opened_windows);
    }

    opened_windows = get_opened_windows(display, root, &opened_windows_count);

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

    active_window = get_active_window(display, root);
    wm_window = get_wm_window(display, root);

    // Fallback, use 'XGetInputFocus()' if '_NET_ACTIVE_WINDOW' is zero
    if (active_window == None) {
      active_window = get_input_focus(display);

      if (active_window != wm_window) {
        continue;
      }
    }

    active_window_xor ^= active_window;
    wm_window_xor ^= wm_window;
    for (unsigned long i = 0; i < opened_windows_count; i++) {
      opened_windows_xor ^= opened_windows[i];
    }

    // Print atom states if at least one has been changed
    if (active_window_xor != previous_active_window_xor ||
        opened_windows_xor != previous_opened_windows_xor ||
        wm_window_xor != previous_wm_window_xor) {
      active_window_process = get_window_process(display, active_window);      
      if (active_window_process != 0) {
        printf("%ld=%d\n", active_window, active_window_process);
      } else {
        // Skip event if XRes returned zero PID for active window
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
