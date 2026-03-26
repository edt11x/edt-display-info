# display-info

A Linux command-line utility that presents a concise, colour-coded summary of your display and session environment.

## What it shows

| Section | Details |
|---|---|
| **Desktop Environment** | DE name (GNOME, KDE, XFCE, …), `XDG_CURRENT_DESKTOP`, `DESKTOP_SESSION`, `XDG_SESSION_TYPE`, `XDG_SESSION_CLASS` |
| **Display Manager** | `/etc/X11/default-display-manager`, systemd `display-manager.service` symlink, running DM process |
| **loginctl Session** | Session ID, seat, TTY, display, remote flag, service, type, class, state |
| **Display Server** | `$DISPLAY`, `$WAYLAND_DISPLAY`, X server info, window manager / compositor process |
| **Screen / Resolution** | Primary resolution, all connected outputs with offsets, DPI — auto-detects X11 (`xrandr`) or Wayland (`wlr-randr` / `kscreen-doctor` / `/sys/class/drm`) |
| **Graphics Hardware** | OpenGL renderer & version (`glxinfo`), PCI display devices (`lspci`), NVIDIA details (`nvidia-smi`) |
| **Miscellaneous** | User/UID, hostname, kernel version, locale, D-Bus session address, uptime |

Missing or unknown values are highlighted in red so they stand out immediately.

## Requirements

- bash 4+
- Standard coreutils (`awk`, `grep`, …)
- `loginctl` (systemd)

**Optional** — richer output when these are present:

| Tool | Extra info |
|---|---|
| `xrandr` | X11 resolution & connected outputs |
| `xdpyinfo` | X server version, DPI |
| `glxinfo` | OpenGL renderer & version |
| `lspci` (pciutils) | PCI GPU info |
| `wlr-randr` | Wayland outputs (wlroots compositors) |
| `kscreen-doctor` | Wayland outputs (KDE Plasma) |
| `nvidia-smi` | NVIDIA GPU details |

## Installation

```bash
# Clone
git clone https://github.com/edt11x/edt-display-info.git
cd edt-display-info

# Install system-wide
sudo cp display-info /usr/local/bin/

# Or just run directly
./display-info
```

## Usage

```
display-info
```

No arguments, no options — just run it.

## Example output

```
▐ display-info ▌

──────────────────────────────────────────────────────────────
  Desktop Environment & Session
──────────────────────────────────────────────────────────────
  Desktop environment         XFCE
  XDG_CURRENT_DESKTOP         XFCE
  DESKTOP_SESSION             xfce
  XDG_SESSION_TYPE            x11
  XDG_SESSION_CLASS           user

──────────────────────────────────────────────────────────────
  Display Manager
──────────────────────────────────────────────────────────────
  systemd display-manager.service  lightdm
  Running DM process               lightdm

──────────────────────────────────────────────────────────────
  loginctl Session Info
──────────────────────────────────────────────────────────────
  Session ID                  3
    Seat                      seat0
    TTY                       tty7
    Display                   :0
    Remote                    no
    Type                      x11
    Class                     user
    State                     active

──────────────────────────────────────────────────────────────
  Screen / Resolution
──────────────────────────────────────────────────────────────
  Primary resolution          1920x1080
  DPI                         96x96
```

## License

MIT
