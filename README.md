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
  - [Manual installation using executable from repository](#manual-installation-using-executable-from-repository)
  - [Arch Linux and dereatives](#arch-linux-and-dereatives-1)
  - [Debian and dereatives](#debian-and-dereatives-1)
- [Usage](#usage)
  - [List of available options](#list-of-available-options)
  - [Autostart](#autostart)
  - [Warning for KDE Plasma users](#warning-for-kde-plasma-users)
- [Configuration](#configuration)
  - [Available keys and description](#available-keys-and-description)
  - [Config path](#config-path)
  - [Limitations](#limitations)
  - [Configuration example](#configuration-example)
    - [Long examples](#long-examples)
    - [Short examples](#short-examples)
  - [Environment variables passed to `exec-focus` and `exec-unfocus`](#environment-variables-passed-to-exec-focus-and-exec-unfocus)
    - [List of variables and description](#list-of-variables-and-description)
- [Tips and tricks](#tips-and-tricks)
  - [Keybinding to obtain template from focused window for config](#keybinding-to-obtain-template-from-focused-window-for-config)
  - [Apply changes in config file](#apply-changes-in-config-file)
  - [Types of limits and which you should use](#types-of-limits-and-which-you-should-use)
- [Possible questions](#possible-questions)
  - [How does daemon work?](#how-does-daemon-work)
  - [Does that daemon reduce performance?](#does-that-daemon-reduce-performance)
  - [Is it safe?](#is-it-safe)
  - [Should I trust you and this utility?](#should-i-trust-you-and-this-utility)
  - [With which DE/WM/GPU daemon works correctly?](#with-which-dewmgpu-daemon-works-correctly)
  - [Is not running commands on focus and unfocus makes system vulnerable?](#is-not-running-commands-on-focus-and-unfocus-makes-system-vulnerable)
  - [Can I get banned in a game because of this daemon?](#can-i-get-banned-in-a-game-because-of-this-daemon)
  - [Why was that daemon developed?](#why-was-that-daemon-developed)
  - [Bugs?](#bugs)
  - [Why is code so complicated?](#why-is-code-so-complicated)
  - [Gamescope which allows limit FPS on unfocus exists, Wayland becomes more popular. Are you not late by any chance?](#gamescope-which-allows-limit-fps-on-unfocus-exists-wayland-becomes-more-popular-are-you-not-late-by-any-chance)
  - [What about Wayland support?](#what-about-wayland-support)
  - [Why did you write it in Bash?](#why-did-you-write-it-in-bash)

## Dependencies
### Arch Linux and dereatives

  Required: `bash util-linux cpulimit coreutils xorg-xprop xorg-xwininfo`
  
  Optional: `mangohud lib32-mangohud`

### Debian and dereatives
  
  Required: `bash cpulimit coreutils x11-utils`

  Optional: `mangohud mangohud:i386`

### Void Linux and dereatives

  Required: `bash util-linux cpulimit coreutils xprop xwininfo`

  Optional: `MangoHud MangoHud-32bit`

### Fedora and dereatives

  Required: `bash util-linux cpulimit coreutils xprop xwininfo`

  Optional: `mangohud mangohud.i686`

### OpenSUSE Tumbleweed and dereatives

  Required: `bash util-linux cpulimit coreutils xprop xwininfo`

  Optional: `mangohud mangohud-32bit`

### Gentoo and dereatives

  Required: `app-shells/bash sys-apps/util-linux app-admin/cpulimit sys-apps/coreutils x11-apps/xprop x11-apps/xwininfo`

  Optional: [`mangohud`](https://github.com/flightlessmango/MangoHud) (is not packaged)

Dependencies for other distributions will be added soon.

## Installation
### Manual installation using release tarball
You can use this method if there is no package build script for your distro. Make sure you have installed dependencies as described above before continue.
```bash
fluxver='1.9' # set latest version as I update it here every release
```
```bash
mkdir flux && cd flux # create and change build directory
```
```bash
wget https://github.com/itz-me-zappex/flux/archive/refs/tags/v${fluxver}.tar.gz # download archive with release
```
```bash
tar -xvf v${fluxver}.tar.gz # extract it
```
```bash
sudo install -Dm 755 flux-${fluxver}/flux /usr/local/bin/flux # install daemon to `/usr/local/bin`
```

### Manual installation using executable from repository
I would not suggest to do that unless you found a bug in release and it has been fixed in repository.
```bash
mkdir flux && cd flux # create and change build directory
```
```bash
wget https://raw.githubusercontent.com/itz-me-zappex/flux/refs/heads/main/flux # get `flux` executable from repository
```
```bash
sudo install -Dm 755 flux /usr/local/bin/flux # install daemon to `/usr/local/bin`
```

### Arch Linux and dereatives
Make sure you have installed `base-devel` package before continue.
``` bash
fluxver='1.9' # set latest version as I update it here every release
```
```bash
mkdir flux && cd flux # create and change build directory
```
```bash
wget https://github.com/itz-me-zappex/flux/releases/download/v${fluxver}/PKGBUILD # download PKGBUILD
```
```bash
makepkg -sric # build a package and install it
```

### Debian and dereatives
```bash
fluxver='1.9' # set latest version as I update it here every release
```
```bash
mkdir flux && cd flux # create and change build directory
```
```bash
wget https://github.com/itz-me-zappex/flux/releases/download/v${fluxver}/build-deb.sh # download build script
```
```bash
chmod +x build-deb.sh # make it executable
```
```bash
./build-deb.sh # build a package
```
```bash
sudo dpkg -i flux-v${fluxver}.deb ; sudo apt install -f # install a package
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
  -l, --lazy                 Avoid focus and unfocus commands on hot (use only with '--hot')
  -L, --log <path>           Store messages to specified file
  -p, --pick                 Display info about picked window in usable for config file way and exit
  -q, --quiet                Display errors and warnings only
  -u, --usage                Alias for '--help'
  -v, --verbose              Detailed output
  -V, --version              Display release information and exit

Prefixes configuration:
  --prefix-error <prefix>    Set prefix for error messages (default: [x])
  --prefix-info <prefix>     Set prefix for info messages (default: [i])
  --prefix-verbose <prefix>  Set prefix for verbose messages (default: [~])
  --prefix-warning <prefix>  Set prefix for warning messages (default: [!])

Logging configuration (use only with '--log'):
  --log-no-timestamps        Do not add timestamps to messages in log (do not use with '--log-timestamp')
  --log-overwrite            Recreate log file before start
  --log-timestamp <format>   Set timestamp format (default: [%Y-%m-%dT%H:%M:%S%z])

Examples:
  flux -Hlv
  flux -HlL ~/.flux.log --log-overwrite --log-timestamp '[%d.%m.%Y %H:%M:%S]'
  flux -qL ~/.flux.log --log-disable-timestamps
  flux -c ~/.config/flux.ini.bak
```

### Autostart
Just add command to autostart using your DE settings or WM config. Running daemon as root also possible, but that feature almost useless.

### Warning for KDE Plasma users
If you use KDE Plasma on X11, make sure `$DESKTOP_SESSION` variable contains `plasmax11` (that is what it contains on KDE Neon which I used for testing) to apply workaround which fixes issue with inability to detect termination of windows. Alternatively, run `flux` with command like `DESKTOP_SESSION='plasmax11' flux [OPTIONS]`.

## Configuration
A simple INI is used for configuration.

### Available keys and description
| Key               | Description |
|-------------------|-------------|
| `name` | Name of process, gets from `/proc/<PID>/comm`, required if neither `executable` nor `command` is specified. |
| `executable` | Path to binary of process, gets by reading `/proc/<PID>/exe` symlink, required if neither `name` nor `command` is specified. |
| `owner` | Effective UID of process, gets 2nd UID or 3rd column from `Uid:` string in `/proc/<PID>/status` file. |
| `cpu-limit` | CPU limit between `0%` and `100%`, defaults to `-1%` which means no CPU limit, `%` symbol is optional. |
| `delay` | Delay in seconds before applying CPU/FPS limit. Optional, defaults to `0`, supports values with floating point. |
| `exec-focus` | Command to execute on focus event, command runs via bash and will not be killed on daemon exit, output is hidden to avoid mess in output of daemon. |
| `exec-unfocus` | Command to execute on unfocus event, command runs via bash and will not be killed on daemon exit, output is hidden to avoid mess in output of daemon. |
| `command` | Command of process, gets from `/proc/<PID>/cmdline`, required if neither `name` nor `executable` is specified. |
| `mangohud-config` | Path to MangoHud config, required if you want change FPS limits and requires `fps-unfocus`. Make sure you created specified config, at least just keep it blank, because MangoHud can not load new config on fly unlike reload (if changed) or unload (if removed) it. Do not use the same config for multiple sections! |
| `fps-unfocus` | FPS to set on unfocus, required by and requires `mangohud-config`, cannot be equal to `0` as that means no limit. |
| `fps-focus` | FPS to set on focus, requires `fps-unfocus`, defaults to `0` (i.e. no limit). |

### Config path
- Daemon searches for following configuration files by priority:
  - `$XDG_CONFIG_HOME/flux.ini`
  - `~/.config/flux.ini`
  - `/etc/flux.ini`

### Limitations
As INI is not standartized, I should mention all supported features here.
- Supported
  - Spaces and other symbols in sections names.
  - Single and double quoted strings.
  - Commented lines and inline comments using `;` and/or `#` symbols.
  - Сase insensitivity of keys names.
  - Insensetivity to spaces before and after `=` symbol.
  - Line continuation using `\` symbol, if list of commands separated using `;` symbol and string is not quoted, it still will work and it will not be accepted as comment, not a bug, but feature.
- Unsupported
  - Regular expressions.
  - Inline comment on lines with section name.
  - Anything else that unmentioned here.

### Configuration example
Tip: Use `--focus` or `--pick` option to obtain info about process in usable for configuration way from focused window or by picking it respectively.

#### Long examples
```ini
; Example using freezing as that is single player game
[The Witcher 3: Wild Hunt]
name = witcher3.exe
executable = /home/zappex/.local/share/Steam/steamapps/common/Proton 8.0/dist/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\The Witcher 3\bin\x64\witcher3.exe 
owner = 1000
cpu-limit = 0%
exec-focus = killall picom
exec-unfocus = picom

; Example using FPS limit as that is online game and I use MangoHud
[Forza Horizon 4]
name = ForzaHorizon4.e
executable = /run/media/zappex/WD-BLUE/Games/Steam/steamapps/common/Proton 9.0 (Beta)/files/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\ForzaHorizon4\ForzaHorizon4.exe 
owner = 1000
mangohud-config = ~/.config/MangoHud/wine-ForzaHorizon4.conf
fps-unfocus = 5 ; FPS to set on unfocus event
fps-focus = 60 ; I have 60 FPS lock, so I want restore it on focus event
exec-focus = killall picom
exec-unfocus = picom

; Example using CPU limit as game does not consume GPU resources if minimized but still uses CPU and requires network connection to download levels and music
[Geometry Dash]
name = GeometryDash.ex
executable = /home/zappex/.local/share/Steam/steamapps/common/Proton 8.0/dist/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\Geometry Dash\GeometryDash.exe 
owner = 1000
cpu-limit = 2%
exec-focus = killall picom
exec-unfocus = picom
```

#### Short examples
```ini
; Example using freezing as that is single player game
[The Witcher 3: Wild Hunt]
name = witcher3.exe
cpu-limit = 0%

; Example using FPS limit as that is online game and I use MangoHud
[Forza Horizon 4]
name = ForzaHorizon4.e
mangohud-config = ~/.config/MangoHud/wine-ForzaHorizon4.conf
fps-unfocus = 5 ; FPS to set on unfocus event
fps-focus = 60 ; I have 60 FPS lock, so I want restore it on focus event

; Example using CPU limit as game does not consume GPU resources if minimized but still uses CPU and requires network connection to download levels and music
[Geometry Dash]
name = GeometryDash.ex
cpu-limit = 2%
```

### Environment variables passed to `exec-focus` and `exec-unfocus`
Note: Daemon passes absolutely the same values for both `exec-focus` and `exec-unfocus` commands.

#### List of variables and description
| Variable | Description |
|----------|-------------|
| `FLUX_WINDOW_ID` | ID of focused window |
| `FLUX_PROCESS_PID` | Process PID of focused window |
| `FLUX_PROCESS_NAME` | Process name of focused window |
| `FLUX_PROCESS_EXECUTABLE` | Path to process binary |
| `FLUX_PROCESS_OWNER` | Effective UID of process |
| `FLUX_PROCESS_COMMAND` | Command of process |

## Tips and tricks
### Keybinding to obtain template from focused window for config
- All you need is install `xclip` tool and bind this command: `$ flux --focus | xclip -selection clipboard`.
Now you can easily grab templates from windows to use them in config by pasting content using `Ctrl+v`.

### Apply changes in config file
- Create shortcut for `$ killall flux ; flux --hot --lazy` command which restarts daemon and use it when you done config file editing.

### Types of limits and which you should use
- FPS limits recommended for online and multiplayer games and if you do not mind to use MangoHud, this method reduces resource consumption when game unfocused/minimized.
- CPU limits greater than zero recommended for online and multiplayer games in case you do not use MangoHud, but you should be ready to stuttery audio as `cpulimit` tool interrupts process with `SIGSTOP` and `SIGCONT` signals.
- CPU limit equal to zero recommended for single player games or online games in offline mode, this method freezes game completely to make it just hang in RAM without using any CPU or GPU resources.

## Possible questions
### How does daemon work?
- Daemon reads X11 events related to window focus, then it gets PID of process using window ID via `xprop` tool and uses it to collect info about process (process name, its executable path, command which is used to run it and effective UID) to compare it with identifiers in config, if it finds window which matches with identifier(s) specified in specific section in config, it can run command from `exec-focus` key, in case you switch to another window - apply FPS or CPU limit and run command from `exec-unfocus` key (if all of those has been specified in config of course). If window does not match with any section in config, nothing happens. To reduce CPU usage and speed up daemon I implemented a caching algorithm which stores info about windows and processes into associative arrays, that allows to collect info about process and window once and then use cache to get this info immediately, if window with the same ID or if new window with the same PID appears (in this case it runs `xprop` to get PID of window and searches for cached info about this process), daemon uses cache to get info. Do not worry, daemon forgets info about window and process immediately if window disappears (i.e. becomes closed, not minimized), so memory leak should not occur.

### Does that daemon reduce performance?
- Long story short, impact on neither performance nor battery life should be noticeable. It uses event-based algorithm to obtain info about windows and processes, when you switching between windows daemon consumes a bit CPU time, but it just chills out when you playing game or working in single window.

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
- Main task is to reduce CPU usage of games that have been minimized. Almost every engine fails to recognize that game is unfocused and continues to consume a lot of CPU and GPU resources, what can make system slow for other tasks like browsing stuff, transcoding video etc. or even unresponsive at all. Imagine users with weak laptop who upgraded their RAM to maximum and suffer from a weak processor, now they can simply play a game and then minimize it if needed without carrying about CPU usage or battery level as process will just hang in RAM. To be honest, inspiried by feature from NVIDIA driver for Windows, where user can set FPS limit for minimized software, this tool is not exactly the same, but better than nothing.

### Bugs?
- Nothing is perfect in this world. Almost all bugs I encountered during development have been fixed or will be fixed soon. If you find a bug, open an issue. Known issues that cannot be fixed are:
  - Inability to interact with "glxgears" and "vkcube" windows, as they do not report their PIDs.
  - Freezing online games (setting `cpu-limit` to `0%`) causes disconnects from matches, so use less aggressive CPU limit to allow game to send/receive packets.
  - Stuttery audio in game if CPU limit is very aggressive, as `cpulimit` tool interrupts process, that should be expected.
  - Unsetting of applied limits for all windows when DE or WM restarts, that happens because of buggyness of `xprop` tool, which is used to read X11 events and it prints multiple events meaning that windows terminating one by one until `_NET_CLIENT_LIST_STACKING(WINDOW): window id #` line becomes blank. Just run `$ xprop -root -spy _NET_CLIENT_LIST_STACKING` and restart DE/WM to make sure in that. Note: added workaround (not a fix!) in [94615aa
](<https://github.com/itz-me-zappex/flux/commit/94615aa6a3d558e9c5413eaa1e1a277f67003f2f>) commit.

### Why is code so complicated?
- Long story short, try removing at least one line of code (that does not affect output, of course) and see what happens. That sounds easy - just apply a CPU limit to a window when unfocused and remove it when focused, but that is a bit more complicated. Just check how much logic is used for that "easy" task. Also I used built-in stuff in bash like shell parameter expansions instead of `sed`, loops for reading text line-by-line with regexp in `if` statements instead of `grep` etc. to make code faster, calling external binaries consumes much more time and CPU resources than built-in options.

### Gamescope which allows limit FPS on unfocus exists, Wayland becomes more popular. Are you not late by any chance?
- Well, not everyone is ready for switch to Wayland, there are a lot of reasons exists. Gamescope does not work well on my desktop with NVIDIA GPU and laptop with Intel APU, and I can bet it does not work well for others either. Also, there are a lot of old NVIDIA GPUs that do not support Wayland at all because of old drivers, what makes Gamescope completely useless for owners of these GPUs because it depends on Wayland.

### What about Wayland support?
- That is impossible, there is no any unified way to read window focus events and extract PIDs from windows on Wayland.

### Why did you write it in Bash?
- That is (scripting) language I know pretty good, despite a fact that Bash as all interpretators works slower than compilable languages, it still fits my needs almost perfectly.