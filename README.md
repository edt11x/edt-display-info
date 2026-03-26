# display-info

A cross-platform utility that presents a concise, colour-coded summary of your display and session environment.

- **Linux** — `display-info` (bash script)
- **Windows 11** — `display-info.ps1` (PowerShell script)

## What it shows

### Linux (`display-info`)

| Section | Details |
|---|---|
| **Desktop Environment** | DE name (GNOME, KDE, XFCE, …), `XDG_CURRENT_DESKTOP`, `DESKTOP_SESSION`, `XDG_SESSION_TYPE`, `XDG_SESSION_CLASS` |
| **Display Manager** | `/etc/X11/default-display-manager`, systemd `display-manager.service` symlink, running DM process |
| **loginctl Session** | Session ID, seat, TTY, display, remote flag, service, type, class, state |
| **Display Server** | `$DISPLAY`, `$WAYLAND_DISPLAY`, X server info, window manager / compositor process |
| **Screen / Resolution** | Primary resolution, all connected outputs with offsets, DPI — auto-detects X11 (`xrandr`) or Wayland (`wlr-randr` / `kscreen-doctor` / `/sys/class/drm`) |
| **Graphics Hardware & Mesa Capabilities** | Full Mesa/GL identity, profile versions, capability checklist, memory info, extension counts, PCI devices, optional NVIDIA/Vulkan/VA-API/VDPAU details |
| **Miscellaneous** | User/UID, hostname, kernel version, locale, D-Bus session address, uptime |

### Windows 11 (`display-info.ps1`)

| Section | Details |
|---|---|
| **Desktop Environment & Session** | OS name/version/build/architecture, session name (Console vs RDP) |
| **Login & Winlogon** | `winlogon.exe` / `dwm.exe` status, DWM service, Aero composition, HDR output state, last logon type |
| **Session Info** | Username, domain, session ID, active sessions via `qwinsta` |
| **Display Compositor (DWM)** | Desktop Window Manager status, `dwmapi.dll` version, composition and HDR flags |
| **Screen / Resolution** | Current resolution, refresh rate, bits per pixel, all connected monitors with physical IDs (manufacturer/name/serial), logical DPI |
| **Graphics Hardware & DirectX** | `Win32_VideoController` (name, driver, VRAM, PNP ID), `dxdiag` report (DirectX version, feature levels, D3D9/10/11/12 DDI, shader versions), optional NVIDIA/Vulkan details |
| **Miscellaneous** | User + SID, hostname, admin status, PowerShell/CLR versions, locale, timezone, uptime, relevant environment variables |

Missing or unknown values are highlighted in red so they stand out immediately.

## Graphics Hardware & Mesa Capabilities

This section provides a deep dive into the GPU and Mesa stack:

### Identity
- GL vendor, renderer string, Mesa version
- Hardware acceleration status — green if GPU-backed, red if software (llvmpipe/softpipe)
- Direct rendering flag

### OpenGL Profile Versions
- Core profile version
- Compatibility profile version
- OpenGL ES version
- GLSL (shading language) version
- GLSL ES version
- GLX version

### Mesa `GLX_MESA_query_renderer`
Raw data from Mesa's renderer query extension:
- Device name, Mesa version
- Video memory (MB), unified memory flag
- Preferred profile, max core/compat GL, max GLES 1/2/3 versions

### Video Memory
Available and total memory from `GL_NVX_gpu_memory_info`.

### Extension Counts
Total GL extensions and GLX extensions supported.

### Capability Checklist
A ✔/✘ checklist of 20 notable GL capabilities:

| Capability | Extension(s) checked |
|---|---|
| Geometry shaders | `GL_ARB_geometry_shader4`, `GL_EXT_geometry_shader` |
| Tessellation | `GL_ARB_tessellation_shader` |
| Compute shaders | `GL_ARB_compute_shader` |
| Shader storage (SSBO) | `GL_ARB_shader_storage_buffer_object` |
| 64-bit float (FP64) | `GL_ARB_gpu_shader_fp64` |
| Half-float vertex | `GL_ARB_half_float_vertex` |
| Bindless textures | `GL_ARB_bindless_texture` |
| Sparse textures | `GL_ARB_sparse_texture` |
| Multi-draw indirect | `GL_ARB_multi_draw_indirect` |
| Instanced drawing | `GL_ARB_instanced_arrays`, `GL_ARB_draw_instanced` |
| Transform feedback | `GL_ARB_transform_feedback2` |
| Conditional render | `GL_NV_conditional_render`, `GL_ARB_conditional_render_inverted` |
| Occlusion queries | `GL_ARB_occlusion_query` |
| Timer queries | `GL_ARB_timer_query`, `GL_EXT_timer_query` |
| Anisotropic filtering | `GL_EXT_texture_filter_anisotropic`, `GL_ARB_texture_filter_anisotropic` |
| sRGB framebuffer | `GL_ARB_framebuffer_sRGB`, `GL_EXT_framebuffer_sRGB` |
| Multisample (MSAA) | `GL_ARB_multisample` |
| Sync objects | `GL_ARB_sync` |
| Debug output | `GL_ARB_debug_output`, `GL_KHR_debug` |
| Direct state access | `GL_ARB_direct_state_access` |

### NVIDIA GPU (auto-detected)
If an NVIDIA card is found via `lspci` or `/proc/driver/nvidia/version`, a dedicated block
is shown automatically. If `nvidia-smi` is installed the following sub-sections are added:

