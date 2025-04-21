#ifndef FORWARD_INPUT_ON_HANG_WAIT_H
#define FORWARD_INPUT_ON_HANG_WAIT_H

#include <unistd.h>
#include <pthread.h>
#include <X11/Xlib.h>
#include <stdbool.h>

void* forward_input_on_hang_wait(void *arg);

#endif
