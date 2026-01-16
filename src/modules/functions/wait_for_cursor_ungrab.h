#ifndef WAIT_FOR_CURSOR_UNGRAB_H
#define WAIT_FOR_CURSOR_UNGRAB_H

#include <unistd.h>
#include <X11/Xlib.h>

/* Wait for cursor ungrab to grab it successfully */
void wait_for_cursor_ungrab(Display* display, Window window) {
  while (true) {
    usleep(250000);
    int grab_status = XGrabPointer(display, window, True, ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
                                   GrabModeAsync, GrabModeAsync, window, None, CurrentTime);
    if (grab_status == GrabSuccess) {
      break;
    }
  }
}

#endif