| Sub-section | Fields |
|---|---|
| **Identity** | PCI device line, kernel driver version (`/proc/driver/nvidia/version`) |
| **Per-GPU summary** | Name, driver version, VBIOS version, PCI bus ID |
| **Memory** | Total, used, free VRAM |
| **Clocks** | Core (graphics), memory, SM, video clocks |
| **Thermals & power** | GPU temperature, fan speed, power draw, power limit, power management state |
| **Utilisation** | GPU, memory, encoder, decoder utilisation |
| **Capabilities & state** | Compute mode, performance state (P0–P12), ECC mode, CUDA version |

If `nvidia-smi` is not installed a message is printed prompting installation of `nvidia-utils`.

### Optional — extra blocks appear when tools are installed
- **`vulkaninfo`** — Vulkan device summary (API version, driver, device type)
- **`vainfo`** — VA-API driver and supported hardware video decode/encode profiles
- **`vdpauinfo`** — VDPAU implementation and version

## Requirements

### Linux (`display-info`)

- bash 4+
- Standard coreutils (`awk`, `grep`, …)
- `loginctl` (systemd)

**Optional** — richer output when these are present:

| Tool | Extra info |
|---|---|
| `xrandr` | X11 resolution & connected outputs |
| `xdpyinfo` | X server version, DPI |
| `glxinfo` (mesa-demos) | Full Mesa/GL capability report |
| `lspci` (pciutils) | PCI GPU identification |
| `wlr-randr` | Wayland outputs (wlroots compositors) |
| `kscreen-doctor` | Wayland outputs (KDE Plasma) |
| `nvidia-smi` (nvidia-utils) | NVIDIA GPU details (memory, clocks, thermals, utilisation, CUDA version) |
| `vulkaninfo` (vulkan-tools) | Vulkan device summary |
| `vainfo` (libva-utils) | VA-API video acceleration profiles |
| `vdpauinfo` | VDPAU video acceleration info |

### Windows 11 (`display-info.ps1`)

- PowerShell 5.1+ (built into Windows 10/11 — no upgrade needed)
- No additional dependencies required
- Script is UTF-8 with BOM and CRLF line endings (both enforced via `.gitattributes`)

**Optional** — richer output when these are present:

| Tool | Extra info |
|---|---|
| `nvidia-smi` | Full NVIDIA GPU report (memory, clocks, thermals, utilisation, CUDA version) |
| `vulkaninfo` (Vulkan SDK) | Vulkan device summary |
| `dxdiag` | DirectX version, feature levels, shader versions (built into Windows) |

## Installation

### Linux

```bash
# Clone
git clone https://github.com/edt11x/edt-display-info.git
cd edt-display-info

# Install system-wide
sudo cp display-info /usr/local/bin/

# Or just run directly
./display-info
```

### Windows 11

```powershell
# Clone
git clone https://github.com/edt11x/edt-display-info.git
cd edt-display-info

# Allow running local scripts (once, if not already set)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run
.\display-info.ps1
```

> **Encoding note:** `display-info.ps1` is saved as **UTF-8 with BOM** and
> **CRLF (DOS) line endings**. The BOM is required because PowerShell 5.1
> treats UTF-8 files *without* a BOM as Windows-1252, which corrupts
> multi-byte characters inside strings and causes parse errors. A
> `.gitattributes` file locks both the encoding marker and the line endings
> so every `git checkout` delivers the file correctly, regardless of the
> cloning machine's `core.autocrlf` setting.

## Usage

### Linux
```
display-info
```

### Windows 11
```powershell
.\display-info.ps1
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

──────────────────────────────────────────────────────────────
  Graphics Hardware & Mesa Capabilities
──────────────────────────────────────────────────────────────
  GL vendor                   Mesa
  GL renderer                 llvmpipe (LLVM 21.1.8, 256 bits)
  Mesa version                Mesa 25.3.6
  Hardware accelerated        no (software/llvmpipe)  direct rendering: Yes

  OpenGL profile versions:
    Core profile              4.5 (Core Profile) Mesa 25.3.6
    Compat profile            4.5 (Compatibility Profile) Mesa 25.3.6
    OpenGL ES                 OpenGL ES 3.2 Mesa 25.3.6
    GLSL version              4.50
    GLSL ES version           OpenGL ES GLSL ES 3.20
    GLX version               1.4

  Mesa GLX_MESA_query_renderer:
    Vendor                    Mesa (0xffffffff)
    Device                    llvmpipe (LLVM 21.1.8, 256 bits) (0xffffffff)
    Mesa version              25.3.6
    Video memory              8664MB
    Unified memory            yes
    Preferred profile         core (0x1)
    Max core GL               4.5
    Max compat GL             4.5
    Max GLES 1                1.1
    Max GLES 2/3              3.2

  Video memory (GL_NVX_gpu_memory_info):
    Total available           8664 MB
    Currently avail.          0 MB

  GL extensions total         316
  GLX extensions              36

  Notable capabilities (from GL extensions):
    ✘  Geometry shaders
    ✔  Tessellation
    ✔  Compute shaders
    ✔  Shader storage (SSBO)
    ✔  64-bit float (FP64)
    ✔  Half-float vertex
    ✘  Bindless textures
    ✘  Sparse textures
    ✔  Multi-draw indirect
    ✘  Instanced drawing
    ✔  Transform feedback
    ✘  Conditional render
    ✔  Occlusion queries
    ✘  Timer queries
    ✘  Anisotropic filter
    ✘  sRGB framebuffer
    ✔  Multisample (MSAA)
    ✔  Sync objects
    ✘  Debug output
    ✔  Direct state access
```

## License

MIT
