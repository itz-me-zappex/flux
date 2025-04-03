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
#include "functions/get_input_focus.h"
#include "functions/get_window_process.h"

#include "functions/third-party/xprop/clientwin.h"
#include "functions/third-party/xprop/dsimple.h"

// To avoid compilation breakage, used in 'xprop' source code
void usage(const char *errmsg){}

// Use picker to select window or get focused one depending by cmdline argument and print its XID with PID
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
    return 1;
  }

  Window root = DefaultRootWindow(display);

  Window wm_window, window;

  if (should_pick) {
    window = Select_Window(display, 1);

    if (window == root || window == None) {
      window = get_wm_window(display, root);
    }
  } else {
    window = get_active_window(display, root);

    if (window == None) {
      wm_window = get_wm_window(display, root);

      window = get_input_focus(display);

      if (window != wm_window) {
        XCloseDisplay(display);
        return 1;
      }
    }
  }

  pid_t window_process = get_window_process(display, window);

  if (window_process != 0) {
    printf("%ld=%d\n", window, window_process);
  } else {
    XCloseDisplay(display);
    return 1;
  }

  XCloseDisplay(display);
  return 0;
}
