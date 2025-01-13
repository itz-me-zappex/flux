/*
	Written as small replacement for 'xprop -root -spy _NET_ACTIVE_WINDOW _NET_CLIENT_LIST_STACKING' which aims at following:
	1) Obtaining and printing info in specific order unlike 'xprop', which gets events from X11 (those are random ordered) and "throws" them.
	2) Simplifying integration with this daemon or any other project.
	3) Speeding up and reducing CPU usage of daemon by:
		3.1) Obtaining PID of focused window process directly in C++ code instead of calling external binary.
		3.2) Solving issue with repeating events completely, because listener checks for actual events being changed, not passed by X server ones.
		3.3) Taking away need to check events in daemon calling 'xprop' tool again to get state "dump" of current '_NET_ACTIVE_WINDOW' and '_NET_CLIENT_LIST_STACKING' atoms.
	4) Obtaining PID using XRes extension instead of relying on '_NET_WM_PID' atom because:
		4.1) It is not accessible in some windows.
		4.2) Reports wrong PID when app runs in sandbox with PID namespaces (e.g. Firejail)
		4.3) It may lie from time to time, because it is set by app manually.

	Always prints three events every time '_NET_ACTIVE_WINDOW' and '_NET_CLIENT_LIST_STACKING' properties change (in hardcoded order):
	1) Info about focused window in '<WID>=<PID>' format.
	2) List with info about opened windows in '<WID>=<PID>' format.
*/

#include <iostream>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/extensions/XRes.h>
#include <sstream>

using namespace std;

// Obtain active window ID
void get_active_window(Display *display, Window root, Window &active_window_id){
	int revert;
	XGetInputFocus(display, &active_window_id, &revert);
}

// Obtain window process PID
void get_process_pid(Display *display, Window window_id, pid_t &process_pid){
	// Ask for PID only
	XResClientIdSpec client_spec;
	client_spec.client = window_id;
	client_spec.mask = XRES_CLIENT_ID_PID_MASK;
	// Store IDs count here, expected to have 'long' type
	long ids_count;
	// Blank pointer is expected
	XResClientIdValue *client_ids = nullptr;
	// Query client list
	XResQueryClientIds(display, 1, &client_spec, &ids_count, &client_ids);
	// Go through all PIDs and break loop if non-zero value appears
	for (long i = 0; i < ids_count; i++){
		process_pid = XResGetClientPid(&client_ids[i]);
		if (window_id > 0){
			break;
		}
	}
}

// Get list of opened window from '_NET_CLIENT_LIST_STACKING' atom
void get_opened_windows(Display *display, Window root, string &opened_window_ids){
	// Contains list of opened windows
	Atom net_client_list_stacking = XInternAtom(display, "_NET_CLIENT_LIST_STACKING", False);
	// Store info here
	unsigned char *data = nullptr;
	unsigned long windows_count, bytes_after;
	Atom type;
	int format;
	// Get list of opened windows
	XGetWindowProperty(display, root, net_client_list_stacking, 0, ~0, False, XA_WINDOW, &type, &format, &windows_count, &bytes_after, &data);
	// Convert to array
	Window *windows = (Window *)data;
	// Convert to string
	stringstream local_opened_windows;
	for (unsigned long i = 0; i < windows_count; i++){
		local_opened_windows << "0x" << hex << windows[i] << dec;
		// Add space if not last
		if (i < windows_count - 1){
			local_opened_windows << " ";
		}
	}
	opened_window_ids = local_opened_windows.str();
	XFree(data);
}

// Listen and handle events
int main(){
	// Current and previous window ID
	Window active_window_id;
	Window previous_active_window_id;
	// Window process PID
	pid_t process_pid;
	// Current and previous opened window IDs list
	string opened_window_ids;
	string previous_opened_window_ids;
	// Single opened window ID
	Window opened_window_id;
	// Connect to X server
	Display *display = XOpenDisplay(nullptr);
	if (!display){
		return 1;
	}
	// Get root window
	Window root = DefaultRootWindow(display);
	// Listen '_NET_ACTIVE_WINDOW' and '_NET_CLIENT_LIST_STACKING' atoms infinitely (until SIGTERM/SIGINT of course)
	Atom net_active_window = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
	Atom net_client_list_stacking = XInternAtom(display, "_NET_CLIENT_LIST_STACKING", False);
	XSelectInput(display, root, PropertyChangeMask);
	// Store events here
	XEvent event;
	// Handle events
	while (true){
		// Get event
		XNextEvent(display, &event);
		// Wait for property to change
		if (event.type == PropertyNotify){
			// Get active window ID
			get_active_window(display, root, active_window_id);
			// Get list of opened windows
			get_opened_windows(display, root, opened_window_ids);
			// Continue only if at least one atom has been changed
			if (previous_active_window_id != active_window_id || previous_opened_window_ids != opened_window_ids){
				// Get active window process PID
				get_process_pid(display, active_window_id, process_pid);
				// Print info about focused window in '<WID>=<PID>' format
				cout << "0x" << hex << active_window_id << dec << "=" << process_pid << endl;
				// Print info about opened windows in '<WID>=<PID>' format on single line
				istringstream opened_window_ids_stream(opened_window_ids);
				string opened_window_id_str;
				while (opened_window_ids_stream >> opened_window_id_str){
					// Convert string into acceptable for 'Window' format
					stringstream opened_window_id_stream(opened_window_id_str);
					opened_window_id_stream >> hex >> opened_window_id;
					// Get PID using window ID and print info about window
					get_process_pid(display, opened_window_id, process_pid);
					cout << "0x" << hex << opened_window_id << dec << "=" << process_pid << " ";
				}
				cout << endl;
				// Remember current atoms state to compare those on next event
				previous_active_window_id = active_window_id;
				previous_opened_window_ids = opened_window_ids;
			}
		}
	}
	// Exit safely
	XCloseDisplay(display);
	return 0;
}