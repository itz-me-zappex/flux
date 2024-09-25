## flux
A daemon for X11 designed to automatically limit CPU usage of unfocused windows and run commands on focus and unfocus events.

### Navigation
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Usage](#usage)
  - [Autostart](#autostart)
- [Configuration](#configuration)
  - [Config path](#config-path)
  - [Limitations](#limitations)
  - [Configuration example](#configuration-example)
- [Variables](#variables)
- [Possible questions](#possible-questions)
  - [Should I trust you and this utility?](#should-i-trust-you-and-this-utility)
  - [Is it safe?](#is-it-safe)
  - [Can I get banned in a game because of this daemon?](#can-i-get-banned-in-a-game-because-of-this-daemon)
  - [Why was that daemon developed?](#why-was-that-daemon-developed)
  - [Bugs?](#bugs)
  - [Why is code so complicated?](#why-is-code-so-complicated)
  - [Can I apply FPS-limits instead of CPU-limits?](#can-i-apply-fps-limits-instead-of-cpu-limits)
  - [Gamescope exists, Wayland becomes more popular. Are you not late by any chance?](#gamescope-exists-wayland-becomes-more-popular-are-you-not-late-by-any-chance)
  - [What about Wayland support?](#what-about-wayland-support)


 
### Dependencies
Developed and tested on Arch Linux, all dependencies below related to that and based on distros.
- bash (tested with 5.2.032)
- util-linux (tested with 2.40.2)
  - kill
- procps-ng (tested with 4.0.4)
  - pkill
- cpulimit (tested with 1:0.2)
  - cpulimit
- coreutils (tested with 9.5)
  - nohup
  - readlink
  - sleep (optional, uses 'read -t \<seconds\>' by default)
- xorg-xprop (tested with 1.2.7)
  - xprop
- xorg-xwininfo (tested with 1.1.6)
  - xwininfo

### Installation
This daemon was developed with portability in mind, so all code has been placed in one file.
All you need is just download [flux](https://github.com/itz-me-zappex/flux/blob/main/flux) file, make it executable and put in place you want, but preferably put it somewhere in $PATH to avoid calling daemon with directly specified path every time.

### Usage
```
Usage: flux [option] <value>
Options and values:
    -c, --config     <path-to-config>    Specify path to config file
    -h, --help                           Display this help
    -H, --hot                            Apply actions to already unfocused windows before handling events
    -l, --lazy                           Avoid focus and unfocus commands on hot
    -q, --quiet                          Print errors and warnings only
    -t, --template                       Print template for config by picking window (since v1.2)
    -u, --usage                          Same as '--help'
    -v, --verbose                        Detailed output
    -V, --version                        Display release information
```

#### Autostart
Just add command to autostart using your DE settings or WM config. Running daemon as root also possible, but that feature almost useless.

### Configuration
A simple INI is used for configuration.
Available keys and description:
| Key               | Description |
|-------------------|-------------|
| `name` | Name of process, gets from `/proc/<PID>/comm`, required if neither `executable` nor `command` is specified. |
| `executable` | Path to binary of process, gets by reading `/proc/<PID>/exe` symlink, required if neither `name` nor `command` is specified. |
| `owner` | User ID of process, gets from `/proc/<PID>/status`. |
| `cpulimit` | CPU-limit between 0 and CPU threads multiplied by 100 (i.e. 2 threads = 200, 8 = 800 etc.), defaults to -1 which means no CPU-limit. |
| `delay` | Delay before applying CPU-limit, required for avoid freezing app on exit keeping zombie process or longer exiting than should be, which caused by interrupts from 'cpulimit' subprocess. |
| `focus` | Command to execute on focus event, command runs via bash and won't be killed on daemon exit, output is hidden for avoid mess in output of daemon. |
| `unfocus` | Command to execute on unfocus event, command runs via bash and won't be killed on daemon exit, output is hidden for avoid mess in output of daemon. |
| `command` | Command of process, gets from `/proc/<PID>/cmdline`, required if neither `name` nor `executable` is specified. (since `v1.1`) |

#### Config path
- Daemon searches for following configuration files by priority:
  - `/etc/flux.ini`
  - `$XDG_CONFIG_HOME/flux.ini`
  - `~/.config/flux.ini`

#### Limitations
Since INI is not standartized, I should mention all supported features here.
- Supported:
  - Spaces in section names.
  - Single and double quoted strings.
  - Commented lines and inline comments using `;` and/or `#` symbols.
  - Сase insensitive name of keys.
  - Insensetivity to spaces before and after `=` symbol.
- Unsupported:
  - Regular expressions.
  - Inline comment on lines with section name.
  - Line continuation using `\` symbol.
  - Anything else what unmentioned above.

#### Configuration example
```ini
; Long example
[SuperTux]
name = supertux2
executable = /usr/bin/supertux2
command = /usr/bin/supertux2
owner = 1000
cpulimit = 0
delay = 1
focus = killall picom
unfocus = picom

; Short example
[Geometry Dash]
name = GeometryDash.ex
cpulimit = 0
delay = 1

; Do not apply limits, execute commands on events instead
[Mednafen]
name = mednafen
focus = killall picom
unfocus = picom
```

### Variables
Flux does not support environment variables, but passes them to commands in 'focus' and 'unfocus' keys.

| Variable | Description |
|----------|-------------|
| `FLUX_WINDOW_ID` | ID of focused window |
| `FLUX_PROCESS_PID` | Process PID of focused window |
| `FLUX_PROCESS_NAME` | Process name of focused window |
| `FLUX_PROCESS_EXECUTABLE` | Path to process binary |
| `FLUX_PROCESS_OWNER` | UID of process |
| `FLUX_PROCESS_COMMAND` | Command of process (since `v1.1`) |

Daemon passes absolutely same values for both 'focus' and 'unfocus' keys.

### Possible questions
##### Should I trust you and this utility?
- You can read entire code. If you are uncomfortable, feel free to avoid using it.

##### Is it safe?
- Yes, all daemon does is read events from X11 related to window focus. Neither I nor daemon has access to your data.

##### Can I get banned in a game because of this daemon?
- Nowadays, anti-cheats are pure garbage, developed by freaks without balls, and you can get banned even for a wrong click.

##### Why was that daemon developed?
- Main task is to reduce CPU usage of games that have been minimized. Almost every engine fails to recognize that game is unfocused and continues to consume a lot of CPU and GPU resources, what can make system slow for other tasks like browsing stuff, transcoding video etc. or even unresponsive at all.

##### Bugs?
- Nothing is perfect in this world. Almost all bugs I encountered during development have been fixed or will be fixed soon. If you find a bug, open an issue. Known issues that cannot be fixed are:
  - Inability to interact with "glxgears" and "vkcube" windows, as they do not report their PIDs.
  - Freezing online games (setting 'cpulimit' to '0') causes disconnects from matches, so use less aggressive CPU-limit to allow game to send/receive packets.
  - Stuttery audio in game if CPU-limit is very aggressive, since 'cpulimit' interrupts process, that should be expected.

##### Why is code so complicated?
- Long story short, try removing at least one line of code (that does not affect output, of course) and see what happens. That sounds easy - just apply a CPU-limit to a window when unfocused and remove it when focused, but that is a bit more complicated. Just check how much logic is used for that "easy" task. Also I used built-in stuff in bash like shell parameter expansions instead of 'sed', loops for reading text line-by-line with regexp in 'if' statements instead of 'grep', 'read -t' instead of 'sleep' etc. to make code faster, calling external binaries consumes much more time and CPU resources than built-in options.

##### Can I apply FPS-limits instead of CPU-limits?
- No, at least not directly. You can use MangoHud with game, then add commands to 'focus' and 'unfocus' keys to modify 'fps_limit' option in MangoHud config on fly using 'sed' tool. Since MangoHud reads config on fly, that works like a charm.

##### Gamescope exists, Wayland becomes more popular. Are you not late by any chance?
- Well, not everyone is ready to switch to Wayland, there are a lot of reasons exists. Gamescope does not work well on my Nvidia desktop and Intel laptop, and I can bet it does not work well for others either. Also, there are a lot of old Nvidia GPUs that do not support Wayland at all because of old drivers, what makes Gamescope completely useless for owners of these GPUs.

##### What about Wayland support?
- That is impossible, there is no any unified way to read window focus events and extract PIDs from windows on Wayland.
