#include "cursor.h"

/* Inefficient and consumes a lot of CPU time
 * Needed to make window accept mouse input only for when waiting
 * for Wine/Proton process to hang after cursor grab
 * Needed because process may not hang at all if already initialized
 * and without this crutch game will ignore mouse input
 */
void* forward_input_on_hang_wait(void *arg) {
  forward_input_on_hang_wait_args* args = (forward_input_on_hang_wait_args *)arg;

  XEvent event;
  while (!args->stop) {
    while (XPending(args->display)) {
      XMaskEvent(args->display, *cursor_event_masks, &event);
      XSendEvent(args->display, args->window, True, NoEventMask, &event);
    }
    usleep(500); // 0.5ms, busy waiting, otherwise - thread locks
  }

  return NULL;
}

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
