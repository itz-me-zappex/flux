## flux
Advanced daemon for X11 desktops and window managers, designed to automatically limit FPS/CPU usage of unfocused windows and run commands on focus and unfocus events. Written in Bash and partially in C.

## Navigation
- [Known issues](#known-issues)
- [Features](#features)
- [Dependencies](#dependencies)
  - [Arch Linux and dereatives](#arch-linux-and-dereatives)
  - [Debian and dereatives](#debian-and-dereatives)
  - [Void Linux and dereatives](#void-linux-and-dereatives)
  - [Fedora and dereatives](#fedora-and-dereatives)
  - [OpenSUSE Tumbleweed and dereatives](#opensuse-tumbleweed-and-dereatives)
- [Building and installation](#building-and-installation)
  - [Arch Linux and dereatives](#arch-linux-and-dereatives-1)
  - [Manual installation using release tarball](#manual-installation-using-release-tarball)
- [Usage](#usage)
  - [List of available options](#list-of-available-options)
  - [Autostart](#autostart)
- [Configuration](#configuration)
  - [Available keys and description](#available-keys-and-description)
    - [Identifiers](#identifiers)
    - [Limits](#limits)
    - [Limits configuration](#limits-configuration)
    - [Miscellaneous](#miscellaneous)
  - [Config path](#config-path)
  - [Limitations](#limitations)
  - [Configuration example](#configuration-example)
    - [Long examples](#long-examples)
    - [Short examples](#short-examples)
  - [Environment variables passed to commands and description](#environment-variables-passed-to-commands-and-description)
    - [Passed to `exec-focus` and `lazy-exec-focus` config keys](#passed-to-exec-focus-and-lazy-exec-focus-config-keys)
    - [Passed to `exec-unfocus` and `lazy-exec-unfocus` config keys](#passed-to-exec-unfocus-and-lazy-exec-unfocus-config-keys)
- [Tips and tricks](#tips-and-tricks)
  - [Apply changes in config file](#apply-changes-in-config-file)
  - [Mute process audio on unfocus (Pipewire & Wireplumber)](#mute-process-audio-on-unfocus-pipewire--wireplumber)
  - [Types of limits and which you should use](#types-of-limits-and-which-you-should-use)
- [Possible questions](#possible-questions)
  - [How does that daemon work?](#how-does-that-daemon-work)
  - [Does that daemon reduce performance?](#does-that-daemon-reduce-performance)
  - [May I get banned in game because of this daemon?](#may-i-get-banned-in-game-because-of-this-daemon)
  - [Why was that daemon developed?](#why-was-that-daemon-developed)
  - [Why is code so complicated?](#why-is-code-so-complicated)
  - [Why not just use Gamescope to set FPS limit on unfocus?](#why-not-just-use-gamescope-to-set-FPS-limit-on-unfocus)
  - [What about Wayland support?](#what-about-wayland-support)
  - [Why did you write it in Bash?](#why-did-you-write-it-in-bash)

## Known issues
- Freezing online/multiplayer games by setting `cpu-limit` to `0%` causes disconnects. Use less aggressive CPU limit to allow game to send/receive packets.
- Stuttery audio in unfocused game if CPU limit is pretty aggressive, that should be expected because `cpulimit` interrupts process with `SIGSTOP` and `SIGCONT` signals very frequently to limit CPU usage. If you use Pipewire with Wireplumber, you may want to mute process as described [here](#mute-process-audio-on-unfocus-pipewire--wireplumber).

## Features
- CPU and FPS limiting process on unfocus and unlimiting on focus (FPS limiting requires game running using MangoHud with already existing config file).
- Reducing process priority on unfocus and restoring it on focus.
- Minimizing window on unfocus using xdotool (useful for borderless windows only).
- Commands/scripts execution on focus and unfocus events to make user able extend daemon functionality.
- Configurable logging.
- Notifications support.
- Multiple identifiers you can set to avoid false positives.
- Easy INI config.
- Ability to use window and process info through environment variables which daemon passes to scripts/commands in `exec-focus`, `exec-unfocus`, `lazy-exec-focus` and `lazy-exec-unfocus` config keys.
- Works with processes running in sandbox with PID namespaces (e.g. Firejail).
- Survives a whole DE/WM restart (not relogin) and continues work without issues.
- Supports most of X11 DEs/WMs [(EWMH-compatible ones)](<https://specifications.freedesktop.org/wm-spec/latest/>) and does not rely on neither GPU nor its driver.
- Detects and handles both explicitly (appeared with focus event) and implicitly (appeared without focus event) opened windows.

## Dependencies
### Arch Linux and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `libxres` `libx11` `libxext` `xorgproto`
  
- Optional: `mangohud` `lib32-mangohud` `libnotify` `xdotool`

- Build: `libxres` `libx11` `libxext` `xorgproto` `make` `gcc`

### Debian and dereatives
  
- Required: `bash` `cpulimit` `coreutils` `libxres1` `libx11-6` `libxext6`

- Optional: `mangohud` `mangohud:i386` `libnotify-bin` `xdotool`

- Build: `libxres-dev` `libx11-dev` `libxext-dev` `x11proto-dev` `make` `gcc`

### Void Linux and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `libXres` `libX11` `libXext` `xorgproto`

- Optional: `MangoHud` `MangoHud-32bit` `libnotify` `xdotool`

- Build: `libXres-devel` `libX11-devel` `libXext-devel` `xorgproto` `make` `gcc`

### Fedora and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `libXres` `libX11` `libXext`

- Optional: `mangohud` `mangohud.i686` `libnotify` `xdotool`

- Build: `libXres-devel` `libX11-devel` `libXext-devel` `xorg-x11-proto-devel` `make` `gcc`

### OpenSUSE Tumbleweed and dereatives

- Required: `bash` `util-linux` `cpulimit` `coreutils` `libXRes1` `libX11-6` `libXext6`

- Optional: `mangohud` `mangohud-32bit` `libnotify4` `xdotool`

- Build: `libXres-devel` `libX11-devel` `libXext-devel` `xorgproto-devel` `make` `gcc`

## Building and installation
### Arch Linux and dereatives
Make sure you have installed `base-devel` package before continue.

#### Create and change build directory
```bash
mkdir 'flux' && cd 'flux'
```

#### Install `cpulimit` dependency from AUR
```bash
git clone 'https://aur.archlinux.org/cpulimit.git' && cd 'cpulimit' && makepkg -sric && cd ..
```

#### Download PKGBUILD from Git repo
```bash
wget 'https://raw.githubusercontent.com/itz-me-zappex/flux/refs/heads/main/PKGBUILD' && wget 'https://raw.githubusercontent.com/itz-me-zappex/flux/refs/heads/main/create-group.install'
```

#### Build and install package
```bash
makepkg -sric
```

#### Add user to `flux` group to bypass limitations related to changing scheduling policies
```bash
sudo usermod -aG flux $USER
```

### Manual installation using release tarball
Use this method if you using different distro. Make sure you have installed dependencies as described [here](#dependencies) before continue.

#### Make options
| Option | Description |
|--------|-------------|
| `clean` | Remove `out/` in repository directory and all files created there after `make`. |
| `install` | Install daemon to prefix, can be changed using `$PREFIX`, defaults to `/usr/local`. |
| `install-bypass` | Install `10-flux.conf` config to `/etc/security/limits.d` to bypass scheduling policy changing restrictions for users in `flux` group |
| `groupadd` | Create `flux` group to which you can add users. |
| `uninstall` | Remove `bin/flux` and `lib/flux/` from prefix, can be changed using `$PREFIX`, defaults to `/usr/local`. |
| `uninstall-bypass` | Remove `10-flux.conf` config from `/etc/security/limits.d`. |
| `groupdel` | Remove `flux` group from system. |

#### Make environment variables
| Variable | Description |
|----------|-------------|
| `PREFIX` | Install to `<PREFIX>/bin/` and `<PREFIX>/lib/flux/`, defaults to `/usr/local`. |
| `CC` | C compiler, defaults to `gcc`. |
| `CFLAGS` | C compiler options, defaults to `-O2 -s`. |

#### Download latest release with source
```bash
wget -qO- 'https://api.github.com/repos/itz-me-zappex/flux/releases/latest' | grep '"tarball_url":' | cut -d '"' -f 4 | xargs wget -O flux.tar.gz
```

#### Extract archive and change directory
```bash
tar -xvf flux.tar.gz --one-top-level=flux --strip-components=1 && cd 'flux'
```

#### Build daemon
```bash
make
```

#### Install daemon to `/usr/local`, bypass limitations related to changing scheduling policies and create `flux` group
```bash
sudo make install install-bypass groupadd && sudo usermod -aG flux $USER
```

#### Or you may want to change prefix e.g. in case you want install it locally
```bash
PREFIX="~/.local" make install
```


## Usage
### List of available options
```
Usage: flux [OPTIONS]

Options and values:
  -c, --config <path>                 Specify path to config file
                                      default: $XDG_CONFIG_HOME/flux.ini or $HOME/.config/flux.ini or /etc/flux.ini
  -h, --help                          Display this help and exit
  -H, --hot                           Apply actions to already unfocused windows before handling events
  -l, --log <path>                    Store messages to specified file
  -L, --log-overwrite                 Recreate log file before start, requires '--log'
  -n, --notifications                 Display messages as notifications
  -q, --quiet                         Display errors and warnings only
  -T, --timestamp-format <format>     Set timestamp format, requires '--timestamps'
                                      default: [%Y-%m-%dT%H:%M:%S%z]
  -t, --timestamps                    Add timestamps to messages
  -u, --usage                         Alias for '--help'
  -v, --verbose                       Detailed output
  -V, --version                       Display release information and exit

Prefixes configuration:
  --prefix-error <prefix>    Set prefix for error messages
                             default: [x]
  --prefix-info <prefix>     Set prefix for info messages
                             default: [i]
  --prefix-verbose <prefix>  Set prefix for verbose messages
                             default: [~]
  --prefix-warning <prefix>  Set prefix for warning messages
                             default: [!]

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
#### Identifiers
| Key | Description |
|-----|-------------|
| `command` | Command which is used to execute process, required if `name` is not specified. |
| `name` | Name of process, required if `command` is not specified. Daemon uses soft match for processes with names which have length 15 symbols (not including 16th `\n`), i.e. probably stripped. |
| `owner` | Effective UID of process or username (login), optional. |

#### Limits
| Key | Description |
|-----|-------------|
| `cpu-limit` | CPU limit to set on unfocus event, accepts values between `0%` and `100%` (no limit), `%` symbol is optional. Defaults to `100%`. |
| `fps-unfocus` | FPS to set on unfocus, required by and requires `mangohud-config`, cannot be equal to `0` as that means no limit. |
| `fps-focus` | FPS to set on focus or list of comma-separated integers (e.g. `30,60,120`, used in MangoHud as FPS limits you can switch between using built-in keybinding), requires `fps-unfocus`. Defaults to `0` (i.e. no limit). |
| `idle` | Boolean, set `SCHED_IDLE` scheduling policy for process on unfocus event to greatly reduce its priority. Daemon should run as `@flux` to be able restore `SCHED_RR`/`SCHED_FIFO`/`SCHED_OTHER`/`SCHED_BATCH` scheduling policy and only as root to restore `SCHED_DEADLINE` scheduling policy (if daemon does not have sufficient rights to restore these scheduling policies, it will print warning and will not change anything). Defaults to `false`. |

#### Limits configuration
| Key | Description |
|-----|-------------|
| `delay` | Delay in seconds before applying CPU/FPS limit or setting `SCHED_IDLE`. Defaults to `0`, supports values with floating point. |
| `mangohud-source-config` | Path to MangoHud config which should be used as a base before apply FPS limit in `mangohud-config`, if not specified, then target behaves as source. Useful if you not looking for duplicate MangoHud config for multiple games. |
| `mangohud-config` | Path to MangoHud config which should be changed (target), required if you want change FPS limits and requires `fps-unfocus`. Make sure you created specified config, at least just keep it blank, otherwise MangoHud will not be able to load new config on fly and daemon will throw warnings related to config absence. Do not use the same config for multiple sections! |

#### Miscellaneous
| Key | Description |
|-----|-------------|
| `exec-focus` | Command to execute on focus event, command runs via bash using `nohup setsid` and will not be killed on daemon exit, output is hidden to avoid mess. |
| `exec-unfocus` | Command to execute on unfocus event or window closure, command runs via bash using `nohup setsid` and will not be killed on daemon exit, output is hidden to avoid mess. |
| `lazy-exec-focus` | Same as `exec-focus`, but command will not run when processing opened windows if `--hot` is specified or in case window appeared implicitly (w/o focus event). |
| `lazy-exec-unfocus` | Same as `exec-unfocus`, but command will not run when processing opened windows if `--hot` is specified or in case window appeared implicitly (w/o focus event), will be executed on daemon termination if focused window matches with section where this key and command is specified. |
| `minimize` | Boolean, minimize window to panel on unfocus, useful for borderless windowed apps/games as those are not minimized automatically on `Alt+Tab`, requires `xdotool` installed on system. Defaults to `false`. |

### Config path
- Daemon searches for following configuration files by priority:
  - `$XDG_CONFIG_HOME/flux.ini`
  - `$HOME/.config/flux.ini`
  - `/etc/flux.ini`

### Limitations
As INI is not standartized, I should mention all supported features here.
- Supported
  - Spaces and other symbols in section names.
  - Single and double quoted strings.
  - Сase insensitivity of key names.
  - Comments (using `;` and/or `#` symbols).
  - Insensetivity to spaces before and after `=` symbol.
- Unsupported
  - Regular expressions.
  - Line continuation (using `\` symbol).
  - Inline comments
  - Anything else that unmentioned here.

### Configuration example
#### Long examples
```ini
; Freeze on unfocus and disable/enable compositor on focus and unfocus respectively
[The Witcher 3: Wild Hunt]
name = witcher3.exe
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\The Witcher 3\bin\x64\witcher3.exe 
owner = zappex
cpu-limit = 0%
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom

; Set FPS limit to 5, minimize (borderless) and mute on unfocus, restore FPS to 60 and unmute on focus
[Forza Horizon 4]
name = ForzaHorizon4.exe
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

; Reduce CPU usage and reduce priority when unfocused, to keep game able download music and assets
[Geometry Dash]
name = GeometryDash.exe
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\Geometry Dash\GeometryDash.exe 
owner = zappex
cpu-limit = 2%
idle = true
```

#### Short examples
```ini
; Freeze on unfocus and disable/enable compositor on focus and unfocus respectively
[The Witcher 3: Wild Hunt]
name = witcher3.exe
cpu-limit = 0%
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom

; Set FPS limit to 5, minimize (borderless) and mute on unfocus, restore FPS to 60 and unmute on focus
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

; Reduce CPU usage and reduce priority when unfocused, to keep game able download music and assets
[Geometry Dash]
name = GeometryDash.exe
cpu-limit = 2%
idle = true
```

### Environment variables passed to commands and description
Note: You may want to use these variables in commands and scripts which running from `exec-focus`, `exec-unfocus`, `lazy-exec-focus` and `lazy-exec-unfocus` config keys to extend daemon functionality.

#### Passed to `exec-focus` and `lazy-exec-focus` config keys
| Variable | Description |
|----------|-------------|
| `FLUX_WINDOW_ID` | Hexadecimal ID of focused window. |
| `FLUX_PROCESS_PID` | Process PID of focused window. |
| `FLUX_PROCESS_NAME` | Process name of focused window. |
| `FLUX_PROCESS_OWNER` | Effective process UID of focused window. |
| `FLUX_PROCESS_OWNER_USERNAME` | Effective process owner username of focused window. |
| `FLUX_PROCESS_COMMAND` | Command used to run process of focused window. |
| `FLUX_PREV_WINDOW_ID` | Hexadecimal ID of unfocused window. |
| `FLUX_PREV_PROCESS_PID` | Process PID of unfocused window. |
| `FLUX_PREV_PROCESS_NAME` | Process name of unfocused window. |
| `FLUX_PREV_PROCESS_OWNER` | Effective process UID of unfocused window. |
| `FLUX_PREV_PROCESS_OWNER_USERNAME` | Effective process owner username of unfocused window. |
| `FLUX_PREV_PROCESS_COMMAND` | Command used to run process of unfocused window. |

#### Passed to `exec-unfocus` and `lazy-exec-unfocus` config keys
| Variable | Description |
|----------|-------------|
| `FLUX_WINDOW_ID` | Hexadecimal ID of unfocused window. |
| `FLUX_PROCESS_PID` | Process PID of unfocused window. |
| `FLUX_PROCESS_NAME` | Process name of unfocused window. |
| `FLUX_PROCESS_OWNER` | Effective process UID of unfocused window. |
| `FLUX_PROCESS_OWNER_USERNAME` | Effective process owner username of unfocused window. |
| `FLUX_PROCESS_COMMAND` | Command used to run process of unfocused window. |
| `FLUX_NEW_WINDOW_ID` | Hexadecimal ID of focused window. |
| `FLUX_NEW_PROCESS_PID` | Process PID of focused window. |
| `FLUX_NEW_PROCESS_NAME` | Process name of focused window. |
| `FLUX_NEW_PROCESS_OWNER` | Effective process UID of focused window. |
| `FLUX_NEW_PROCESS_OWNER_USERNAME` | Effective process owner username of focused window. |
| `FLUX_NEW_PROCESS_COMMAND` | Command used to run process of focused window. |

## Tips and tricks
### Apply changes in config file
- Daemon does not support config parsing on a fly, but there is workaround you can use. Create keybinding for command like `killall flux ; flux --hot` which restarts daemon, use this keybinding if you done with config file editing.

### Mute process audio on unfocus (Pipewire & Wireplumber)
- Add `exec-focus = wpctl set-mute -p $FLUX_PROCESS_PID 0` and `exec-unfocus = wpctl set-mute -p $FLUX_PROCESS_PID 1` lines to section responsible for game. No idea about neither Pulseaudio nor pure Alsa setups, that is why I can not just add `mute` config key.

### Types of limits and which you should use
- FPS limits recommended for online and multiplayer games and if you do not mind to use MangoHud.
- CPU limits greater than zero recommended for online/multiplayer games in case you do not use MangoHud and for CPU heavy applications e.g. VirtualBox and Handbrake with encoding on CPU, but you should be ready for stuttery audio which caused because of `cpulimit` tool which interrupts process with `SIGSTOP` and `SIGCONT` signals, to fix that on systems with Pipewire and Wireplumber check [this](#mute-process-audio-on-unfocus-pipewire--wireplumber).
- CPU limit equal to zero (freezing) recommended for singleplayer games, online games in offline mode and for stuff which consumes resources in background without reason, makes game/app just hang in RAM without consuming neither CPU nor GPU resources.

## Possible questions
### How does that daemon work?
- Daemon listens changes in `_NET_ACTIVE_WINDOW` and `_NET_CLIENT_LIST_STACKING` atoms, obtains window IDs and using those obtains PIDs, then reads info about processes from files in `/proc/<PID>` to compare it with identifiers in config file and if matching section appears, then it does specified in config file actions.

### Does that daemon reduce performance?
- Daemon uses event-based algorithm to obtain info about windows and processes, when you switching between windows daemon consumes a bit CPU time and just chills out when you doing stuff in single window. Performance loss should not be noticeable even on weak systems.

### May I get banned in game because of this daemon?
- Nowadays, anti-cheats are pure garbage, developed by freaks without balls, and you may get banned even for a wrong click or sudden mouse movement, I am not even talking about bans because of broken libs provided with games by developers themselves. But daemon by its nature should not trigger anticheat, anyway, I am not responsible for your actions, so - use it carefully and do not write me if you get banned.

### Why was that daemon developed?
- Main task is to reduce CPU/GPU usage of games that have been minimized. Almost every engine fails to recognize that game is unfocused and still consumes a lot of CPU and GPU resources, what can make system slow for other tasks like browsing stuff, chatting, transcoding video etc. or even unresponsive at all. With that daemon now I can simply play a game or tinker with virtual machine and then minimize window if needed without carrying about high CPU/GPU usage and suffering from low multitasking performance. Also, daemon does not care about type of software, so you can use it with everything. Inspiried by feature from NVIDIA driver for Windows where user can set FPS limit for minimized software, this tool is not exactly the same, but better than nothing.

### Why is code so complicated?
- I try to avoid using external tools in favor of bashisms to reduce CPU usage by daemon and speed up code.

### Why not just use Gamescope to set FPS limit on unfocus?
- You can use it if you like, my project is aimed at X11 and systems without Wayland support, as well as at non-interference with application/game window and user input unlike Gamescope does, so you have no need to execute app/game using wrapper (except you need FPS limiting, MangoHud required in this case), just configure daemon and have fun.

### What about Wayland support?
- That is impossible, there is no any unified way to read window related events (focus, unfocus, closing etc.) and obtain PIDs from windows on Wayland.

### Why did you write it in Bash?
- That is (scripting) language I know pretty good, despite a fact that Bash as all interpretators works slower than compilable languages, it still fits my needs almost perfectly.