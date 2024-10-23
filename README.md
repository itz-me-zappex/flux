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
  - [Manual installation](#manual-installation)
  - [Arch Linux and dereatives](#arch-linux-and-dereatives-1)
  - [Debian and dereatives](#debian-and-dereatives-1)
- [Usage](#usage)
  - [Autostart](#autostart)
- [Configuration](#configuration)
  - [Config path](#config-path)
  - [Limitations](#limitations)
  - [Configuration example](#configuration-example)
    - [Long examples](#long-examples)
    - [Short examples](#short-examples)
- [Variables](#variables)
- [Tips and tricks](#tips-and-tricks)
  - [Keybinding to obtain template from focused window for config](#keybinding-to-obtain-template-from-focused-window-for-config)
  - [Apply changes in config file](#apply-changes-in-config-file)
  - [Improve performance of daemon](#improve-performance-of-daemon)
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
### Manual installation
You can use this method if there is no package build script for your distro. Make sure you have installed dependencies as described above before continue.
```bash
fluxver='1.7.7' # set latest version as I update it here every release
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

### Arch Linux and dereatives
Make sure you have installed `base-devel` package before continue.
``` bash
fluxver='1.7.7' # set latest version as I update it here every release
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
fluxver='1.7.7' # set latest version as I update it here every release
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
```
Usage: flux [option] <value>
Options and values:
    -c, --config     <path-to-config>    Specify path to config file
    -f, --focused                        Display info about focused window in usable for config file way
    -h, --help                           Display this help
    -H, --hot                            Apply actions to already unfocused windows before handling events
    -l, --lazy                           Avoid focus and unfocus commands on hot
    -p, --pick                           Display info about picked window in usable for config file way
    -q, --quiet                          Display errors and warnings only
    -u, --usage                          Same as '--help'
    -v, --verbose                        Detailed output
    -V, --version                        Display release information
```

### Autostart
Just add command to autostart using your DE settings or WM config. Running daemon as root also possible, but that feature almost useless.

## Configuration
A simple INI is used for configuration.
Available keys and description:
| Key               | Description |
|-------------------|-------------|
| `name` | Name of process, gets from `/proc/<PID>/comm`, required if neither `executable` nor `command` is specified. |
| `executable` | Path to binary of process, gets by reading `/proc/<PID>/exe` symlink, required if neither `name` nor `command` is specified. |
| `owner` | User ID of process, gets from `/proc/<PID>/status`. |
| `cpu-limit` | CPU limit between `0%` and `100%`, defaults to `-1%` which means no CPU limit, `%` symbol is optional. |
| `delay` | Delay in seconds before applying CPU/FPS limit. Optional, defaults to `0`, supports values with floating point. |
| `focus` | Command to execute on focus event, command runs via bash and will not be killed on daemon exit, output is hidden to avoid mess in output of daemon. |
| `unfocus` | Command to execute on unfocus event, command runs via bash and will not be killed on daemon exit, output is hidden to avoid mess in output of daemon. |
| `command` | Command of process, gets from `/proc/<PID>/cmdline`, required if neither `name` nor `executable` is specified. |
| `mangohud-config` | Path to MangoHud config, required if you want change FPS limits and requires `fps-unfocus`. DO NOT USE THE SAME CONFIG FOR MULTIPLE SECTIONS! |
| `fps-unfocus` | FPS to set on unfocus, required by and requires `mangohud-config`, cannot be equal to `0` as that means no limit. |
| `fps-focus` | FPS to set on focus, requires `fps-unfocus`, defaults to `0` (i.e. full unlimit). |

### Config path
- Daemon searches for following configuration files by priority:
  - `/etc/flux.ini`
  - `$XDG_CONFIG_HOME/flux.ini`
  - `~/.config/flux.ini`

### Limitations
As INI is not standartized, I should mention all supported features here.
- Supported
  - Spaces in section names.
  - Single and double quoted strings.
  - Commented lines and inline comments using `;` and/or `#` symbols.
  - Сase insensitive name of keys.
  - Insensetivity to spaces before and after `=` symbol.
- Unsupported
  - Regular expressions.
  - Inline comment on lines with section name.
  - Line continuation using `\` symbol.
  - Anything else what unmentioned above.

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
focus = killall picom
unfocus = picom

; Example using FPS limit as that is online game and I use MangoHud
[Forza Horizon 4]
name = ForzaHorizon4.e
executable = /run/media/zappex/WD-BLUE/Games/Steam/steamapps/common/Proton 9.0 (Beta)/files/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\ForzaHorizon4\ForzaHorizon4.exe 
owner = 1000
mangohud-config = /home/zappex/.config/MangoHud/wine-ForzaHorizon4.conf
fps-unfocus = 5 ; FPS to set on unfocus event
fps-focus = 60 ; I have 60 FPS lock, so I want restore it on focus event
focus = killall picom
unfocus = picom

; Example using CPU limit as game does not consume GPU resources if minimized but still uses CPU and requires network connection to download levels and music
[Geometry Dash]
name = GeometryDash.ex
executable = /home/zappex/.local/share/Steam/steamapps/common/Proton 8.0/dist/bin/wine64-preloader
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\Geometry Dash\GeometryDash.exe 
owner = 1000
cpu-limit = 2%
focus = killall picom
unfocus = picom
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
mangohud-config = /home/zappex/.config/MangoHud/wine-ForzaHorizon4.conf
fps-unfocus = 5 ; FPS to set on unfocus event
fps-focus = 60 ; I have 60 FPS lock, so I want restore it on focus event

; Example using CPU limit as game does not consume GPU resources if minimized but still uses CPU and requires network connection to download levels and music
[Geometry Dash]
name = GeometryDash.ex
cpu-limit = 2%
```

## Variables
Flux does not support environment variables, but passes them to commands in `focus` and `unfocus` keys.

| Variable | Description |
|----------|-------------|
| `FLUX_WINDOW_ID` | ID of focused window |
| `FLUX_PROCESS_PID` | Process PID of focused window |
| `FLUX_PROCESS_NAME` | Process name of focused window |
| `FLUX_PROCESS_EXECUTABLE` | Path to process binary |
| `FLUX_PROCESS_OWNER` | UID of process |
| `FLUX_PROCESS_COMMAND` | Command of process |

Daemon passes absolutely same values for both `focus` and `unfocus` commands.

## Tips and tricks
### Keybinding to obtain template from focused window for config
- All you need is install `xclip` tool and bind this command: `$ flux --focus | xclip -selection clipboard`.
Now you can easily grab templates from windows to use them in config by pasting content using `Ctrl+v`.

### Apply changes in config file
- Create shortcut for `$ killall flux ; flux --hot --lazy` command which restarts daemon and use it when you done config file editing.

### Improve performance of daemon
- Geeks only, casual users should not care about that. To do that, run daemon using command like `$ chrt --batch 0 flux --hot --lazy`. `SCHED_BATCH` scheduling policy is designed to improve performance of non-interactive tasks like daemons, timers, scripts etc..

### Types of limits and which you should use
- FPS limits recommended for online and multiplayer games and if you do not mind to use MangoHud, this method reduces resource consumption when game unfocused/minimized.
- CPU limits greater than zero recommended for online and multiplayer games in case you do not use MangoHud, but you should be ready to stuttery audio as `cpulimit` tool interrupts process with `SIGSTOP` and `SIGCONT` signals.
- CPU limit equal to zero recommended for single player games or online games in offline mode, this method freezes game completely to make it just hang in RAM without using any CPU or GPU resources.

## Possible questions
### How does daemon work?
- Daemon reads X11 events related to window focus, then it gets PID of process using window ID and uses it to collect info about process (process name, its executable path, command which is used and UID) to compare it with identifiers in config, when it finds window which matches with identifier(s) specified in specific section in config, it runs command from `focus` key (if specified), when you switching to another window - applies FPS or CPU limit (if specified) and runs command from `unfocus` key (if specified). When window does not match with any section in config, nothing happens. To reduce CPU usage and speed up daemon a caching algorithm was implemented which stores info about windows into associative arrays, that allows to just collect info about process once and then use cache to get process info immediately after obtaining its PID when window appears focused again.

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
- Main task is to reduce CPU usage of games that have been minimized. Almost every engine fails to recognize that game is unfocused and continues to consume a lot of CPU and GPU resources, what can make system slow for other tasks like browsing stuff, transcoding video etc. or even unresponsive at all. Imagine users with weak laptop who upgraded their RAM to maximum and suffer from a weak processor, now they can simply play a game and then minimize it if needed without carrying about CPU usage or battery level as process just will hang in RAM. There are a lot of situations and usecases for it.

### Bugs?
- Nothing is perfect in this world. Almost all bugs I encountered during development have been fixed or will be fixed soon. If you find a bug, open an issue. Known issues that cannot be fixed are:
  - Inability to interact with "glxgears" and "vkcube" windows, as they do not report their PIDs.
  - Freezing online games (setting `cpu-limit` to `0%`) causes disconnects from matches, so use less aggressive CPU limit to allow game to send/receive packets.
  - Stuttery audio in game if CPU limit is very aggressive, as `cpulimit` tool interrupts process, that should be expected.

### Why is code so complicated?
- Long story short, try removing at least one line of code (that does not affect output, of course) and see what happens. That sounds easy - just apply a CPU limit to a window when unfocused and remove it when focused, but that is a bit more complicated. Just check how much logic is used for that "easy" task. Also I used built-in stuff in bash like shell parameter expansions instead of `sed`, loops for reading text line-by-line with regexp in `if` statements instead of `grep` etc. to make code faster, calling external binaries consumes much more time and CPU resources than built-in options.

### Gamescope which allows limit FPS on unfocus exists, Wayland becomes more popular. Are you not late by any chance?
- Well, not everyone is ready to switch to Wayland, there are a lot of reasons exists. Gamescope does not work well on my Nvidia desktop and Intel laptop, and I can bet it does not work well for others either. Also, there are a lot of old Nvidia GPUs that do not support Wayland at all because of old drivers, what makes Gamescope completely useless for owners of these GPUs.

### What about Wayland support?
- That is impossible, there is no any unified way to read window focus events and extract PIDs from windows on Wayland.

### Why did you write it in Bash?
- That is (scripting) language I know pretty good, despite a fact that Bash as all interpretators works slower than compilable languages, it still fits my needs almost perfectly.
