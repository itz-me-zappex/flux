/*
	Written as small replacement for 'xprop -root -spy _NET_ACTIVE_WINDOW _NET_CLIENT_LIST_STACKING' which aims at following:
	1) Obtaining and printing info in specific order unlike 'xprop', which gets events from X11 (those are random ordered) and "throws" them.
	2) Simplifying integration with this daemon or any other project.
	3) Speeding up and reducing CPU usage of daemon by:
		3.1) Obtaining PID of focused window process directly in C++ code instead of calling external binary.
		3.2) Solving issue with repeating events completely, because event reader checks for atoms being changed, not events passed by X server.
		3.3) Taking away need to check events in daemon calling 'xprop' tool again to get state "dump" of current '_NET_ACTIVE_WINDOW' and '_NET_CLIENT_LIST_STACKING' atoms.
	4) Obtaining PID using XRes extension instead of relying on '_NET_WM_PID' atom because:
		4.1) It is not accessible in some windows.
		4.2) Reports wrong PID when app runs in sandbox with PID namespaces (e.g. Firejail)
		4.3) It may lie, because this atom is set by app itself.

	Always prints two events every time '_NET_ACTIVE_WINDOW' and '_NET_CLIENT_LIST_STACKING' properties change (in hardcoded order):
	1) Info about focused window in '<WID>=<PID>' format.
	2) List with info about opened windows in '<WID>=<PID>' format.
*/

#include <iostream>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/extensions/XRes.h>
#include <sstream>
#include <chrono>
#include <thread>

using namespace std;

// Obtain active window ID
void get_active_window(Display *display, Window root, Window &active_window_id){
	// Contains focused window ID
	Atom net_active_window = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
	// Store info here
	unsigned char *data = nullptr;
	unsigned long windows_count, bytes_after;
	Atom type;
	int format;
	// Get active window
	XGetWindowProperty(display, root, net_active_window, 0, ~0, False, XA_WINDOW, &type, &format, &windows_count, &bytes_after, &data);
	// Pass window ID outside
	active_window_id = *(Window *)data;
	XFree(data);
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
void get_opened_windows(Display *display, Window root, string &opened_window_ids_str){
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
	opened_window_ids_str = local_opened_windows.str();
	XFree(data);
}

// Check for WM restart
bool check_wm_restart(Display* display, Window root, Window &previous_owner){
	// Get "WM_S0" atom
	Atom wm_s0 = XInternAtom(display, "WM_S0", False);
	// Get "WM_S0" owner
	Window owner = XGetSelectionOwner(display, wm_s0);
	// Return 'true' if owner has been changed as that means WM restart
	bool restarted = (previous_owner != None && owner != previous_owner);
	// Remember owner to compare it next time
	previous_owner = owner;
	// True or false
	return restarted;
}

// Simplify sleeping
void sleep(int ms){
	this_thread::sleep_for(chrono::milliseconds(ms));
}

// Listen and handle events
int main(){
	// Current and previous window ID
	Window active_window_id;
	Window previous_active_window_id;
	// Window process PID
	pid_t process_pid;
	// Current and previous opened window IDs list
	string opened_window_ids_str;
	string previous_opened_window_ids_str;
	// Single opened window ID
	Window opened_window_id;
	string opened_window_id_str;
	// Remember last owner of window to detect WM restart
	Window previous_owner = None;
	// Needed to simulate event to obtain and print atoms state immediately after start
	bool fake_first_event = true;
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
		if (!fake_first_event){
			XNextEvent(display, &event);
		}
		// Wait for property to change
		if (fake_first_event || event.type == PropertyNotify){
			// Unset trigger
			if (fake_first_event){
				fake_first_event = false;
			}
			// Get active window ID
			get_active_window(display, root, active_window_id);
			// Skip event if focused window has '0x0' ID
			if (active_window_id == 0){
				continue;
			}
			// Skip events if WM has been restarted
			if (check_wm_restart(display, root, previous_owner) || active_window_id == 1){
				sleep(1000);
				continue;
			}
			// Get list of opened windows
			get_opened_windows(display, root, opened_window_ids_str);
			// Continue only if at least one atom has been changed and that is not '0x0' focused window ID
			if (previous_active_window_id != active_window_id || previous_opened_window_ids_str != opened_window_ids_str){
				// Get active window process PID
				get_process_pid(display, active_window_id, process_pid);
				// Print info about focused window in '<WID>=<PID>' format
				cout << "0x" << hex << active_window_id << dec << "=" << process_pid << endl;
				// Print info about opened windows in '<WID>=<PID>' format on single line
				istringstream opened_window_ids_stream(opened_window_ids_str);
				while (opened_window_ids_stream >> opened_window_id_str){
					// Convert string into acceptable for 'Window' format
					stringstream opened_window_id_stream(opened_window_id_str);
					opened_window_id_stream >> hex >> opened_window_id;
					// Get PID using window ID
					get_process_pid(display, opened_window_id, process_pid);
					// Print info about window
					cout << "0x" << hex << opened_window_id << dec << "=" << process_pid << " ";
				}
				cout << endl;
				// Remember current atoms state to compare those on next event
				previous_active_window_id = active_window_id;
				previous_opened_window_ids_str = opened_window_ids_str;
			}
		}
	}
	// Exit safely
	XCloseDisplay(display);
	return 0;
}