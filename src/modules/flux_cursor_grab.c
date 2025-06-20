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

/* Ugly layer between focused window and mouse
 * XGrabPointer() grabs cursor cutting input off window, but that is only one adequate way to prevent cursor from escaping window
 * Because of that, all obtained mouse events here are redirected to window
 */
int main(int argc, char *argv[]) {
  if (argc != 2) {
    return 1;
  }

  XInitThreads();

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

  pid_t window_process = get_window_process(display, window);
  if (window_process == 0) {
    XCloseDisplay(display);
    return 1;
  } else {
    XUngrabPointer(display, CurrentTime);
  }

  // Wait a bit to prevent failure in case window gets focus with mouse click
  usleep(100000);

  // Attempt to grab cursor as that is daemonized process and I don't want hook another Bash instance for it to check exit code (which I won't get ever if no error occur)
  int grab_status = XGrabPointer(display, window, True, ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
                                 GrabModeAsync, GrabModeAsync, window, None, CurrentTime);
  if (grab_status != GrabSuccess) {
    XCloseDisplay(display);
    return 1;
  }

  /* Handle Wine/Proton games/apps in complicated way to prevent freezing on init because of grabbed cursor
   * That is an issue only when game starts loading for the first time, Wine/Proton waits for mouse cursor and freezes a whole process
   */
  bool wine_window = is_wine_window(display, window);
  if (wine_window) {
    // Check whether process hangs after cursor grab or not
    bool process_cpu_idle;
    while (true) {
      // Attempt to grab cursor
      grab_status = XGrabPointer(display, window, True, ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
                                 GrabModeAsync, GrabModeAsync, window, None, CurrentTime);
      if (grab_status != GrabSuccess) {
        XCloseDisplay(display);
        return 1;
      } else {
        XSync(display, False);
      }

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
    // Just grab cursor and go below
    grab_status = XGrabPointer(display, window, True, ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
                               GrabModeAsync, GrabModeAsync, window, None, CurrentTime);

    if (grab_status != GrabSuccess) {
      XCloseDisplay(display);
      return 1;
    }
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
