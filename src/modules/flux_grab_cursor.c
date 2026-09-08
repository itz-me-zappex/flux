#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>

#include "functions/get_opened_windows.h"
#include "functions/check_window_existence.h"
#include "functions/get_window_process.h"
#include "functions/is_wine_window.h"
#include "functions/is_process_cpu_idle.h"
#include "functions/forward_input_on_hang_wait.h"
#include "functions/wait_for_cursor_ungrab.h"

/* Ugly layer between focused window and mouse
 * XGrabPointer() grabs cursor cutting input off window,
 * but that is only one adequate way to prevent cursor
 * from escaping window
 * Because of that, all obtained mouse events here are
 * redirected to specified (focused) window
 */
int main(int argc, char *argv[]) {
  /* To make output readable from command substitution in Bash */
  setlinebuf(stdout);

  if (argc != 2) {
    printf("error\n");
    return 1;
  }

  XInitThreads();

  Display *display = XOpenDisplay(NULL);
  if (!display) {
    printf("error\n");
    return 1;
  }

  Window root = DefaultRootWindow(display);
  Window window = strtoul(argv[1], NULL, 0);

  bool window_exists = check_window_existence(display, root, window);
  if (!window_exists) {
    XCloseDisplay(display);
    printf("error\n");
    return 1;
  }

  pid_t window_process = get_window_process(display, window);
  if (window_process == 0) {
    XCloseDisplay(display);
    printf("error\n");
    return 1;
  }

  /* Attempt to grab cursor */
  int grab_status = XGrabPointer(display, window, True, ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
                                 GrabModeAsync, GrabModeAsync, window, None, CurrentTime);
  if (grab_status != GrabSuccess) {
    printf("cursor_already_grabbed\n");
    wait_for_cursor_ungrab(display, window);
  }

  /* Handle Wine/Proton games/apps in complicated way to prevent
   * freezing on init because of grabbed cursor
   * That is an issue only when game starts for the first time,
   * Wine/Proton expects for mouse cursor being ungrabbed and
   * freezes the whole process
   */
  if (is_wine_window(display, window)) {
    printf("wine_window\n");
    /* Check whether process hangs after cursor grab or not */
    int attempts = 3;
    bool process_cpu_idle = false;
    bool first_loop = true;
    for (int i = 0; i < attempts; i++) {
      /* Cursor is already grabbed
       * No need to wait until it become ungrabbed due to hang
       */
      if (first_loop) {
        first_loop = false;
      } else {
        wait_for_cursor_ungrab(display, window);
      }

      /* Run thread which will pass mouse input during 100ms until next loop
       * or window passed init and I will be able redirect input eventually
       */
      forward_input_on_hang_wait_args forward_input_on_hang_wait_t_args = {
        .display = display,
        .window = window,
        .stop = false,
      };
      pthread_t forward_input_on_hang_wait_t;
      pthread_create(&forward_input_on_hang_wait_t, NULL, forward_input_on_hang_wait, &forward_input_on_hang_wait_t_args);

      /* Process may not hang immediately after cursor grabbing,
       * without this delay, some games will hang because cursor
       * will not be ungrabbed
       */
      for (int j = 0; j < 50; j++) {
        usleep(100000);
        process_cpu_idle = is_process_cpu_idle(window_process);
        /* Stop check and ungrab cursor to unfreeze process if hanged */
        if (process_cpu_idle) {
          break;
        }
      }

      /* No longer needed in this cycle */
      forward_input_on_hang_wait_t_args.stop = true;
      pthread_join(forward_input_on_hang_wait_t, NULL);

      /* Ungrabbing every iteration because of both,
       * if that is last iteration - without ungrabbing
       * cursor will not be confined to window, if not -
       * cursor should be ungrabbed to unfreeze Wine/Proton
       * app.
       */
      XUngrabPointer(display, CurrentTime);
      XSync(display, False);

      if (i == attempts) {
        break;
      }

      if (process_cpu_idle) {
        printf("wine_hang\n");
        sleep(1);
      } else {
        break;
      }
    }
  } else {
    printf("window\n");
  }

  /* Should be (re)grabbed anyway */
  wait_for_cursor_ungrab(display, window);

  long int event_masks[] = {
    ButtonPressMask |
    ButtonReleaseMask |
    ButtonMotionMask |
    PointerMotionMask |
    PointerMotionHintMask
  };

  printf("success\n");

  /* Send mouse related events to window in realtime */
  XEvent event;
  while (true) {
    XMaskEvent(display, *event_masks, &event);
    XSendEvent(display, window, True, NoEventMask, &event);
  }

  /* Unreachable because 'XMaskEvent()' locks loop up
   * Handling SIGINT/SIGTERM also impossible because of that
   */
  XUngrabPointer(display, CurrentTime);
  XCloseDisplay(display);
  return 0;
}
