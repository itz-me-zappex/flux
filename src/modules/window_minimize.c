#include <stdlib.h>
#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>

#include "functions/get_opened_windows.h"
#include "functions/check_window_existence.h"

/* Minimize window if passed window XID is valid */
int main(int argc, char *argv[]) {
  if (argc != 2) {
    return 1;
  }

  Display *display = XOpenDisplay(NULL);

  if (!display) {
    return 1;
  }

  Window root = DefaultRootWindow(display);
  Window window = strtoul(argv[1], NULL, 0);

  bool window_exists = check_window_existence(display, root, window);
  if (window_exists) {
    XIconifyWindow(display, window, DefaultScreen(display));
    XFlush(display);
  }

  XCloseDisplay(display);

  if (window_exists) {
    return 0;
  } else {
    return 1;
  }
}
