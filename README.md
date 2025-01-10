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
  - [How does that daemon work?](#how-does-that-daemon-work)
  - [Does that daemon reduce performance?](#does-that-daemon-reduce-performance)
  - [Which DE/WM/GPU daemon supports?](#which-dewmgpu-daemon-supports)
  - [May I get banned in game because of this daemon?](#may-i-get-banned-in-game-because-of-this-daemon)
  - [Why was that daemon developed?](#why-was-that-daemon-developed)
  - [Why is code so complicated?](#why-is-code-so-complicated)
  - [Why not just use Gamescope to set FPS limit on unfocus?](#why-not-just-use-gamescope-to-set-FPS-limit-on-unfocus)
  - [What about Wayland support?](#what-about-wayland-support)
  - [Why did you write it in Bash?](#why-did-you-write-it-in-bash)

## Dependencies
### Arch Linux and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `xorg-xprop` `xorg-xwininfo`
  
- Optional: `mangohud` `lib32-mangohud` `libnotify` `xdotool`

### Debian and dereatives
  
- Required: `bash` `cpulimit` `coreutils` `x11-utils`

- Optional: `mangohud` `mangohud:i386` `libnotify-bin` `xdotool`

### Void Linux and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `xprop` `xwininfo`

- Optional: `MangoHud` `MangoHud-32bit` `libnotify` `xdotool`

### Fedora and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `xprop` `xwininfo`

- Optional: `mangohud` `mangohud.i686` `libnotify` `xdotool`

### OpenSUSE Tumbleweed and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `xprop` `xwininfo`

- Optional: `mangohud` `mangohud-32bit` `libnotify4` `xdotool`

### Gentoo and dereatives

- Required: `app-shells/bash` `sys-apps/util-linux` `app-admin/cpulimit` `sys-apps/coreutils` `x11-apps/xprop` `x11-apps/xwininfo`

- Optional: `x11-libs/libnotify` `x11-misc/xdotool` [`mangohud (is not packaged)`](https://github.com/flightlessmango/MangoHud)

Dependencies for other distributions will be added soon.

## Installation
### Manual installation using release tarball
You can use this method if there is no package build script for your distro. Make sure you have installed dependencies as described above before continue.
```bash
flux_version='1.18.2' # set latest version as I update it here every release
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
flux_version='1.18.2' # set latest version as I update it here every release
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
flux_version='1.18.2' # set latest version as I update it here every release
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
| `cpu-limit` | CPU limit between `0%` and `100%`, `%` symbol is optional. Defaults to `-1%` (i.e. no CPU limit). |
| `delay` | Delay in seconds before applying CPU/FPS limit or setting `SCHED_IDLE`. Defaults to `0`, supports values with floating point. |
| `exec-focus` | Command to execute on focus event, command runs via bash and will not be killed on daemon exit, output is hidden to avoid mess in output of daemon. |
| `exec-unfocus` | Command to execute on unfocus event, command runs via bash and will not be killed on daemon exit, output is hidden to avoid mess in output of daemon. |
| `lazy-exec-focus` | Same as `exec-focus`, but command will not run when processing opened windows if `--hot` is specified. |
| `lazy-exec-unfocus` | Same as `exec-unfocus`, but command will not run when processing opened windows if `--hot` is specified and will be executed on daemon termination if focused window matches with section where this key and command specified. |
| `command` | Command which is used to start process, required if neither `name` nor `executable` is specified. |
| `mangohud-source-config` | Path to MangoHud config which should be used as a base before apply FPS limit in `mangohud-config`, if not specified, then target behaves as source. Useful if you not looking for duplicate MangoHud config for multiple games. |
| `mangohud-config` | Path to MangoHud config which should be changed (target), required if you want change FPS limits and requires `fps-unfocus`. Make sure you created specified config, at least just keep it blank, otherwise MangoHud will not be able to load new config on fly and daemon will throw warnings related to config absence. Do not use the same config for multiple sections! |
| `fps-unfocus` | FPS to set on unfocus, required by and requires `mangohud-config`, cannot be equal to `0` as that means no limit. |
| `fps-focus` | FPS to set on focus or list of comma-separated integers (e.g. `30,60,120`, used in MangoHud as FPS limits you can switch between using built-in keybinding), requires `fps-unfocus`. Defaults to `0` (i.e. no limit). |
| `idle` | Boolean, set `SCHED_IDLE` scheduling policy for process on unfocus event. Daemon requires realtime privileges or root rights to restore `SCHED_RR`/`SCHED_FIFO` and only root rights to restore `SCHED_DEADLINE` scheduling policy, restoring `SCHED_OTHER` and `SCHED_BATCH` scheduling policies do not require neither root nor realtime privileges. Defaults to `false`.|
| `minimize` | Boolean, minimize window to panel on unfocus, useful for borderless windowed apps/games as those are not minimized automatically on `Alt+Tab`, requires `xdotool` installed on system. Defaults to `false`. |

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
; Freeze singleplayer game on unfocus and disable/enable compositor on unfocus and focus respectively
[The Witcher 3: Wild Hunt]
name = witcher3.exe
executable = /home/zappex/.local/share/Steam/steamapps/common/Proton 8.0/dist/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\The Witcher 3\bin\x64\witcher3.exe 
owner = zappex
cpu-limit = 0%
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom

; Set FPS limit to 5 on unfocus and restore it to 60 on focus, unmute and mute on focus and unfocus respectively, minimize on unfocus as game supports only borderless windowed mode and reduce priority
[Forza Horizon 4]
name = ForzaHorizon4.exe
executable = /run/media/zappex/WD-BLUE/Games/Steam/steamapps/common/Proton 9.0 (Beta)/files/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\ForzaHorizon4\ForzaHorizon4.exe 
owner = zappex
mangohud-config = ~/.config/MangoHud/wine-ForzaHorizon4.conf
mangohud-source-config = ~/.config/MangoHud/MangoHud.conf
fps-unfocus = 5
fps-focus = 60
exec-focus = wpctl set-mute -p $FLUX_PROCESS_PID 0
exec-unfocus = wpctl set-mute -p $FLUX_PROCESS_PID 1
idle = true
minimize = true

; Reduce CPU usage when unfocused to make game able download music and assets and reduce priority
[Geometry Dash]
name = GeometryDash.exe
executable = /home/zappex/.local/share/Steam/steamapps/common/Proton 8.0/dist/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\Geometry Dash\GeometryDash.exe 
owner = zappex
cpu-limit = 2%
idle = true
```

#### Short examples
```ini
; Freeze singleplayer game on unfocus and disable/enable compositor on unfocus and focus respectively
[The Witcher 3: Wild Hunt]
name = witcher3.exe
cpu-limit = 0%
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom

; Set FPS limit to 5 on unfocus and restore it to 60 on focus, unmute and mute on focus and unfocus respectively, minimize on unfocus as game supports only borderless windowed mode and reduce priority
[Forza Horizon 4]
name = ForzaHorizon4.exe
mangohud-config = ~/.config/MangoHud/wine-ForzaHorizon4.conf
mangohud-source-config = ~/.config/MangoHud/MangoHud.conf
fps-unfocus = 5
fps-focus = 60
exec-focus = wpctl set-mute -p $FLUX_PROCESS_PID 0
exec-unfocus = wpctl set-mute -p $FLUX_PROCESS_PID 1
idle = true
minimize = true

; Reduce CPU usage when unfocused to make game able download music and assets and reduce priority
[Geometry Dash]
name = GeometryDash.exe
cpu-limit = 2%
idle = true
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
### How does that daemon work?
- Daemon listens `xprop` which runs with `-root -spy` options to track `_NET_ACTIVE_WINDOW` and `_NET_CLIENT_LIST_STACKING` events, using window IDs it obtains PIDs, then reads info about processes from files in `/proc/<PID>` to compare it with identifiers in config file and if matching section appears, then it does specified in config file actions.

### Does that daemon reduce performance?
- Daemon uses event-based algorithm to obtain info about windows and processes, when you switching between windows daemon consumes a bit CPU time and just chills out when you doing stuff in single window. Performance loss should not be noticeable even on weak systems.

### Which DE/WM/GPU daemon supports?
- Daemon compatible with all EMHW-compatible X11 window managers (and desktop environments respectively) and does not depend on neither GPU nor driver version as it relies on X11 event system.

### May I get banned in game because of this daemon?
- Nowadays, anti-cheats are pure garbage, developed by freaks without balls, and you may get banned even for a wrong click or sudden mouse movement, I am not even talking about bans because of broken libs provided with games by developers themselves. But daemon by its nature should not trigger anticheat, anyway, I am not responsible for your actions, so - use it carefully and do not write me if you get banned.

### Why was that daemon developed?
- Main task is to reduce CPU/GPU usage of games that have been minimized. Almost every engine fails to recognize that game is unfocused and still consumes a lot of CPU and GPU resources, what can make system slow for other tasks like browsing stuff, chatting, transcoding video etc. or even unresponsive at all. With that daemon now I can simply play a game or tinker with virtual machine and then minimize window if needed without carrying about high CPU/GPU usage and suffering from low multitasking performance. Also, daemon does not care about type of software, so you can use it with everything. Inspiried by feature from NVIDIA driver for Windows where user can set FPS limit for minimized software, this tool is not exactly the same, but better than nothing.

### Why is code so complicated?
- I try to avoid using external tools in favor of bashisms to reduce CPU usage by daemon and speed up code.

### Why not just use Gamescope to set FPS limit on unfocus?
- You can use it if you like, my project is aimed at X11 and systems without Wayland support, as well as at non-interference with application/game window and user input unlike Gamescope does, so you have no need to execute app/game using wrapper, just configure daemon and have fun.

### What about Wayland support?
- That is impossible, there is no any unified way to read window related events (focus, unfocus, closing etc.) and obtain PIDs from windows on Wayland.

### Why did you write it in Bash?
- That is (scripting) language I know pretty good, despite a fact that Bash as all interpretators works slower than compilable languages, it still fits my needs almost perfectly.