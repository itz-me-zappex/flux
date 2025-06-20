#ifndef FORWARD_INPUT_ON_HANG_WAIT_H
#define FORWARD_INPUT_ON_HANG_WAIT_H

#include <unistd.h>
#include <pthread.h>
#include <X11/Xlib.h>
#include <stdbool.h>

/* Inefficient and consumes a lot of CPU time
 * Needed to make window accept mouse input only for when waiting for Wine/Proton process to hang after cursor grab (workaround to pass init step)
 * Because process may not hang at all if already initialized and it will ignore mouse input without this crutch
 */

typedef struct {
  Display* display;
  Window window;
  volatile bool stop;
} forward_input_on_hang_wait_args;

void* forward_input_on_hang_wait(void *arg) {
  forward_input_on_hang_wait_args* args = (forward_input_on_hang_wait_args *)arg;

  XEvent event;
  while (!args->stop) {
    while (XPending(args->display)) {
      XMaskEvent(args->display, ButtonPressMask | ButtonReleaseMask | PointerMotionMask, &event);
      XSendEvent(args->display, args->window, True, NoEventMask, &event);
    }
    usleep(500);
  }

  return NULL;
}

#endif
