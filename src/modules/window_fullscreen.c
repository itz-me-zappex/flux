#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

#include "functions/get_opened_windows.h"

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

  Atom net_client_list_stacking = XInternAtom(display, "_NET_CLIENT_LIST_STACKING", False);

  unsigned long opened_windows_count;
  Window *opened_windows = get_opened_windows(display, root, &opened_windows_count, net_client_list_stacking);

  if (!opened_windows) {
    XCloseDisplay(display);
    return 1;
  }

  bool window_exists = false;

  for (unsigned long i = 0; i < opened_windows_count; i++) {
    if (opened_windows[i] == window) {
      window_exists = true;
      break;
    }
  }

  XFree(opened_windows);

  if (!window_exists) {
    XCloseDisplay(display);
    return 1;
  }

  Atom net_wm_state = XInternAtom(display, "_NET_WM_STATE", False);
  Atom net_wm_state_fullscreen = XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", False);

  if (net_wm_state == None || net_wm_state_fullscreen == None) {
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
	XFlush(display);

  Window parent;
  Window *child;
  unsigned int child_count;

  if (XQueryTree(display, window, &root, &parent, &child, &child_count)) {
    if (child_count > 0) {
      Window selected_child = child[0];
      int x, y;
      unsigned int child_width, child_height, child_border_width, child_depth;

      if (XGetGeometry(display, selected_child, &root, &x, &y, &child_width, &child_height, &child_border_width, &child_depth)) {
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

        if (screen_width != child_width || screen_height != child_height) {
          // 100ms delay needed because some games will not be resized without it
          usleep(100000);

          XResizeWindow(display, selected_child, screen_width, screen_height);
          XFlush(display);
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
