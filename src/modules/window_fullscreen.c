#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

#include "functions/get_opened_windows.h"
#include "functions/check_window_existence.h"

// Send X11 event to make window fullscreen and resize its child window to screen size (for games which are kinda buggy in terms of window modes e.g. Forza Horizon 4)
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
  if (!window_exists) {
    XCloseDisplay(display);
    return 1;
  }

  Atom net_wm_state = XInternAtom(display, "_NET_WM_STATE", False);
  Atom net_wm_state_fullscreen = XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", False);
  if (net_wm_state == None ||
      net_wm_state_fullscreen == None) {
    XCloseDisplay(display);
    return 1;
  }

  // Original: https://stackoverflow.com/questions/12706631/x11-change-resolution-and-make-window-fullscreen
  XEvent event = {
    .xclient = {
      .type = ClientMessage,
      .window = window,
      .message_type = net_wm_state,
      .format = 32,
      .data = {
        .l[0] = 1, // Enforce fullscreen mode
        .l[1] = net_wm_state_fullscreen,
        .l[2] = 0, // No property to toggle
        .l[3] = 1,
        .l[4] = 0,
      }
    }
  };

  XSendEvent(display, root, False, SubstructureRedirectMask | SubstructureNotifyMask, &event);

  Window parent;
  Window *childs;
  unsigned int child_count;
  if (XQueryTree(display, window, &root, &parent, &childs, &child_count)) {
    if (child_count > 0) {
      Window child = childs[0];

      XFree(childs);

      int x, y;
      unsigned int child_width, child_height, child_border_width, child_depth;

      if (XGetGeometry(display, child, &root, &x, &y, &child_width, &child_height, &child_border_width, &child_depth)) {
        XWindowAttributes attrs;
        unsigned int screen;

        if (XGetWindowAttributes(display, window, &attrs)) {
          screen = XScreenNumberOfScreen(attrs.screen);
        } else {
          XCloseDisplay(display);
          return 1;
        }

        unsigned int screen_width = XDisplayWidth(display, screen);
        unsigned int screen_height = XDisplayHeight(display, screen);

        if (screen_width != child_width ||
            screen_height != child_height) {
          // 100ms delay needed because some games will not be resized without it
          usleep(100000);

          XResizeWindow(display, child, screen_width, screen_height);
        }
      } else {
        XCloseDisplay(display);
        return 1;
      }
    }
  } else {
    XCloseDisplay(display);
    return 1;
  }

  XCloseDisplay(display);
  return 0;
}
