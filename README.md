## flux
Advanced daemon for X11 desktops and window managers, designed to automatically limit FPS/CPU usage of unfocused windows and run commands on focus and unfocus events. Written in Bash and partially in C.

## Navigation
- [Known issues](#known-issues)
- [Screenshot](#screenshot)
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
    - [Make options](#make-options)
    - [Make environment variables](#make-environment-variables)
- [Uninstallation](#uninstallation)
  - [Arch Linux and dereatives](#arch-linux-and-dereatives-2)
  - [Uninstallation using `make`](#uninstallation-using-make)
  - [Cleaning up](#cleaning-up)
- [Usage](#usage)
  - [List of available options](#list-of-available-options)
  - [Colorful output](#colorful-output)
  - [Autostart](#autostart)
- [Configuration](#configuration)
  - [Config path](#config-path)
  - [Limitations](#limitations)
  - [Available keys and description](#available-keys-and-description)
    - [Identifiers](#identifiers)
    - [Limits](#limits)
    - [Limits configuration](#limits-configuration)
    - [Scripting](#scripting)
    - [Miscellaneous](#miscellaneous)
  - [Groups](#groups)
  - [Regular expressions](#regular-expressions)
  - [Configuration example](#configuration-example)
  - [Environment variables passed to commands and description](#environment-variables-passed-to-commands-and-description)
    - [On focus or window appearance](#on-focus-or-window-appearance)
    - [On unfocus, closure or daemon termination](#on-unfocus-closure-or-daemon-termination)
- [Tips and tricks](#tips-and-tricks)
  - [Apply changes in config file](#apply-changes-in-config-file)
  - [Mute process audio on unfocus (Pipewire & Wireplumber)](#mute-process-audio-on-unfocus-pipewire--wireplumber)
  - [Reduce niceness of process on window appearance (increase priority)](#reduce-niceness-of-process-on-window-appearance-increase-priority)
  - [Overclock NVIDIA GPU on window focus and revert it on unfocus](#overclock-nvidia-gpu-on-window-focus-and-revert-it-on-unfocus)
  - [Change keyboard layout to English on focus and revert it to Russian on unfocus](#change-keyboard-layout-to-english-on-focus-and-revert-it-to-russian-on-unfocus)
  - [Increase digital vibrance on focus and revert it on unfocus](#increase-digital-vibrance-on-focus-and-revert-it-on-unfocus)
    - [NVIDIA](#nvidia)
    - [Mesa (AMD/Intel)](#mesa-amdintel)
  - [Preload shader cache on window appearance to avoid stuttering](#preload-shader-cache-on-window-appearance-to-avoid-stuttering)
    - [NVIDIA](#nvidia-1)
    - [Mesa (AMD/Intel/NVIDIA with Nouveau)](#mesa-amdintelnvidia-with-nouveau)
- [Possible questions](#possible-questions)
  - [How does this daemon work?](#how-does-this-daemon-work)
  - [Does this daemon reduce performance?](#does-this-daemon-reduce-performance)
  - [May I get banned in game because of this daemon?](#may-i-get-banned-in-game-because-of-this-daemon)
  - [Why was this daemon developed?](#why-was-this-daemon-developed)
  - [Why is code so complicated?](#why-is-code-so-complicated)
  - [What about Wayland support?](#what-about-wayland-support)
  - [Why did you write it in Bash?](#why-did-you-write-it-in-bash)

## Known issues
- Freezing online/multiplayer games by setting `cpu-limit` to `0%` causes disconnects. Use less aggressive CPU limit to allow game to send/receive packets.
- Stuttery audio in unfocused game if CPU limit is pretty aggressive, that should be expected because `cpulimit` interrupts process with `SIGSTOP` and `SIGCONT` signals very frequently to limit CPU usage. If you use Pipewire with Wireplumber, you may want to mute process as described [here](#mute-process-audio-on-unfocus-pipewire--wireplumber).
- Some games under Wine/Proton may not like `flux-cursor-grab`, meaning that if game gets focus without clicking on it with mouse (e.g. after Alt+Tab), cursor will be grabbed and will not work outside of window, but still will be able to escape, that happens for me with Ori and the Will of the Wisps in windowed mode for example. Also cursor grabbing in daemon does not work for all games, because a lot of those grab cursor manually, so cursor grabbing unneeded in this case and you will see warning in log/output that daemon unable to grab cursor, it is okay.

## Screenshot
![](preview.png)
*Daemon running with handling already opened windows (`-H`) in verbose mode (`-v`) and enabled timestamps (`-t`)*

## Features
- Apply CPU or FPS limit to process on unfocus and unlimit on focus, FPS limiting requires game running using MangoHud with already existing config file.
- Reduce process priority on unfocus and restore it on focus.
- Minimize window on unfocus, useful for borderless windows.
- Expand window to fullscreen on focus, useful for games which are handle a window mode in weird way, e.g. Forza Horizon 4 changes its mode to windowed after minimization.
- Force window to grab cursor to prevent it from escaping to second monitor as example.
- Execute commands and scripts on focus, unfocus and window closure events to extend daemon functionality. Daemon provides info about window and process through environment variables.
- Logging support.
- Notifications support.
- Flexible identifiers support to avoid false positives, including regular expressions.
- Works with processes running in sandbox with PID namespaces, through Firejail for example.
- Survives DE/WM restart and continues work without issues.
- Supports most of X11 DEs/WMs [(EWMH-compatible ones)](<https://specifications.freedesktop.org/wm-spec/latest/>) and does not rely on neither GPU nor its driver.
- Detects and handles both explicitly and implicitly opened windows (appeared with and without focus event respectively).

## Dependencies
### Arch Linux and dereatives
**Required:** `bash` `util-linux` `cpulimit` `coreutils` `libxres` `libx11` `libxext` `xorgproto` `less`

**Optional:** `mangohud` `lib32-mangohud` `libnotify`

**Build:** `libxres` `libx11` `libxext` `xorgproto` `make` `gcc`

### Debian and dereatives
**Required:** `bash` `cpulimit` `coreutils` `libxres1` `libx11-6` `libxext6` `less`

**Optional:** `mangohud` `mangohud:i386` `libnotify-bin`

**Build:** `libxres-dev` `libx11-dev` `libxext-dev` `x11proto-dev` `make` `gcc`

### Void Linux and dereatives
**Required:** `bash` `util-linux` `cpulimit` `coreutils` `libXres` `libX11` `libXext` `xorgproto` `less`

**Optional:** `MangoHud` `MangoHud-32bit` `libnotify`

**Build:** `libXres-devel` `libX11-devel` `libXext-devel` `xorgproto` `make` `gcc`

### Fedora and dereatives
**Required:** `bash` `util-linux` `cpulimit` `coreutils` `libXres` `libX11` `libXext` `less`

**Optional:** `mangohud` `mangohud.i686` `libnotify`

**Build:** `libXres-devel` `libX11-devel` `libXext-devel` `xorg-x11-proto-devel` `make` `gcc`

### OpenSUSE Tumbleweed and dereatives
**Required:** `bash` `util-linux` `cpulimit` `coreutils` `libXRes1` `libX11-6` `libXext6` `less`

**Optional:** `mangohud` `mangohud-32bit` `libnotify4`

**Build:** `libXres-devel` `libX11-devel` `libXext-devel` `xorgproto-devel` `make` `gcc`

## Building and installation
### Arch Linux and dereatives
Make sure you have installed `base-devel` package before continue.

#### Install `cpulimit` dependency from AUR
```bash
git clone 'https://aur.archlinux.org/cpulimit.git' && cd 'cpulimit' && makepkg -sric && cd ..
```

#### Clone this repository and use PKGBUILD to install daemon
```bash
git clone https://github.com/itz-me-zappex/flux.git && cd flux && makepkg -sric
```

#### Add user to `flux` group to bypass limitations related to changing scheduling policies
```bash
sudo usermod -aG flux "$USER"
```

### Manual installation using release tarball
Use this method if you using different distro. Make sure you have installed dependencies as described [here](#dependencies) before continue.

#### Make options
| Option | Description |
|--------|-------------|
| `clean` | Remove `build/` in repository directory with all files created there after `make`. |
| `install` | Install daemon to prefix, can be changed using `$PREFIX`, defaults to `/usr/local`. |
| `uninstall` | Remove `bin/flux` and `lib/flux/` from prefix, can be changed using `$PREFIX`, defaults to `/usr/local`. |

#### Make environment variables
| Variable | Description |
|----------|-------------|
| `PREFIX` | Install daemon to `<PREFIX>/bin/` and `<PREFIX>/lib/flux/`, defaults to `/usr/local`. |
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
#### Install daemon to `/usr/local`
```bash
sudo make install
```
#### Or you may want to change prefix e.g. in case you want install it locally
```bash
PREFIX="~/.local" make install
```
#### Or you may want to keep daemon and modules in single directory, that will work, just
```bash
./build/flux -h
```
#### Create `flux` group, needed to bypass scheduling policies change limitations
```bash
sudo groupadd -r flux
```
#### Add current user to `flux` group
```bash
sudo usermod -aG flux "$USER"
```
## Uninstallation
### Arch Linux and dereatives
#### Execute following
```bash
sudo pacman -Rnsc flux
```
### Uninstallation using `make`
#### Download release archive with currently installed version and extract it, e.g
```bash
wget 'https://github.com/itz-me-zappex/flux/archive/refs/tags/v1.23.4.tar.gz' && tar -xvf 'v1.23.4.tar.gz' && cd 'flux-1.23.4'
```
#### Uninstall daemon from `/usr/local`
```bash
sudo make uninstall
```
#### Or, if it was installed somewhere else, e.g. in `/usr`, then
```bash
sudo PREFIX='/usr' make uninstall
```
#### Remove unneeded dependencies
Depends by distro and package manager you use, I highly suggest to remove dependencies selectively and check which packages are use it, to avoid system breakage.
### Cleaning up
#### Lock file (after crash)
```bash
rm '/tmp/flux-lock'
```
#### Config file (if not needed anymore), e.g.
```bash
rm ~/.config/flux.ini
```
#### Remove group from system
```bash
sudo groupdel flux
```
## Usage
### List of available options
```
Usage: flux [-C <mode>] [-c <file>] [-g <method>] [-l <file>] [-T <format>] [-Pe/-Pi/-Pv/-Pw <text>] [options]

Options and values:
  -C, --color <mode>                  Color mode, either 'always', 'auto' or 'never'
                                      default: auto
  -c, --config <file>                 Change path to config file
                                      default: 1) $XDG_CONFIG_HOME/flux.ini
                                               2) $HOME/.config/flux.ini
                                               3) /etc/flux.ini
  -g, --get <method>                  Display window process info and exit, method either 'focus' or 'pick'
  -h, --help                          Display this help and exit
  -H, --hot                           Apply actions to already unfocused windows before handling events
  -l, --log <file>                    Enable logging and set path to log file
  -L, --log-overwrite                 Recreate log file before start, depends on '--log' option
  -n, --notifications                 Display messages as notifications
  -q, --quiet                         Display errors and warnings only
  -T, --timestamp-format <format>     Set timestamp format, depends on '--timestamps' option
                                      default: [%Y-%m-%dT%H:%M:%S%z]
  -t, --timestamps                    Include timestamps in messages
  -u, --usage                         Alias for '--help'
  -v, --verbose                       Detailed output
  -V, --version                       Display release information and exit

Prefixes configuration:
  -Pe, --prefix-error <text>          Change prefix for error messages
                                      default: [x]
  -Pi, --prefix-info <text>           Change prefix for info messages
                                      default: [i]
  -Pv, --prefix-verbose <text>        Change prefix for verbose messages
                                      default: [~]
  -Pw, --prefix-warning <text>        Change prefix for warning messages
                                      default: [!]

Examples:
  flux -Hvt
  flux -HtLl ~/.flux.log -T '[%d.%m.%Y %H:%M:%S]'
  flux -ql ~/.flux.log
  flux -c ~/.config/flux.ini.bak
  flux -tT '(\e[1;4;36m%d.%m.%Y\e[0m \e[1;4;31m%H:%M:%S\e[0m)'
```

### Colorful output
Daemon supports colors in prefixes and timestamps, those are configurable and I did everything to prevent user from shooting into his third "leg". There is a bunch of logic implemented to avoid that:
  - Daemon will not interpret anything but ANSI escape sequences (e.g. `\e[31mHello, world!\e[0m`), so output breakage because of something like `\n` or `\r` simply impossible, those are just shown as text.
  - Daemon adds additional `\e[0m` to end of prefix/timestamp, that prevents output breakage by isolating formatting inside variables.
  - If colors specified by user in custom prefixes/timestamp and `--color` set to `auto` (or unset), daemon disables those when writes message to log file or output appears redirected to file (`stdout` and `stderr`), if `--color` set to `never` - disables colors completely, if `always` - enforces colors even for logging and redirection.

To configure colors in custom prefix/timestamp, you need to use ANSI escape sequence inside of prefix/timestamp as specified below:
```bash
flux -tT '(\e[1;4;36m%d.%m.%Y\e[0m \e[1;4;31m%H:%M:%S\e[0m)'
```

Now you will get timestamps with bold and underlined text with cyan date and red time, order or count of ANSI escape sequences does not matter, so you can turn timestamps into freaking rainbow without causing explosion of the Sun. Same with prefixes. If you do not like `\e` for whatever reason, you can use either `\033`, `\u001b` or `\x1b` instead, those are handled registry independently. More about colors and ANSI escape sequences you can find on `https://www.shellhacks.com/bash-colors` or any other website.

### Autostart
Just add command to autostart using your DE/WM settings. Running daemon as root also possible, but that feature almost useless.

## Configuration
**Note:** A simple INI is used for configuration.

### Config path
Daemon searches for following configuration files by priority:
- `$XDG_CONFIG_HOME/flux.ini`
- `$HOME/.config/flux.ini`
- `/etc/flux.ini`

### Limitations
As INI is not standartized, I should mention all supported features here.

**Supported:**
- Spaces and other symbols in section names.
- Single and double quoted strings.
- Сase insensitivity of key names.
- Comments (using `;` and/or `#` symbols).
- Insensetivity to spaces before and after `=` symbol.
- Appending values to config keys using `+=` (only `exec-oneshot`, `exec-focus`, `exec-unfocus`, `lazy-exec-focus` and `lazy-exec-unfocus`).
- Regular expressions using `~=` (only `name`, `command` and `owner`).

**Unsupported:**
- Line continuation.
- Inline comments.
- Anything else that unmentioned here.

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
| `group` | Specify group from which section suppossed to inherit rules. Group declaration should begin with `@` symbol in both its section name and in value of `group` key. |

#### Scripting
| Key | Description |
|-----|-------------|
| `exec-oneshot` | Command to execute on window appearance event, command runs via bash using `nohup setsid` and will not be killed on daemon exit, output is hidden to avoid mess. |
| `exec-closure` | Command to execute on window closure event, command runs via bash using `nohup setsid` and will not be killed on daemon exit, output is hidden to avoid mess. Defaults to `lazy-exec-unfocus` value if not specified. |
| `exec-exit` | Command to execute when daemon receives `SIGINT` or `SIGTERM` signal, command runs via bash using `nohup setsid` and will not be killed on daemon exit, output is hidden to avoid mess. Defaults to `lazy-exec-unfocus` value if not specified. |
| `exec-exit-focus` | Same as `exec-exit`, but command appears executed only if matching window appears focused at the moment of daemon termination. |
| `exec-exit-unfocus` | Same as `exec-exit`, but command appears executed only if matching window appears unfocused at the moment of daemon termination. |
| `exec-focus` | Command to execute on focus event, command runs via bash using `nohup setsid` and will not be killed on daemon exit, output is hidden to avoid mess. |
| `exec-unfocus` | Command to execute on unfocus event, command runs via bash using `nohup setsid` and will not be killed on daemon exit, output is hidden to avoid mess. |
| `lazy-exec-focus` | Same as `exec-focus`, but command will not run when processing opened windows if `--hot` is specified or in case window appeared implicitly (w/o focus event). |
| `lazy-exec-unfocus` | Same as `exec-unfocus`, but command will not run when processing opened windows if `--hot` is specified or in case window appeared implicitly (w/o focus event). Used as `exec-exit` and/or `exec-closure` automatically if one/two of those is/are not specified. |

#### Miscellaneous
| Key | Description |
|-----|-------------|
| `unfocus-minimize` | Boolean, minimize window to panel on unfocus, useful for borderless windowed apps/games as those are not minimized automatically on `Alt+Tab`. Defaults to `false`. |
| `focus-fullscreen` | Boolean, sends X event to window manager on focus to expand window to fullscreen, useful if game (e.g. Forza Horizon 4) handles window mode in weird a way. Defaults to `false`. |
| `focus-cursor-grab` | Boolean, daemon grabs cursor if possible, binds it to window and because of X11 nature which prevents input to anything but client which owns cursor (`flux-cursor-grab` module in background in this case) - redirects all input into focused window. This ugly layer prevents cursor from escaping to second monitor in some games at cost of *possible* input lag. Cursor is ungrabbed on unfocus event. Defaults to `false`. |

### Groups
To avoid repeating yourself, reduce config file size and simplify editing, you may want to create and use groups.

Order of `group` config key matters a lot, if you want to overwrite value from group, specify key below `group = @<group>`, otherwise - above. If you want to append value to key from group, then use `+=` **after** `group` config key.

Group name does not matter, except section name should begin with `@` symbol. That is how daemon defines whether that is just a section or group.

Position of group declaration section in config file does not matter at all.

Using multiple groups in one section at the same time is not possible.

Group **should not** contain identifiers e.g. `name`, `owner` and/or `command`.

You can use `group` config key inside groups.

To make things more clear, here is an example how to create and use groups:
```ini
[@games]
exec-focus += wpctl set-mute -p $FLUX_PROCESS_PID 0
exec-unfocus += wpctl set-mute -p $FLUX_PROCESS_PID 1
lazy-exec-focus += nvidia-settings -a '[gpu:0]/DigitalVibrance=150'
lazy-exec-unfocus += nvidia-settings -a '[gpu:0]/DigitalVibrance=0'
exec-oneshot += renice -n -4 $FLUX_PROCESS_PID
exec-oneshot += find ~/.nv -type f -exec cat {} + > /dev/null

[@games-overclock]
group = @games
lazy-exec-focus += nvidia-settings -c :0 -a '[gpu:0]/GPUGraphicsClockOffset[2]=200'
lazy-exec-focus += nvidia-settings -c :0 -a '[gpu:0]/GPUMemoryTransferRateOffset[2]=2000'
lazy-exec-unfocus += nvidia-settings -c :0 -a '[gpu:0]/GPUGraphicsClockOffset[2]=0'
lazy-exec-unfocus += nvidia-settings -c :0 -a '[gpu:0]/GPUMemoryTransferRateOffset[2]=0'

[Geometry Dash]
name = GeometryDash.exe
cpu-limit = 2%
idle = true
group = @games-overclock

[Ember Knights]
name = EmberKnights_64.exe
cpu-limit = 5%
idle = true
unfocus-minimize = true
group = @games

[Alan Wake]
name = AlanWake.exe
cpu-limit = 0%
group = @games-overclock
```

### Regular expressions
To simplify config file editing and reduce its config size, you may want to use regexp e.g. to avoid extremely long strings (like in Minecraft's command which has `java` as process name) or to make section matchable with multimple process names.

```ini
; Section matches with both 'vkcube' and 'glxgears' processes
[vkcube and glxgears]
name ~= ^(vkcube|glxgears)$
cpu-limit = 0%

; Minecraft has extremely long command and process name is just 'java', so
[Minecraft]
name = java
;command = /usr/lib/jvm/java-17-openjdk/bin/java -Xms512m -Xmx8192m -Duser.language=en -Djava.library.path...minecraft-1.20.4-client.jar org.prismlauncher.EntryPoint
command ~= minecraft
cpu-limit = 5%
```

### Configuration example
```ini
; ----------------------------------------------------------------------------------------------- ;
; --- Config keys 'command' and 'owner' are optional in this case, so you can use just 'name' --- ;
; ----------------------------------------------------------------------------------------------- ;

; Freeze on unfocus and disable/enable compositor on focus and unfocus respectively
[The Witcher 3: Wild Hunt]
name = witcher3.exe
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\The Witcher 3\bin\x64\witcher3.exe 
owner = zappex
cpu-limit = 0%
lazy-exec-focus = killall picom
lazy-exec-unfocus = picom

; Set FPS limit to 5, minimize (as this is borderless window) and mute on unfocus, restore FPS to 60, unmute and expand to fullscreen on focus
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
exec-exit = wpctl set-mute -p $FLUX_PROCESS_PID 0
idle = true
unfocus-minimize = true
focus-fullscreen = true

; Reduce CPU usage and reduce priority when unfocused, needed to keep game able download music and assets
[Geometry Dash]
name = GeometryDash.exe
command = Z:\run\media\zappex\WD-BLUE\Games\Steam\steamapps\common\Geometry Dash\GeometryDash.exe 
owner = zappex
cpu-limit = 2%
idle = true
```

### Environment variables passed to commands and description
You may want to use these variables in commands and scripts which running from `exec-oneshot`, `exec-focus`, `exec-unfocus`, `lazy-exec-focus` and `lazy-exec-unfocus` config keys to extend daemon functionality.
#### On focus or window appearance
| Variable | Description |
|----------|-------------|
| `FLUX_WINDOW_XID` | Decimal XID of focused window. |
| `FLUX_PROCESS_PID` | Process PID of focused window. |
| `FLUX_PROCESS_NAME` | Process name of focused window. |
| `FLUX_PROCESS_OWNER` | Effective process UID of focused window. |
| `FLUX_PROCESS_OWNER_USERNAME` | Effective process owner username of focused window. |
| `FLUX_PROCESS_COMMAND` | Command used to run process of focused window. |
| `FLUX_PREV_WINDOW_XID` | Decimal XID of unfocused window. |
| `FLUX_PREV_PROCESS_PID` | Process PID of unfocused window. |
| `FLUX_PREV_PROCESS_NAME` | Process name of unfocused window. |
| `FLUX_PREV_PROCESS_OWNER` | Effective process UID of unfocused window. |
| `FLUX_PREV_PROCESS_OWNER_USERNAME` | Effective process owner username of unfocused window. |
| `FLUX_PREV_PROCESS_COMMAND` | Command used to run process of unfocused window. |

#### On unfocus, closure or daemon termination
| Variable | Description |
|----------|-------------|
| `FLUX_WINDOW_XID` | Decimal XID of unfocused window. |
| `FLUX_PROCESS_PID` | Process PID of unfocused window. |
| `FLUX_PROCESS_NAME` | Process name of unfocused window. |
| `FLUX_PROCESS_OWNER` | Effective process UID of unfocused window. |
| `FLUX_PROCESS_OWNER_USERNAME` | Effective process owner username of unfocused window. |
| `FLUX_PROCESS_COMMAND` | Command used to run process of unfocused window. |
| `FLUX_NEW_WINDOW_XID` | Decimal XID of focused window. |
| `FLUX_NEW_PROCESS_PID` | Process PID of focused window. |
| `FLUX_NEW_PROCESS_NAME` | Process name of focused window. |
| `FLUX_NEW_PROCESS_OWNER` | Effective process UID of focused window. |
| `FLUX_NEW_PROCESS_OWNER_USERNAME` | Effective process owner username of focused window. |
| `FLUX_NEW_PROCESS_COMMAND` | Command used to run process of focused window. |

## Tips and tricks
### Apply changes in config file
As daemon does not parse config on a go, you need to restart daemon with `--hot` option after editing config to make daemon handle already opened windows immediately after start.
### Mute process audio on unfocus (Pipewire & Wireplumber)
Add following lines to section responsible for target:

```ini
; Unmute on focus
exec-focus += wpctl set-mute -p $FLUX_PROCESS_PID 0

; Mute on unfocus
exec-unfocus += wpctl set-mute -p $FLUX_PROCESS_PID 1
```
### Reduce niceness of process on window appearance (increase priority)
**Note:** Niceness `-4` is fine for multimedia tasks, including games.

Add following line to section responsible for target:

```ini
; Increase process priority if window opens first time
exec-oneshot += renice -n -4 $FLUX_PROCESS_PID
```
### Overclock NVIDIA GPU on window focus and revert it on unfocus
**Note:** Command from `lazy-exec-unfocus` is also executed on daemon termination if window appears focused at that moment.

Add following lines to section responsible for target (use your own values):

```ini
; Overclock GPU on focus and revert on unfocus
lazy-exec-focus += nvidia-settings -c :0 -a '[gpu:0]/GPUGraphicsClockOffset[2]=200'
lazy-exec-focus += nvidia-settings -c :0 -a '[gpu:0]/GPUMemoryTransferRateOffset[2]=2000'
lazy-exec-unfocus += nvidia-settings -c :0 -a '[gpu:0]/GPUGraphicsClockOffset[2]=0'
lazy-exec-unfocus += nvidia-settings -c :0 -a '[gpu:0]/GPUMemoryTransferRateOffset[2]=0'
```
### Change keyboard layout to English on focus and revert it to Russian on unfocus
**Note:** Useful for some games/apps that do not understand cyrillic letters and rely on layout instead of scancodes.

Add following lines to section responsible for target (use your own values):

```ini
; Change layout to US on focus and to RU on unfocus
lazy-exec-focus += setxkbmap us,ru,ua
lazy-exec-unfocus += setxkbmap ru,ua,us
```
### Increase digital vibrance on focus and revert it on unfocus
**Note:** Use `vibrant-cli` from [`libvibrant`](<https://github.com/libvibrant/libvibrant>) project if you use AMD or Intel GPU.

Add following lines to section responsible for target (use your own values):
#### NVIDIA
```ini
; Increase digital vibrance on focus and revert on unfocus
lazy-exec-focus += nvidia-settings -a '[gpu:0]/DigitalVibrance=150'
lazy-exec-unfocus += nvidia-settings -a '[gpu:0]/DigitalVibrance=0'
```

#### Mesa (AMD/Intel)
```ini
; Increase digital vibrance on focus and revert on unfocus
lazy-exec-focus += vibrant-cli DisplayPort-0 2.3
lazy-exec-unfocus += vibrant-cli DisplayPort-0 1
```

### Preload shader cache on window appearance to avoid stuttering
**Note:** That is how bufferization works, you just need to load file to memory by reading it *somehow* and kernel will not read it from disk again relying on RAM instead.

Add following line to section responsible for target (path may vary depending on system configuration):
#### NVIDIA
```ini
; Preload shader cache if window opens first time
exec-oneshot += find ~/.cache/nvidia -type f -exec cat {} + > /dev/null
```

#### Mesa (AMD/Intel/NVIDIA with Nouveau)
```ini
; Preload shader cache if window opens first time
exec-oneshot += find ~/.cache/mesa_shader_cache_db -type f -exec cat {} + > /dev/null
```

## Possible questions
### How does this daemon work?
- Daemon listens changes in `_NET_ACTIVE_WINDOW` and `_NET_CLIENT_LIST_STACKING` atoms, obtains window IDs and using those obtains PIDs by "asking" Xorg server via `XRes` extension, then reads info about processes from files in `/proc/<PID>` to compare it with identifiers in config file and if matching section appears, then it does specified in config file actions.

### Does this daemon reduce performance?
- Daemon uses event-based algorithm to obtain info about windows and processes, when you switching between windows daemon consumes a bit CPU time and just chills out when you doing stuff in single window. Performance loss should not be noticeable even on weak systems.

### May I get banned in game because of this daemon?
- Nowadays, anti-cheats are pure garbage, developed by freaks without balls, and you may get banned even for a wrong click or sudden mouse movement, I am not even talking about bans because of broken libs provided with games by developers themselves. But daemon by its nature should not trigger anti-cheat, anyway, I am not responsible for your actions, so use it carefully and do not write me if you got a ban.

### Why was this daemon developed?
- Main task is to reduce CPU/GPU usage of games that have been minimized. Almost every engine fails to recognize that game is unfocused and still consumes a lot of CPU and GPU resources, what can make system slow for other tasks like browsing stuff, chatting, transcoding video etc. or even unresponsive at all. With this daemon now I can simply play a game or tinker with virtual machine and then minimize window if needed without carrying about high CPU/GPU usage and suffering from low multitasking performance. Also, daemon does not care about type of software, so you can use it with everything. Inspiried by feature from NVIDIA driver for Windows where user can set FPS limit for minimized software, this tool is not exactly the same, but better than nothing.

### Why is code so complicated?
- I trying to avoid using external tools in favor of bashisms to reduce CPU usage daemon and speed up code.

### What about Wayland support?
- That is impossible, there is no any unified way to read window related events and obtain PIDs of windows on Wayland.
### Why did you write it in Bash?
- This is (scripting) language I know pretty good, despite a fact that Bash as all interpretators works slower than compilable languages, it still fits my needs almost perfectly.
