## flux
A daemon for X11 designed to automatically limit FPS or CPU usage of unfocused windows and run commands on focus and unfocus events.

## Navigation
- [Dependencies](#dependencies)
  - [Arch Linux and dereatives](#arch-linux-and-dereatives)
  - [Debian and dereatives](#debian-and-dereatives)
  - [Void Linux and dereatives](#void-linux-and-dereatives)
  - [Fedora and dereatives](#fedora-and-dereatives)
  - [OpenSUSE Tumbleweed and dereatives](#opensuse-tumbleweed-and-dereatives)
  - [Gentoo and dereatives](#gentoo-and-dereatives)
- [Installation](#installation)
  - [Manual installation using release tarball](#manual-installation-using-release-tarball)
  - [Arch Linux and dereatives](#arch-linux-and-dereatives-1)
  - [Debian and dereatives](#debian-and-dereatives-1)
- [Usage](#usage)
  - [List of available options](#list-of-available-options)
  - [Autostart](#autostart)
- [Configuration](#configuration)
  - [Available keys and description](#available-keys-and-description)
  - [Config path](#config-path)
  - [Limitations](#limitations)
  - [Configuration example](#configuration-example)
    - [Long examples](#long-examples)
    - [Short examples](#short-examples)
  - [Environment variables passed to commands](#environment-variables-passed-to-commands)
    - [List of variables passed to `exec-focus` and `lazy-exec-focus` config keys and description](#list-of-variables-passed-to-exec-focus-and-lazy-exec-focus-config-keys-and-description)
    - [List of variables passed to `exec-unfocus` and `lazy-exec-unfocus` config keys and description](#list-of-variables-passed-to-exec-unfocus-and-lazy-exec-unfocus-config-keys-and-description)
- [Tips and tricks](#tips-and-tricks)
  - [Keybinding to obtain template from focused window for config](#keybinding-to-obtain-template-from-focused-window-for-config)
  - [Apply changes in config file](#apply-changes-in-config-file)
  - [Mute audio for unfocused window (Pipewire/Wireplumber)](#mute-audio-for-unfocused-window-pipewirewireplumber)
  - [Types of limits and which you should use](#types-of-limits-and-which-you-should-use)
- [Known issues](#known-issues)
- [Possible questions](#possible-questions)
  - [How does daemon work?](#how-does-daemon-work)
  - [Does that daemon reduce performance?](#does-that-daemon-reduce-performance)
  - [Is it safe?](#is-it-safe)
  - [Should I trust you and this utility?](#should-i-trust-you-and-this-utility)
  - [With which DE/WM/GPU daemon works correctly?](#with-which-dewmgpu-daemon-works-correctly)
  - [Is not running commands on focus and unfocus makes system vulnerable?](#is-not-running-commands-on-focus-and-unfocus-makes-system-vulnerable)
  - [Can I get banned in a game because of this daemon?](#can-i-get-banned-in-a-game-because-of-this-daemon)
  - [Why was that daemon developed?](#why-was-that-daemon-developed)
  - [Why is code so complicated?](#why-is-code-so-complicated)
  - [Gamescope which allows limit FPS on unfocus exists, Wayland becomes more popular. Are you not late by any chance?](#gamescope-which-allows-limit-fps-on-unfocus-exists-wayland-becomes-more-popular-are-you-not-late-by-any-chance)
  - [What about Wayland support?](#what-about-wayland-support)
  - [Why did you write it in Bash?](#why-did-you-write-it-in-bash)

## Dependencies
### Arch Linux and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `xorg-xprop` `xorg-xwininfo`
  
- Optional: `mangohud` `lib32-mangohud` `libnotify`

### Debian and dereatives
  
- Required: `bash` `cpulimit` `coreutils` `x11-utils`

- Optional: `mangohud` `mangohud:i386` `libnotify-bin`

### Void Linux and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `xprop` `xwininfo`

- Optional: `MangoHud` `MangoHud-32bit` `libnotify`

### Fedora and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `xprop` `xwininfo`

- Optional: `mangohud` `mangohud.i686` `libnotify`

### OpenSUSE Tumbleweed and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `xprop` `xwininfo`

- Optional: `mangohud` `mangohud-32bit` `libnotify4`

### Gentoo and dereatives

- Required: `app-shells/bash` `sys-apps/util-linux` `app-admin/cpulimit` `sys-apps/coreutils` `x11-apps/xprop` `x11-apps/xwininfo`

- Optional: [`mangohud (is not packaged)`](https://github.com/flightlessmango/MangoHud) `x11-libs/libnotify`

Dependencies for other distributions will be added soon.

## Installation
### Manual installation using release tarball
You can use this method if there is no package build script for your distro. Make sure you have installed dependencies as described above before continue.
```bash
flux_version='1.17' # set latest version as I update it here every release
```
```bash
mkdir 'flux' && cd 'flux' # create and change build directory
```
```bash
wget "https://github.com/itz-me-zappex/flux/archive/refs/tags/v${flux_version}.tar.gz" # download archive with release
```
```bash
tar -xvf "v${flux_version}.tar.gz" # extract it
```
```bash
cd "flux-${flux_version}" # change directory to extracted archive
```
```bash
chmod +x 'build.sh' # make build script executable
```
```bash
./build.sh # build 'flux' executable
```
```bash
sudo install -Dm 755 'flux' '/usr/local/bin/flux' # install daemon to '/usr/local/bin'
```

### Arch Linux and dereatives
Make sure you have installed `base-devel` package before continue.
``` bash
flux_version='1.17' # set latest version as I update it here every release
```
```bash
mkdir 'flux' && cd 'flux' # create and change build directory
```
```bash
wget "https://github.com/itz-me-zappex/flux/releases/download/v${flux_version}/PKGBUILD" # download PKGBUILD
```
```bash
makepkg -sric # build a package and install it
```

### Debian and dereatives
```bash
flux_version='1.17' # set latest version as I update it here every release
```
```bash
mkdir 'flux' && cd 'flux' # create and change build directory
```
```bash
wget "https://github.com/itz-me-zappex/flux/releases/download/v${flux_version}/build-deb.sh" # download build script
```
```bash
chmod +x 'build-deb.sh' # make it executable
```
```bash
./build-deb.sh # build a package
```
```bash
sudo dpkg -i "flux-v${flux_version}.deb" ; sudo apt install -f # install a package
```

## Usage
### List of available options
```
Usage: flux [OPTIONS]

Options and values:
  -c, --config <path>        Specify path to config file
                             (default: $XDG_CONFIG_HOME/flux.ini; $HOME/.config/flux.ini; /etc/flux.ini)
  -f, --focused              Display info about focused window in compatible with config way and exit
  -h, --help                 Display this help and exit
  -H, --hot                  Apply actions to already unfocused windows before handling events
  -l, --log <path>           Store messages to specified file
  -L, --log-overwrite        Recreate log file before start, use only with '--log'
  -n, --notifications        Display messages as notifications
  -p, --pick                 Display info about picked window in usable for config file way and exit
  -q, --quiet                Display errors and warnings only
  -T, --timestamp-format     Set timestamp format, use only with '--timestamps' (default: [%Y-%m-%dT%H:%M:%S%z])
  -t, --timestamps           Add timestamps to messages
  -u, --usage                Alias for '--help'
  -v, --verbose              Detailed output
  -V, --version              Display release information and exit

Prefixes configuration:
  --prefix-error <prefix>    Set prefix for error messages (default: [x])
  --prefix-info <prefix>     Set prefix for info messages (default: [i])
  --prefix-verbose <prefix>  Set prefix for verbose messages (default: [~])
  --prefix-warning <prefix>  Set prefix for warning messages (default: [!])

Examples:
  flux -Hvt
  flux -HtLl ~/.flux.log -T '[%d.%m.%Y %H:%M:%S]'
  flux -ql ~/.flux.log
  flux -c ~/.config/flux.ini.bak
```

### Autostart
Just add command to autostart using your DE/WM settings. Running daemon as root also possible, but that feature almost useless.

## Configuration
A simple INI is used for configuration.

### Available keys and description
| Key               | Description |
|-------------------|-------------|
| `name` | Name of process, required if neither `executable` nor `command` is specified. Daemon uses soft match for processes with names which have length 15 symbols, i.e. stripped. |
| `executable` | Path to binary of process, required if neither `name` nor `command` is specified. |
| `owner` | Effective UID of process or username (login), optional identifier. |
| `cpu-limit` | CPU limit between `0%` and `100%`, defaults to `-1%` what means no CPU limit, `%` symbol is optional. |
| `delay` | Delay in seconds before applying CPU/FPS limit or setting `SCHED_IDLE`. Optional, defaults to `0`, supports values with floating point. |
| `exec-focus` | Command to execute on focus event, command runs via bash and will not be killed on daemon exit, output is hidden to avoid mess in output of daemon. |
| `exec-unfocus` | Command to execute on unfocus event, command runs via bash and will not be killed on daemon exit, output is hidden to avoid mess in output of daemon. |
| `lazy-exec-focus` | Same as `exec-focus`, but command will not run when processing opened windows if `--hot` is specified. |
| `lazy-exec-unfocus` | Same as `exec-unfocus`, but command will not run when processing opened windows if `--hot` is specified and will be executed on daemon termination if focused window matches with section where this key and command specified. |
| `command` | Command which is used to start process, required if neither `name` nor `executable` is specified. |
| `mangohud-source-config` | Path to MangoHud config which should be used as a base before apply FPS limit in `mangohud-config`, if not specified, then target behaves as source. Useful if you not looking for duplicate MangoHud config for multiple games. |
| `mangohud-config` | Path to MangoHud config which should be changed (target), required if you want change FPS limits and requires `fps-unfocus`. Make sure you created specified config, at least just keep it blank, otherwise MangoHud will not be able to load new config on fly and daemon will throw warnings related to config absence. Do not use the same config for multiple sections! |
| `fps-unfocus` | FPS to set on unfocus, required by and requires `mangohud-config`, cannot be equal to `0` as that means no limit. |
| `fps-focus` | FPS to set on focus or list of comma-separated integers (e.g. `30,60,120`, used in MangoHud as FPS limits you can switch between using built-in keybinding), requires `fps-unfocus`, defaults to `0` (i.e. no limit). |
| `idle` | Boolean, set `SCHED_IDLE` scheduling policy for process on unfocus event. Daemon requires realtime privileges or root rights to change scheduling policy for processes with `SCHED_RR` or `SCHED_FIFO` to `SCHED_IDLE` and restore it on focus event respecively, and only root rights to restore `SCHED_DEADLINE` with its parameters, changing/restoring `SCHED_OTHER` and `SCHED_BATCH` scheduling policies do not require neither root nor realtime privileges. |

### Config path
- Daemon searches for following configuration files by priority:
  - `$XDG_CONFIG_HOME/flux.ini`
  - `~/.config/flux.ini`
  - `/etc/flux.ini`

### Limitations
As INI is not standartized, I should mention all supported features here.
- Supported
  - Spaces and other symbols in section names.
  - Single and double quoted strings.
  - Сase insensitivity of key names.
  - Comments using `;` and/or `#` symbols.
  - Insensetivity to spaces before and after `=` symbol.
- Unsupported
  - Regular expressions.
  - Line continuation using `\` symbol.
  - Inline comments using `;` and/or `#` symbols.
  - Anything else that unmentioned here.

### Configuration example
Tip: Use `--focus` or `--pick` option to obtain info about process in usable for configuration way from focused window or by picking window respectively.

#### Long examples
```ini
; Example using freezing as that is singleplayer game
[The Witcher 3: Wild Hunt]
name = witcher3.exe
executable = /home/zappex/.local/share/Steam/steamapps/common/Proton 8.0/dist/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\The Witcher 3\bin\x64\witcher3.exe 
owner = zappex
cpu-limit = 0%
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom

; Example using FPS limit as that is online game and I use MangoHud
[Forza Horizon 4]
name = ForzaHorizon4.exe
executable = /run/media/zappex/WD-BLUE/Games/Steam/steamapps/common/Proton 9.0 (Beta)/files/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\ForzaHorizon4\ForzaHorizon4.exe 
owner = zappex
mangohud-config = ~/.config/MangoHud/wine-ForzaHorizon4.conf
mangohud-source-config = ~/.config/MangoHud/MangoHud.conf
fps-unfocus = 5
fps-focus = 60
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom
exec-focus = wpctl set-mute -p $FLUX_PROCESS_PID 0
exec-unfocus = wpctl set-mute -p $FLUX_PROCESS_PID 1

; Example using CPU limit as game does not consume GPU resources when minimized but still uses CPU and requires network connection to download levels and music
[Geometry Dash]
name = GeometryDash.exe
executable = /home/zappex/.local/share/Steam/steamapps/common/Proton 8.0/dist/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\Geometry Dash\GeometryDash.exe 
owner = zappex
cpu-limit = 2%
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom
```

#### Short examples
```ini
; Example using freezing as that is singleplayer game
[The Witcher 3: Wild Hunt]
name = witcher3.exe
cpu-limit = 0%
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom

; Example using FPS limit as that is online game and I use MangoHud
[Forza Horizon 4]
name = ForzaHorizon4.exe
mangohud-config = ~/.config/MangoHud/wine-ForzaHorizon4.conf
mangohud-source-config = ~/.config/MangoHud/MangoHud.conf
fps-unfocus = 5
fps-focus = 60
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom
exec-focus = wpctl set-mute -p $FLUX_PROCESS_PID 0
exec-unfocus = wpctl set-mute -p $FLUX_PROCESS_PID 1

; Example using CPU limit as game does not consume GPU resources when minimized but still uses CPU and requires network connection to download levels and music
[Geometry Dash]
name = GeometryDash.exe
cpu-limit = 2%
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom
```

### Environment variables passed to commands
Note: You may want to use these variables in commands and scripts which running from `exec-focus`, `exec-unfocus`, `lazy-exec-focus` and `lazy-exec-unfocus` config keys to extend daemon functionality.

#### List of variables passed to `exec-focus` and `lazy-exec-focus` config keys and description
| Variable | Description |
|----------|-------------|
| `FLUX_WINDOW_ID` | Hexadecimal ID of focused window |
| `FLUX_PROCESS_PID` | Process PID of focused window |
| `FLUX_PROCESS_NAME` | Process name of focused window |
| `FLUX_PROCESS_EXECUTABLE` | Path to process executable of focused window |
| `FLUX_PROCESS_OWNER` | Effective process UID of focused window |
| `FLUX_PROCESS_COMMAND` | Command used to run process of focused window |
| `FLUX_PREV_WINDOW_ID` | Hexadecimal ID of unfocused window |
| `FLUX_PREV_PROCESS_PID` | Process PID of unfocused window |
| `FLUX_PREV_PROCESS_NAME` | Process name of unfocused window |
| `FLUX_PREV_PROCESS_EXECUTABLE` | Path to process executable of unfocused window |
| `FLUX_PREV_PROCESS_OWNER` | Effective process UID of unfocused window |
| `FLUX_PREV_PROCESS_COMMAND` | Command used to run process of unfocused window |

#### List of variables passed to `exec-unfocus` and `lazy-exec-unfocus` config keys and description
| Variable | Description |
|----------|-------------|
| `FLUX_WINDOW_ID` | Hexadecimal ID of unfocused window |
| `FLUX_PROCESS_PID` | Process PID of unfocused window |
| `FLUX_PROCESS_NAME` | Process name of unfocused window |
| `FLUX_PROCESS_EXECUTABLE` | Path to process executable of unfocused window |
| `FLUX_PROCESS_OWNER` | Effective process UID of unfocused window |
| `FLUX_PROCESS_COMMAND` | Command used to run process of unfocused window |
| `FLUX_NEW_WINDOW_ID` | Hexadecimal ID of focused window |
| `FLUX_NEW_PROCESS_PID` | Process PID of focused window |
| `FLUX_NEW_PROCESS_NAME` | Process name of focused window |
| `FLUX_NEW_PROCESS_EXECUTABLE` | Path to process executable of focused window |
| `FLUX_NEW_PROCESS_OWNER` | Effective process UID of focused window |
| `FLUX_NEW_PROCESS_COMMAND` | Command used to run process of focused window |

## Tips and tricks
### Keybinding to obtain template from focused window for config
- Install `xclip` tool and create keybinding with `flux --focus | xclip -selection clipboard` command.
Now you can easily grab templates from focused windows to use them in config by pasting content using `Ctrl`+`V`.

### Apply changes in config file
- Daemon does not support config parsing on a fly, but there is workaround you can use. Create keybinding for command like `killall flux ; flux --hot` which restarts daemon, use this keybinding if you done with config file editing.

### Mute audio for unfocused window (Pipewire/Wireplumber)
- If you use Pipewire with Wireplumber, you may want to add `exec-focus = wpctl set-mute -p $FLUX_PROCESS_PID 0` and `exec-unfocus = wpctl set-mute -p $FLUX_PROCESS_PID 1` lines to section responsible for game. No idea about neither Pulseaudio nor pure Alsa setups, that is why I can not just add `mute` config key.

### Types of limits and which you should use
- FPS limits recommended for online and multiplayer games and if you do not mind to use MangoHud.
- CPU limits greater than zero recommended for online and multiplayer games in case you do not use MangoHud, but you should be ready for stuttery audio, because `cpulimit` tool interrupts process with `SIGSTOP` and `SIGCONT` signals.
- CPU limit equal to zero recommended for singleplayer games or online games in offline mode, this method freezes game completely to make it just hang in RAM without using any CPU or GPU resources.

## Known issues
- Inability to interact with `glxgears`, `vkcube` and `noisetorch` windows, as those are do not report their PIDs, probably there are more cases but in most cases everything should be fine.
- Freezing online games (setting `cpu-limit` to `0%`) causes disconnects from matches, just use less aggressive CPU limit to allow game to send/receive packets.
- Stuttery audio in game if CPU limit is very aggressive, as `cpulimit` tool interrupts process, that should be expected.
- Unsetting of applied limits for all windows when DE or WM restarts, that happens because of buggyness of `xprop` tool, which is used to read X11 events and it prints multiple events meaning that windows terminating one by one until `_NET_CLIENT_LIST_STACKING(WINDOW): window id #` line becomes blank. Just run `$ xprop -root -spy _NET_CLIENT_LIST_STACKING` and restart DE/WM to make sure in that. Note: added workaround (not a fix!) in [94615aa
](<https://github.com/itz-me-zappex/flux/commit/94615aa6a3d558e9c5413eaa1e1a277f67003f2f>) commit.
- Inability to interact with windows of processes which running using Firejail, because `xprop` reports their internal PIDs and there is no way to identify process properly, e.g. Mednafen running with `firejail` has PID equal to `3` in sandbox and `xprop` reports that PID too, but an attempt to obtain info about that process fails because `/proc/3` contains info about absolutely unrelated process because this check happens out of sandbox. Because of that, false positive also possible. No idea how to fix that.
- If `fps-focus` is a comma-separated list of integers, first value wins, and if value of `fps-focus` is e.g. `30,60,120`, on focus event MangoHud will set 30 FPS lock for game.

## Possible questions
### How does daemon work?
- Daemon reads X11 events related to window focus using `xprop`, then it gets PID of process using window ID using the same tool and uses PID to collect info about process (process name, its executable path, command which is used to run it and effective UID) to compare it with identifiers in config, if it finds window which matches with identifier(s) specified in specific section in config, it can run command from `(lazy-)exec-focus` key, in case you switch to another window - apply FPS or CPU limit and run command from `(lazy-)exec-unfocus` key (if all of those have been specified in config of course). If window does not match with any section in config, nothing happens. To reduce CPU usage and speed up daemon I implemented a caching algorithm which stores info about windows and processes into associative arrays, that allows to collect info about process and window once and then use cache to get this info immediately, if window with the same ID or if new window with the same PID appears (in this case it runs `xprop` to get PID of window and searches for cached info about this process), daemon uses cache to get info. Do not worry, daemon forgets info about window and process immediately if window disappears (i.e. becomes closed, not minimized), so memory leak should not occur.

### Does that daemon reduce performance?
- Long story short, impact on neither performance nor battery life should be noticeable. It uses event-based algorithm to obtain info about windows and processes, when you switching between windows daemon consumes a bit CPU time and just chills out when you doing stuff in single window.

### Is it safe?
- Yes, read above. Neither I nor daemon has access to your data.

### Should I trust you and this utility?
- You can read entire code. If you are uncomfortable, feel free to avoid using it.

### With which DE/WM/GPU daemon works correctly?
- Daemon compatible with all X11 window managers and desktop environments and does not depend on neither GPU nor driver version as it relies on X11 event system.

### Is not running commands on focus and unfocus makes system vulnerable?
- Just put config file to `/etc/flux.ini` and make it read-only, also do something like that with scripts you interacting with from config file.

### Can I get banned in a game because of this daemon?
- Nowadays, anti-cheats are pure garbage, developed by freaks without balls, and you can get banned even for a wrong click. But that is should not be bannable except you are farmer and using sandboxing. Do not write me if you got a ban in game.

### Why was that daemon developed?
- Main task is to reduce CPU/GPU usage of games that have been minimized. Almost every engine fails to recognize that game is unfocused and still consumes a lot of CPU and GPU resources, what can make system slow for other tasks like browsing stuff, transcoding video etc. or even unresponsive at all. With that daemon, imaginated user now can simply play a game and then minimize it if needed without carrying about high CPU/GPU usage and suffering from low multitasking performance. Also, daemon does not care about type of software, so you can use it with games, VMs, video transcoders like Handbrake etc.. To be honest, inspiried by feature from NVIDIA driver for Windows, where user can set FPS limit for minimized software, this tool is not exactly the same, but better than nothing.

### Why is code so complicated?
- That sounds easy - just apply a CPU/FPS limit to window on unfocus and remove it on focus, but that is "a bit" more complicated. Just check how much logic is used for that "easy" task, and daemon has a lot of useful (or not very) features. Also I used built-in stuff in Bash like shell parameter expansions instead of `sed`, loops for reading text line-by-line with regexp in `if` statements instead of `grep` etc. to make code faster, calling external binaries consumes much more time and CPU resources than built-in options.

### Gamescope which allows limit FPS on unfocus exists, Wayland becomes more popular. Are you not late by any chance?
- Well, not everyone is ready for switch to Wayland, there are a lot of reasons exists. Gamescope does not work well on my desktop with NVIDIA GPU and laptop with Intel APU, and I can bet it does not work well for others either. Also, there are a lot of old NVIDIA GPUs that do not support Wayland at all because of old drivers, what makes Gamescope completely useless for owners of these GPUs because it depends on Wayland.

### What about Wayland support?
- That is impossible, there is no any unified way to read window related events (focus, unfocus, closing etc.) and extract PIDs from windows on Wayland. I could implement support for Wayland if I knew how to do that.

### Why did you write it in Bash?
- That is (scripting) language I know pretty good, despite a fact that Bash as all interpretators works slower than compilable languages, it still fits my needs almost perfectly.