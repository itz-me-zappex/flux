#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/extensions/XRes.h>

// Get window ID using '_NET_ACTIVE_WINDOW' atom
Window get_active_window(Display* display, Window root, Atom atom) {
	Window active_window;
	Atom type;
	unsigned char *data = NULL;
	unsigned long windows_count, bytes_after;
	int format;

	int status = XGetWindowProperty(display, root, atom, 0, 1, False, XA_WINDOW, &type, &format, &windows_count, &bytes_after, &data);

	if (status == Success && data != NULL) {
		active_window = *(Window *)data;
	} else {
		active_window = None;
	}

	XFree(data);

	return active_window;
}

// Fallback, get window ID from X server if '_NET_ACTIVE_WINDOW' is zero
Window get_input_focus(Display* display) {
	int revert;
	Window active_window;

	XGetInputFocus(display, &active_window, &revert);

	return active_window;
}

// Check difference between previous and current 'WM_S0' atom to detect WM restart
bool check_wm_restart(Display* display, Window root, Atom atom) {
	static Window previous_owner = None;

	Window owner = XGetSelectionOwner(display, atom);

	bool wm_restart = (previous_owner != None && owner != previous_owner);
	previous_owner = owner;

	return wm_restart;
}

// Get process of window using XRes extension ('_NET_WM_PID' is unreliable)
pid_t get_window_process(Display* display, Window window_id) {
	pid_t window_process;
	XResClientIdSpec client_spec;
	client_spec.client = window_id;
	client_spec.mask = XRES_CLIENT_ID_PID_MASK;
	long elements;
	XResClientIdValue *client_ids = NULL;

	int status = XResQueryClientIds(display, 1, &client_spec, &elements, &client_ids);

	if (status == Success) {
		for (long i = 0; i < elements; i++) {
			if (window_id > 0) {
				window_process = XResGetClientPid(&client_ids[i]);
				break;
			}
		}
	} else {
		window_process = -1;
	}

	XResClientIdsDestroy(elements, client_ids);

	return window_process;
}

// Get window manager WID using '_NET_SUPPORTING_WM_CHECK' atom, needed to include it to list of opened windows and skip event if 'XGetInputFocus()' returns smth else instead of WM WID
Window get_wm_window(Display* display, Window root, Atom atom) {
	Window wm_window;
	Atom type;
	unsigned char *data = NULL;
	unsigned long windows_count, bytes_after;
	int format;

	int status = XGetWindowProperty(display, root, atom, 0, 1, False, XA_WINDOW, &type, &format, &windows_count, &bytes_after, &data);

	if (status == Success && data != NULL) {
		wm_window = *(Window *)data;
	} else {
		wm_window = None;
	}

	XFree(data);

	return wm_window;
}

// Get list of opened window IDs using '_NET_CLIENT_LIST_STACKING' atom
Window* get_opened_windows(Display* display, Window root, unsigned long *opened_windows_count, Atom atom) {
	Atom type;
	unsigned char *data = NULL;
	unsigned long windows_count, bytes_after;
	int format;

	int status = XGetWindowProperty(display, root, atom, 0, ~0, False, XA_WINDOW, &type, &format, &windows_count, &bytes_after, &data);

	if (status != Success) {
		*opened_windows_count = 0;
		return NULL;
	}
	*opened_windows_count = windows_count;
	return (Window *)data;
}

