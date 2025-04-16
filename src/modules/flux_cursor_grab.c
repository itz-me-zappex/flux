#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>

#include "functions/get_opened_windows.h"
#include "functions/check_window_existence.h"

/* Ugly layer between focused window and mouse
 * XGrabPointer() grabs cursor cutting input off window, but that is only one adequate way to prevent cursor from escaping window
 * Because of that, all obtained mouse events here are redirected to window
 */
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

  // Wait for 500ms in case window still did not appear
  usleep(500000);

  int grab_status = XGrabPointer(display, window, True, ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
                                 GrabModeAsync, GrabModeAsync, window, None, CurrentTime);

  if (grab_status != GrabSuccess) {
    XCloseDisplay(display);
    return 1;
  }

  // Send mouse related events to window in realtime
  XEvent event;
  while (true) {
    XMaskEvent(display, ButtonPressMask | ButtonReleaseMask | PointerMotionMask, &event);
    XSendEvent(display, window, True, NoEventMask, &event);
  }

  // Unreachable because 'XMaskEvent()' locks loop up
  // Handling SIGINT/SIGTERM also impossible because of that
  XUngrabPointer(display, CurrentTime);
  XCloseDisplay(display);
  return 0;
}
