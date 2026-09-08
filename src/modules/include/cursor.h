#ifndef CURSOR_H
#define CURSOR_H

#include <unistd.h>
#include <pthread.h>
#include <X11/Xlib.h>
#include <stdbool.h>

typedef struct {
  Display* display;
  Window window;
  volatile bool stop;
} forward_input_on_hang_wait_args;

extern long int cursor_event_masks[];

void* forward_input_on_hang_wait(void *arg);

void wait_for_cursor_ungrab(Display* display, Window window);

#endif
