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
- [Tips and tricks](#tips-and-tricks)
  - [Keybinding to obtain template from focused window for config](#keybinding-to-obtain-template-from-focused-window-for-config)
  - [Apply changes in config file](#apply-changes-in-config-file)
  - [Improve performance of daemon](#improve-performance-of-daemon)
  - [Types of limits and which you should use](#types-of-limits-and-which-you-should-use)
- [Possible questions](#possible-questions)
  - [How does daemon work?](#how-does-daemon-work)
  - [Should I trust you and this utility?](#should-i-trust-you-and-this-utility)
  - [Which DE or WM should I use for best compatibility?](#which-de-or-wm-should-i-use-for-best-compatibility)
  - [Does it increase input lag and/or record my screen to detect window focus/unfocus events?](#does-it-increase-input-lag-andor-record-my-screen-to-detect-window-focusunfocus-events)
  - [Is it safe?](#is-it-safe)
  - [Is not running commands on focus and unfocus makes system vulnerable?](#is-not-running-commands-on-focus-and-unfocus-makes-system-vulnerable)
  - [Can I get banned in a game because of this daemon?](#can-i-get-banned-in-a-game-because-of-this-daemon)
  - [Why was that daemon developed?](#why-was-that-daemon-developed)
  - [Bugs?](#bugs)
  - [Why is code so complicated?](#why-is-code-so-complicated)
  - [Can I apply FPS-limits instead of CPU-limits?](#can-i-apply-fps-limits-instead-of-cpu-limits)
  - [Gamescope exists, Wayland becomes more popular. Are you not late by any chance?](#gamescope-exists-wayland-becomes-more-popular-are-you-not-late-by-any-chance)
  - [What about Wayland support?](#what-about-wayland-support)
  - [Why did you write it on Bash?](#why-did-you-write-it-on-bash)
  - [Does that daemon reduce performance?](#does-that-daemon-reduce-performance)
 
### Dependencies
- `Arch Linux` branch:

  Required: `bash util-linux procps-ng cpulimit coreutils xorg-xprop xorg-xwininfo`
  
  Optional: `mangohud lib32-mangohud`

- `Debian`/`Ubuntu` branch:
  
  Required: `bash procps cpulimit coreutils x11-utils`

  Optional: `mangohud mangohud:i386`

Dependencies for other distros will be added soon.

### Installation
This daemon was developed with portability in mind, so all code has been placed in one file.
All you need is just download [flux](https://github.com/itz-me-zappex/flux/blob/main/flux) file, make it executable and put in place you want, but preferably put it somewhere in $PATH to avoid calling daemon with directly specified path every time.

There are also PKGBUILDs to build a package for Arch Linux, you can find them in tab with releases.

### Usage
```
Usage: flux [option] <value>
Options and values:
    -c, --changelog                      Display changelog
    -C, --config     <path-to-config>    Specify path to config file
    -f, --focused                        Display template for config from focused window
    -h, --help                           Display this help
    -H, --hot                            Apply actions to already unfocused windows before handling events
    -l, --lazy                           Avoid focus and unfocus commands on hot
    -p, --pick                           Display template for config by picking window
    -q, --quiet                          Display errors and warnings only
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
| `cpu-limit` | CPU-limit between 0 and CPU threads multiplied by 100 (i.e. 2 threads = 200, 8 = 800 etc.), defaults to -1 which means no CPU-limit. |
| `delay` | Delay before applying CPU-limit, preferable to avoid freezing app on exit when windows closes but process still exists if `cpu-limit` equal to `0`, defaults to `0`. |
| `focus` | Command to execute on focus event, command runs via bash and will not be killed on daemon exit, output is hidden for avoid mess in output of daemon. |
| `unfocus` | Command to execute on unfocus event, command runs via bash and will not be killed on daemon exit, output is hidden for avoid mess in output of daemon. |
| `command` | Command of process, gets from `/proc/<PID>/cmdline`, required if neither `name` nor `executable` is specified. |
| `mangohud-config` | Path to MangoHud config, required if you want change FPS-limits and requires `fps-limit`. |
| `fps-limit` | FPS to set on unfocus, required by and requires `mangohud-config`. |
| `fps-unlimit` | FPS to set on focus, requires `fps-limit`, defaults to `0` (i.e. full unlimit). |

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
; Long example using FPS-limit
[Geometry Dash]
name = GeometryDash.ex
executable = /run/media/zappex/Samsung-EVO/Steam/steamapps/common/Proton 9.0 (Beta)/files/bin/wine64-preloader
command = D:\Steam\steamapps\common\Geometry Dash\GeometryDash.exe
owner = 1000
cpu-limit = -1
mangohud-config = /home/zappex/.config/MangoHud/wine-GeometryDash.conf
fps-limit = 5
fps-unlimit = 0
delay = 0
focus = killall picom
unfocus = picom

; Long example using CPU-limit (freezing) with one second delay
[Geometry Dash]
name = GeometryDash.ex
executable = /run/media/zappex/Samsung-EVO/Steam/steamapps/common/Proton 9.0 (Beta)/files/bin/wine64-preloader
command = D:\Steam\steamapps\common\Geometry Dash\GeometryDash.exe
owner = 1000
cpu-limit = 0
mangohud-config = ''
fps-limit = ''
fps-unlimit = ''
delay = 1
focus = killall picom
unfocus = picom

; Short example
[SuperTux]
name = supertux2
cpu-limit = 0
delay = 1

; Do not apply limits, execute commands on events instead
[Mednafen]
name = mednafen
focus = killall picom
unfocus = picom
```

### Variables
Flux does not support environment variables, but passes them to commands in `focus` and `unfocus` keys.

| Variable | Description |
|----------|-------------|
| `FLUX_WINDOW_ID` | ID of focused window |
| `FLUX_PROCESS_PID` | Process PID of focused window |
| `FLUX_PROCESS_NAME` | Process name of focused window |
| `FLUX_PROCESS_EXECUTABLE` | Path to process binary |
| `FLUX_PROCESS_OWNER` | UID of process |
| `FLUX_PROCESS_COMMAND` | Command of process |

Daemon passes absolutely same values for both `focus` and `unfocus` keys.

### Tips and tricks
##### Keybinding to obtain template from focused window for config
- All you need is install `xclip` tool and bind this command: `$ flux --focus | xclip -selection clipboard`.
Now you can easily grab templates from windows to use them in config by pasting content using `Ctrl+v`.

##### Apply changes in config file
- Create shortcut for `$ killall flux ; flux --hot --lazy` command which restarts daemon and use it when you done config file editing.

##### Improve performance of daemon
- Geeks only, casual users should not care about that. To do that, run daemon with `SCHED_BATCH` scheduling policy which is designed to improve performance of non-interactive tasks like daemons, timers, scripts etc.. To do that, use command like `$ chrt --batch 0 flux --hot --lazy`.

##### Types of limits and which you should use
- FPS-limits recommended for online and multiplayer games and if you do not mind to use MangoHud, this method reduces resource consumption when game unfocused/minimized.
- CPU-limits greater than zero recommended for online and multiplayer games in case you do not use MangoHud, but you should be ready to stuttery audio since `cpulimit` tool interrupts process with `SIGSTOP` and `SIGCONT` signals.
- CPU-limit equal to zero recommended for single player games or online games in offline mode, this method freezes game completely to make it just hang in RAM without using any CPU or GPU resources.

### Possible questions
##### How does daemon work?
- Daemon reads X11 events related to window focus, then it gets PID of process using window ID and uses it to collect info about process (process name, its executable path, command which is used and UID) to compare it with identifiers in config, when it finds window which matches with identifier(s) specified in specific section in config, it runs command from `focus` key (if specified), when you switching to another window - applies FPS or CPU-limit (if specified) and runs command from `unfocus` key (if specified). When window does not match with any section in config, nothing happens. To reduce CPU usage and speed up daemon a caching algorithm was implemented which stores info about windows into associative arrays, that allows to just collect info of process once, and then get that info from cache immediately after obtaining its PID when window appears focused again.

##### Should I trust you and this utility?
- You can read entire code. If you are uncomfortable, feel free to avoid using it.

##### Which DE or WM should I use for best compatibility?
- Daemon compatible with all X11 window managers and desktop environments, since it relies on X11 event system.

##### Does it increase input lag and/or record my screen to detect window focus/unfocus events?
- No, all it does is read events from X11 related to window focus.

##### Is it safe?
- Yes, read above. Neither I nor daemon has access to your data.

##### Is not running commands on focus and unfocus makes system vulnerable?
- Just put config file to `/etc/flux.ini` and make it read-only.

##### Can I get banned in a game because of this daemon?
- Nowadays, anti-cheats are pure garbage, developed by freaks without balls, and you can get banned even for a wrong click.

##### Why was that daemon developed?
- Main task is to reduce CPU usage of games that have been minimized. Almost every engine fails to recognize that game is unfocused and continues to consume a lot of CPU and GPU resources, what can make system slow for other tasks like browsing stuff, transcoding video etc. or even unresponsive at all. Imagine users with weak laptop who upgraded their RAM to maximum and suffer from a weak processor, now they can simply play a game and then minimize it if needed without carrying about CPU usage or battery level since process just will hang in RAM. There are a lot of situations and usecases for it.

##### Bugs?
- Nothing is perfect in this world. Almost all bugs I encountered during development have been fixed or will be fixed soon. If you find a bug, open an issue. Known issues that cannot be fixed are:
  - Inability to interact with "glxgears" and "vkcube" windows, as they do not report their PIDs.
  - Freezing online games (setting `cpu-limit` to `0`) causes disconnects from matches, so use less aggressive CPU-limit to allow game to send/receive packets.
  - Stuttery audio in game if CPU-limit is very aggressive, since `cpulimit` tool interrupts process, that should be expected.

##### Why is code so complicated?
- Long story short, try removing at least one line of code (that does not affect output, of course) and see what happens. That sounds easy - just apply a CPU-limit to a window when unfocused and remove it when focused, but that is a bit more complicated. Just check how much logic is used for that "easy" task. Also I used built-in stuff in bash like shell parameter expansions instead of `sed`, loops for reading text line-by-line with regexp in `if` statements instead of `grep` etc. to make code faster, calling external binaries consumes much more time and CPU resources than built-in options.

##### Can I apply FPS-limits instead of CPU-limits?
- Since v1.3 using MangoHud.

##### Gamescope exists, Wayland becomes more popular. Are you not late by any chance?
- Well, not everyone is ready to switch to Wayland, there are a lot of reasons exists. Gamescope does not work well on my Nvidia desktop and Intel laptop, and I can bet it does not work well for others either. Also, there are a lot of old Nvidia GPUs that do not support Wayland at all because of old drivers, what makes Gamescope completely useless for owners of these GPUs.

##### What about Wayland support?
- That is impossible, there is no any unified way to read window focus events and extract PIDs from windows on Wayland.

##### Why did you write it on Bash?
- That is (scripting) language I know pretty good, despite a fact that Bash as all interpretators works slower than compilable languages, it still fits my needs almost perfectly.

##### Does that daemon reduce performance?
- Depends. It uses event-based algorithm to obtain info about windows and processes, when you switching between windows daemon consumes a bit CPU time, but it just chills out when you playing game or working in single window. Long story short, difference in performance and battery life should not be noticeable.
