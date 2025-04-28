#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <X11/cursorfont.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/extensions/XRes.h>
#include <X11/Xos.h>
#include <X11/Xutil.h>
#include <stdarg.h>

#include "functions/get_active_window.h"
#include "functions/get_wm_window.h"
#include "functions/get_window_process.h"
#include "functions/get_opened_windows.h"
#include "functions/check_window_existence.h"

#include "functions/third-party/xprop/clientwin.h"
#include "functions/third-party/xprop/dsimple.h"

// To avoid compilation breakage, used in 'xprop' source code
void usage(const char *errmsg) {}

// Use picker to select window or get focused one depending by cmdline argument and print its XID with PID
// Exit codes here are wrapped in 'flux' to print proper error messages when executing this binary
int main(int argc, char *argv[]) {
  if (argc != 2) {
    return 1;
  }

  char *argument = argv[1];

  bool should_pick;

  if (strcmp(argument, "pick") == 0) {
    should_pick = true;
  } else if (strcmp(argument, "focus") == 0) {
    should_pick = false;
  } else {
    return 1;
  }

  Display *display = XOpenDisplay(NULL);

  if (!display) {
    return 2;
  }

  Window root = DefaultRootWindow(display);
  Window wm_window = get_wm_window(display, root);

  if (wm_window == None) {
    XCloseDisplay(display);
    return 3;
  }

  Window window;

  if (should_pick) {
    // Attempt to grab mouse to avoid error from third-party 'Select_Window()'
    int grab_status = XGrabPointer(display, root, True,
        ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
        GrabModeAsync, GrabModeAsync,
        None, None, CurrentTime);
    if (grab_status != GrabSuccess) {
      XCloseDisplay(display);
      return 4;
    }
    XUngrabPointer(display, CurrentTime);

    window = Select_Window(display, 1);
  } else {
    window = get_active_window(display, root);
  }

  if (window == root ||
      window == None) {
    window = wm_window;
  } else {
    bool window_exists = check_window_existence(display, root, window);

    if (!window_exists &&
        window != wm_window) {
      XCloseDisplay(display);
      return 5;
    }
  }

  pid_t window_process = get_window_process(display, window);

  if (window_process != 0) {
    printf("%ld=%d\n", window, window_process);
  } else {
    XCloseDisplay(display);
    return 6;
  }

  XCloseDisplay(display);
  return 0;
}
