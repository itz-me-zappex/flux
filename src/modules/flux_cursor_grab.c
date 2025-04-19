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

// Check whether that is Wine/Proton window or not by checking '_WINE_HWND_STYLE' atom existence
bool is_wine_window(Display* display, Window window) {
  Atom wine_hwnd_style = XInternAtom(display, "_WINE_HWND_STYLE", False);
  Atom type;
  unsigned char *data = NULL;
  unsigned long windows_count, bytes_after;
  int format;
  int status = XGetWindowProperty(display, window, wine_hwnd_style, 0, 1, False, XA_CARDINAL,
                                  &type, &format, &windows_count, &bytes_after, &data);
  if (data) {
    XFree(data);
  }
  if (status == Success && type != None) {
    return true;
  }
  return false;
}

// Check whether process sleeps or not using '/proc/PID/status'
bool is_process_cpu_idle(pid_t pid) {
  char path[64];
  snprintf(path, sizeof(path), "/proc/%d/stat", pid);

  unsigned long utime1, stime1;
  unsigned long utime2, stime2;

  FILE *file = fopen(path, "r");
  if (!file) {
    return false;
  }

  char buf[4096];
  if (!fgets(buf, sizeof(buf), file)) {
    fclose(file);
    return false;
  }
  fclose(file);

  char *ptr = strrchr(buf, ')');
  if (!ptr) {
    return false;
  }
  ptr++;

  // Skip PID, comm and state
  int field = 3;
  char *token = strtok(ptr, " ");
  while (token) {
    if (field == 14) {
      utime1 = strtoul(token, NULL, 10);
    } else if (field == 15) {
      stime1 = strtoul(token, NULL, 10);
      break;
    }
    token = strtok(NULL, " ");
    field++;
  }

  // Wait before 2nd check to get difference
  usleep(100000);

  file = fopen(path, "r");
  if (!file) {
    return false;
  }
  if (!fgets(buf, sizeof(buf), file)) {
    fclose(file);
    return false;
  }
  fclose(file);

  ptr = strrchr(buf, ')');
  if (!ptr) {
    return false;
  }
  ptr++;

  field = 3;
  token = strtok(ptr, " ");
  while (token) {
    if (field == 14) {
      utime2 = strtoul(token, NULL, 10);
    } else if (field == 15) {
      stime2 = strtoul(token, NULL, 10);
      break;
    }
    token = strtok(NULL, " ");
    field++;
  }

  // Get difference between 2 checks
  unsigned long delta = (utime2 + stime2) - (utime1 + stime1);
  
  // If nothing changed between two checks or difference is very small, then process hanged
  if (delta <= 3) {
    return true;
  }

  return false;
}

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
      forward_input_on_hang_wait_args FIOHW_args = {
        .display = display,
        .window = window,
        .stop = false,
      };
      pthread_t forward_input_on_hang_wait_t;
      pthread_create(&forward_input_on_hang_wait_t, NULL, forward_input_on_hang_wait, &FIOHW_args);

      // Process may not hang immediately after cursor grabbing, without this delay some games will hang because cursor will not be ungrabbed
      for (int i = 0; i < 5; i++) {
        sleep(1);
        process_cpu_idle = is_process_cpu_idle(window_process);
        // If there is a hang, then stop check and ungrab cursor to unfreeze it as fast as possible
        if (process_cpu_idle) {
          break;
        }
      }

      // No longer needed
      FIOHW_args.stop = true;
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
