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

// Wait for cursor ungrab to grab it successfully
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

/* Ugly layer between focused window and mouse
 * XGrabPointer() grabs cursor cutting input off window, but that is only one adequate way to prevent cursor from escaping window
 * Because of that, all obtained mouse events here are redirected to window
 */
int main(int argc, char *argv[]) {
  // Use line buffer to make output readable from command substitution in Bash
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
  } else {
    XUngrabPointer(display, CurrentTime);
  }

  // Attempt to grab cursor
  int grab_status = XGrabPointer(display, window, True, ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
                                 GrabModeAsync, GrabModeAsync, window, None, CurrentTime);
  if (grab_status != GrabSuccess) {
    printf("cursor_already_grabbed\n");
    wait_for_cursor_ungrab(display, window);
  }

  /* Handle Wine/Proton games/apps in complicated way to prevent freezing on init because of grabbed cursor
   * That is an issue only when game starts loading for the first time, Wine/Proton waits for mouse cursor and freezes a whole process
   */
  bool wine_window = is_wine_window(display, window);
  if (wine_window) {
    printf("wine_window\n");
    // Check whether process hangs after cursor grab or not
    bool process_cpu_idle;
    while (true) {
      wait_for_cursor_ungrab(display, window);

      // Run thread which will pass mouse input during 100ms until next loop or window passed init and I will be able redirect input eventually
      forward_input_on_hang_wait_args forward_input_on_hang_wait_t_args = {
        .display = display,
        .window = window,
        .stop = false,
      };
      pthread_t forward_input_on_hang_wait_t;
      pthread_create(&forward_input_on_hang_wait_t, NULL, forward_input_on_hang_wait, &forward_input_on_hang_wait_t_args);

      // Process may not hang immediately after cursor grabbing, without this delay some games will hang because cursor will not be ungrabbed
      for (int i = 0; i < 50; i++) {
        usleep(100000);
        process_cpu_idle = is_process_cpu_idle(window_process);
        // If there is a hang, then stop check and ungrab cursor to unfreeze it as fast as possible
        if (process_cpu_idle) {
          break;
        }
      }

      // No longer needed
      forward_input_on_hang_wait_t_args.stop = true;
      pthread_join(forward_input_on_hang_wait_t, NULL);

      // If process hangs after grab, then ungrab cursor and repeat the same until it stop hang (e.g. after loading or Wine/Proton initialization)
      if (process_cpu_idle) {
        XUngrabPointer(display, CurrentTime);
        // Without it cursor will not be really ungrabbed and this loop will not break
        XSync(display, False);
        sleep(1);
      } else {
        break;
      }
    }
  } else {
    printf("window\n");
    wait_for_cursor_ungrab(display, window);
  }

  // Send mouse related events to window in realtime
  printf("success\n");
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