// Daemon
int main() {
	// Enforce per-line buffer to make output readable from command substitution in Bash
	setlinebuf(stdout);

	// Store obtained data here
	Window active_window;
	pid_t active_window_process;
	pid_t opened_window_process;
	Window wm_window;
	Window *opened_windows = NULL;
	unsigned long opened_windows_count;

	// Bitwise "eXclusive OR" difference between current and previous atom states
	unsigned long active_window_xor, opened_windows_xor, wm_window_xor;
	unsigned long previous_active_window_xor, previous_opened_windows_xor, previous_wm_window_xor;

	// Attempt to open display
	Display *display = XOpenDisplay(NULL);
	if (!display) {
		return 1;
	}

	// Get atom IDs
	Atom net_active_window = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
	Atom wm_s0 = XInternAtom(display, "WM_S0", False);
	Atom net_supporting_wm_check = XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", False);
	Atom net_client_list_stacking = XInternAtom(display, "_NET_CLIENT_LIST_STACKING", False);

	// Get root window
	Window root = DefaultRootWindow(display);

	// Exit with an error if window manager is not running
	if (get_wm_window(display, root, net_supporting_wm_check) == None) {
		return 1;
	}

	// Listen changes in atoms
	XSelectInput(display, root, PropertyChangeMask);
	XEvent event;

	// Simulate event to handle current atoms state immediately
	bool fake_event = true;

	// Mark needed to remember and handle WM restart
	bool wm_restart_mark = false;

	// Handle changes in atom states
	while (true) {
		// Do not wait for event if there is fake one
		if (!fake_event) {
			XNextEvent(display, &event);
			// Handle only needed events
			if (event.type != PropertyNotify && event.xproperty.atom != net_active_window && event.xproperty.atom != net_client_list_stacking) {
				continue;
			}
		} else if (fake_event) {
			fake_event = false;
		}

		// Do not check 'WM_S0' if WM restart has been detected
		if (!wm_restart_mark) {
			// Set mark and skip loop if WM has been restarted
			if (check_wm_restart(display, root, wm_s0)) {
				wm_restart_mark = true;
				continue;
			}
		}

		// Unset bits as I need new value instead of increasing it
		active_window_xor = 0;
		opened_windows_xor = 0;
		wm_window_xor = 0;

		// Get list of opened windows from '_NET_CLIENT_LIST_STACKING'
		XFree(opened_windows);
		opened_windows = get_opened_windows(display, root, &opened_windows_count, net_client_list_stacking);
		for (unsigned long i = 0; i < opened_windows_count; i++) {
			opened_windows_xor ^= opened_windows[i];
		}

		// Check for WM restart
		if (wm_restart_mark) {
			// Skip loops until '_NET_CLIENT_LIST_STACKING' become adequate
			if (opened_windows_xor != previous_opened_windows_xor) {
				continue;
			} else {
				// Unset mark and handle this event
				wm_restart_mark = false;
			}
		}

		// Get window ID from '_NET_ACTIVE_WINDOW'
		active_window = get_active_window(display, root, net_active_window);
		// Get window manager WID from '_NET_SUPPORTING_WM_CHECK'
		wm_window = get_wm_window(display, root, net_supporting_wm_check);
		// Fallback
		if (active_window == None) {
			// Use 'XGetInputFocus()' if '_NET_ACTIVE_WINDOW' is zero
			active_window = get_input_focus(display);
			// Skip loop if 'XGetInputFocus()' did not return window manager WID
			if (active_window != wm_window) {
				continue;
			}
		}
		// Used to check difference between previous and current states
		active_window_xor ^= active_window;
		wm_window_xor ^= wm_window;

		// Print atom states if at least one has been changed
		if (active_window_xor != previous_active_window_xor || opened_windows_xor != previous_opened_windows_xor || wm_window_xor != previous_wm_window_xor) {
			active_window_process = get_window_process(display, active_window);
			printf("0x%lx=%d\n", active_window, active_window_process);

			for (unsigned long i = 0; i < opened_windows_count; i++) {
				if (opened_windows[i] != None) {
					opened_window_process = get_window_process(display, opened_windows[i]);
					printf("0x%lx=%d ", opened_windows[i], opened_window_process);
				}
			}

			opened_window_process = get_window_process(display, wm_window);
			if (wm_window != None) {
				printf("0x%lx=%d\n", wm_window, opened_window_process);
			} else {
				printf("\n");
			}

			previous_active_window_xor = active_window_xor;
			previous_opened_windows_xor = opened_windows_xor;
			previous_wm_window_xor = wm_window_xor;
		}
	}

	// Unreachable due to 'XNextEvent()' locks loop up
	// Handling SIGINT/SIGTERM also impossible because of that
	return 0;
}