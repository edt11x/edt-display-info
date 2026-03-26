#Requires -Version 5.1
# display-info.ps1 — show display/session environment at a glance (Windows 11)
# PowerShell equivalent of the display-info bash script

# ── colour helpers ─────────────────────────────────────────────────────────────
$ESC = [char]27
function C([string]$code) { "$ESC[${code}m" }

$HEAD  = "$(C '1;36')"   # cyan bold    – section headers
$KEY   = "$(C '0;33')"   # yellow       – labels
$VAL   = "$(C '0;97')"   # bright white – values
$OK    = "$(C '0;32')"   # green        – good/present
$WARN  = "$(C '0;31')"   # red          – missing/unknown
$DIM   = "$(C '2;37')"   # dim grey     – secondary info
$BOLD  = "$(C '1')"
$RST   = "$(C '0')"

# Check if the terminal supports ANSI (Windows Terminal, WT, ConEmu, VS Code, etc.)
# Fall back to plain text if not.
$ansiSupported = $false
try {
    if ($Host.UI.SupportsVirtualTerminal) { $ansiSupported = $true }
    elseif ($env:WT_SESSION -or $env:TERM_PROGRAM -or $env:ConEmuPID) { $ansiSupported = $true }
    elseif ([System.Console]::IsOutputRedirected -eq $false) {
        # Try enabling VT processing on Windows console
        $handle = [System.Console]::OutputEncoding  # dummy access
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ConsoleHelper {
    [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
}
"@ -ErrorAction SilentlyContinue 2>$null
        $stdout = [ConsoleHelper]::GetStdHandle(-11)
        [uint32]$mode = 0
        if ([ConsoleHelper]::GetConsoleMode($stdout, [ref]$mode)) {
            [ConsoleHelper]::SetConsoleMode($stdout, $mode -bor 4) | Out-Null
            $ansiSupported = $true
        }
    }
} catch {}

if (-not $ansiSupported) {
    $HEAD = $KEY = $VAL = $OK = $WARN = $DIM = $BOLD = $RST = ""
}

$WIDTH = 62

function hr {
    Write-Host "${DIM}$('─' * $WIDTH)${RST}"
}

function header([string]$title) {
    Write-Host ""
    hr
    Write-Host "  ${HEAD}$($title.PadRight($WIDTH))${RST}"
    hr
}

function row([string]$key, [string]$val, [string]$extra = "") {
    $paddedKey = $key.PadRight(28)
    if ([string]::IsNullOrEmpty($val) -or $val -eq "unknown" -or $val -eq "not found") {
        Write-Host "  ${KEY}${paddedKey}${RST}${WARN}$(if ($val) { $val } else { 'not found' })${RST}"
    } elseif ($extra) {
        Write-Host "  ${KEY}${paddedKey}${RST}${VAL}${val}${RST}  ${DIM}${extra}${RST}"
    } else {
        Write-Host "  ${KEY}${paddedKey}${RST}${VAL}${val}${RST}"
    }
}

function cmd_or([string]$cmd) {
    try { Get-Command $cmd -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}

# PS5.1-compatible null-coalescing: Coalesce $value "fallback"
function Coalesce($val, $fallback) { if ($null -ne $val) { $val } else { $fallback } }

# ── title ─────────────────────────────────────────────────────────────────────
Write-Host ""
$title = "▐ display-info ▌"
$pad = [math]::Max(0, [math]::Floor(($WIDTH + 20) / 2))
Write-Host "${HEAD}${BOLD}$($title.PadLeft($pad))${RST}"
Write-Host ""

# ── 1. Desktop / Session environment ─────────────────────────────────────────
header "Desktop Environment & Session"

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cs = Get-CimInstance Win32_ComputerSystem  -ErrorAction SilentlyContinue

row "Desktop environment"   "Windows Shell (explorer.exe)"
row "OS name"               (Coalesce$os.Caption "unknown")
row "OS version"            (Coalesce$os.Version "unknown")
row "OS build"              (Coalesce$os.BuildNumber "unknown")
row "OS architecture"       (Coalesce$os.OSArchitecture "unknown")
row "Primary owner"         (Coalesce$cs.PrimaryOwnerName "unknown")

# Detect session type (console, RDP, virtual)
$sessionType = "Console"
if ($env:SESSIONNAME -match 'RDP') { $sessionType = "Remote Desktop (RDP)" }
elseif ($env:SESSIONNAME) { $sessionType = $env:SESSIONNAME }
row "Session name"          $sessionType

# ── 2. Display Manager / Login ────────────────────────────────────────────────
header "Login & Winlogon"

$winlogon = Get-Process winlogon -ErrorAction SilentlyContinue | Select-Object -First 1
row "winlogon.exe"          $(if ($winlogon) { "running (PID $($winlogon.Id))" } else { "not detected" })

$dwm = Get-Process dwm -ErrorAction SilentlyContinue | Select-Object -First 1
row "dwm.exe (DWM)"         $(if ($dwm) { "running (PID $($dwm.Id))" } else { "not detected" })

# Windows logon type from security event log (last logon)
try {
    $lastLogon = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} `
                              -MaxEvents 5 -ErrorAction Stop |
                 Where-Object { $_.Properties[8].Value -in 2,10,11 } |
                 Select-Object -First 1
    if ($lastLogon) {
        $logonTypeMap = @{2='Interactive';3='Network';4='Batch';5='Service';7='Unlock';
                          10='RemoteInteractive';11='CachedInteractive'}
        $lt = $lastLogon.Properties[8].Value
        row "Last interactive logon type" "$lt ($(Coalesce$logonTypeMap[$lt] 'unknown'))"
    }
} catch {
    row "Last logon event" "not readable (needs admin)"
}

# ── 3. Session details ────────────────────────────────────────────────────────
header "Session Info"

row "Username"              $env:USERNAME
row "Domain / computer"     "$($env:USERDOMAIN) / $($env:COMPUTERNAME)"
row "Session ID"            $([System.Diagnostics.Process]::GetCurrentProcess().SessionId.ToString())

# query session (qwinsta) if available
if (cmd_or 'qwinsta') {
    Write-Host ""
    Write-Host "  ${DIM}Active sessions (qwinsta):${RST}"
    try {
        $qw = qwinsta 2>$null
        foreach ($line in $qw) {
            Write-Host "  $DIM$line$RST"
        }
    } catch {}
}

# ── 4. Display Server (DWM / compositor) ──────────────────────────────────────
header "Display Compositor (DWM)"

# DWM is the Windows compositor — no separate display server concept like X/Wayland
row "Compositor"            "Desktop Window Manager (DWM)"

# DWM status via service
$dwmSvc = Get-Service -Name 'UxSms' -ErrorAction SilentlyContinue
if ($dwmSvc) {
    row "DWM service (UxSms)"   $dwmSvc.Status.ToString()
} else {
    # On Win10+ DWM runs as a session process, not a traditional service
    row "DWM service"           "integrated (not a standalone service on Win10+)"
}

# DWM DLL version
$dwmDll = "$env:SystemRoot\System32\dwmapi.dll"
if (Test-Path $dwmDll) {
    $dwmVer = (Get-Item $dwmDll).VersionInfo.ProductVersion
    row "dwmapi.dll version"    (Coalesce$dwmVer "unknown")
}

# Aero / transparency
try {
    $dwmReg = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' -ErrorAction Stop
    $composition = $dwmReg.Composition
    row "Composition (Aero)"    $(if ($composition -ne $null) { if ($composition -eq 1) { "enabled" } else { "disabled" } } else { "unknown" })
} catch {
    row "Composition (Aero)"    "unknown"
}

# HDR / Advanced Color
try {
    $hdrKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\VideoSettings'
    $hdrReg = Get-ItemProperty $hdrKey -ErrorAction Stop
    $hdrEnabled = $hdrReg.EnableHDROutput
    row "HDR output"            $(if ($hdrEnabled -eq 1) { "enabled" } elseif ($hdrEnabled -eq 0) { "disabled" } else { "unknown" })
} catch {
    row "HDR output"            "not configured / unknown"
}

# ── 5. Screen / Resolution ────────────────────────────────────────────────────
header "Screen / Resolution"

$monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams `
                            -ErrorAction SilentlyContinue
$vidCtrls = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue

foreach ($vc in $vidCtrls) {
    if ($vc.CurrentHorizontalResolution -and $vc.CurrentVerticalResolution) {
        row "Current resolution"    "$($vc.CurrentHorizontalResolution) x $($vc.CurrentVerticalResolution)"
        row "Refresh rate"          "$($vc.CurrentRefreshRate) Hz"
        row "Bits per pixel"        "$($vc.CurrentBitsPerPixel)"
    }
    break  # primary adapter
}

# All monitors via Win32_DesktopMonitor
$desktopMons = Get-CimInstance Win32_DesktopMonitor -ErrorAction SilentlyContinue
if ($desktopMons) {
    Write-Host ""
    Write-Host "  ${DIM}Connected monitors:${RST}"
    foreach ($mon in $desktopMons) {
        $name   = Coalesce (Coalesce $mon.Name $mon.Description) "Unknown Monitor"
        $width  = Coalesce $mon.ScreenWidth  "?"
        $height = Coalesce $mon.ScreenHeight "?"
        Write-Host "  $DIM$($name.PadRight(30))$RST  ${VAL}${width} x ${height}${RST}"
    }
}

# Physical monitor names via WMI (more accurate)
try {
    $monIds = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID `
                              -ErrorAction Stop
    if ($monIds) {
        Write-Host ""
        Write-Host "  ${DIM}Physical monitor IDs:${RST}"
        foreach ($m in $monIds) {
            $mfr  = [System.Text.Encoding]::ASCII.GetString(
                        ($m.ManufacturerName | Where-Object { $_ -ne 0 })) -replace '\x00',''
            $prod = [System.Text.Encoding]::ASCII.GetString(
                        ($m.UserFriendlyName | Where-Object { $_ -ne 0 })) -replace '\x00',''
            $ser  = [System.Text.Encoding]::ASCII.GetString(
                        ($m.SerialNumberID   | Where-Object { $_ -ne 0 })) -replace '\x00',''
            $inst = $m.InstanceName -replace '\\.*$',''
            Write-Host "  ${DIM}$($inst.PadRight(20))$RST  ${VAL}$mfr $prod$(if($ser){ " [$ser]" })${RST}"
        }
    }
} catch {}

# DPI via registry (per-monitor aware)
try {
    $dpiKey  = 'HKCU:\Control Panel\Desktop\WindowMetrics'
    $dpiReg  = Get-ItemProperty $dpiKey -ErrorAction Stop
    # AppliedDPI is in the PerMonitorSettings or the global HKCU path
} catch {}
try {
    $dpiPerMon = Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction Stop
    $logPPIX   = $dpiPerMon.LogPixels
    if ($logPPIX) { row "Logical DPI (registry)" "$logPPIX dpi" }
} catch {}

# ── 6. Graphics Hardware ───────────────────────────────────────────────────────
header "Graphics Hardware & DirectX"

foreach ($vc in $vidCtrls) {
    Write-Host ""
    Write-Host "  ${DIM}Video controller: $($vc.Name)${RST}"
    row "  Name"                (Coalesce$vc.Name "unknown")
    row "  Driver version"      (Coalesce$vc.DriverVersion "unknown")
    row "  Driver date"         $(try { ([datetime]$vc.DriverDate.ToString()).ToString('yyyy-MM-dd') } catch { $vc.DriverDate })
    row "  Video RAM"           $(if ($vc.AdapterRAM) { "$([math]::Round($vc.AdapterRAM/1MB)) MB" } else { "unknown" })
    row "  Video processor"     (Coalesce$vc.VideoProcessor "unknown")
    row "  Current mode"        (Coalesce$vc.VideoModeDescription "unknown")
    row "  Status"              (Coalesce$vc.Status "unknown")

    # PNP device ID (shows vendor/device IDs)
    $pnp = $vc.PNPDeviceID
    if ($pnp) { row "  PNP device ID"       $pnp }
}

# DirectX version from dxdiag (saved file — avoid interactive prompt)
$dxdiagPath = "$env:TEMP\dxdiag_out.txt"
$dxRan = $false
if (cmd_or 'dxdiag') {
    try {
        Write-Host ""
        Write-Host "  ${DIM}Running dxdiag (this may take a few seconds)...${RST}"
        $dxProc = Start-Process dxdiag -ArgumentList "/t `"$dxdiagPath`"" `
                                -PassThru -WindowStyle Hidden
        $dxProc.WaitForExit(15000) | Out-Null
        if (Test-Path $dxdiagPath) { $dxRan = $true }
    } catch {}
}

if ($dxRan) {
    $dx = Get-Content $dxdiagPath -Raw -ErrorAction SilentlyContinue
    Write-Host ""
    Write-Host "  ${DIM}DirectX info (dxdiag):${RST}"

    function dxval([string]$content, [string]$label) {
        if ($content -match "(?m)^\s*$([regex]::Escape($label)):\s*(.+)$") {
            return $Matches[1].Trim()
        }
        return $null
    }

    $dxVer      = dxval $dx "DirectX Version"
    $dxOsVer    = dxval $dx "Operating System"
    $dxDdVer    = dxval $dx "DD Version"
    $dxD3d9Ver  = dxval $dx "D3D9 Version"
    $dxD3d10    = dxval $dx "D3D10 DDI Version"
    $dxD3d11    = dxval $dx "D3D11 DDI Version"
    $dxD3d12    = dxval $dx "D3D12 DDI Version"
    $dxAGPTex   = dxval $dx "AGP Texture Acceleration"
    $dxVertBuf   = dxval $dx "Vertex Shader Version"
    $dxPixShad   = dxval $dx "Pixel Shader Version"
    $dxFeature   = dxval $dx "Feature Levels"

    if ($dxVer)    { row "  DirectX version"    $dxVer }
    if ($dxFeature){ row "  Feature levels"     $dxFeature }
    if ($dxD3d9Ver){ row "  D3D9 DDI version"   $dxD3d9Ver }
    if ($dxD3d10)  { row "  D3D10 DDI version"  $dxD3d10 }
    if ($dxD3d11)  { row "  D3D11 DDI version"  $dxD3d11 }
    if ($dxD3d12)  { row "  D3D12 DDI version"  $dxD3d12 }
    if ($dxVertBuf){ row "  Vertex shader ver"  $dxVertBuf }
    if ($dxPixShad){ row "  Pixel shader ver"   $dxPixShad }

    Remove-Item $dxdiagPath -Force -ErrorAction SilentlyContinue
}

# NVIDIA via nvidia-smi (same as the bash version)
$nvidiaVcs = $vidCtrls | Where-Object { $_.Name -match 'NVIDIA' }
if ($nvidiaVcs -or (cmd_or 'nvidia-smi')) {
    Write-Host ""
    Write-Host "  ${DIM}NVIDIA GPU detected:${RST}"

    if (cmd_or 'nvidia-smi') {
        Write-Host ""
        Write-Host "  ${DIM}nvidia-smi:${RST}"

        # Identity
        try {
            $smiId = nvidia-smi --query-gpu=index,name,driver_version,vbios_version,pci.bus_id `
                                 --format=csv,noheader 2>$null
            foreach ($line in $smiId) {
                $f = $line -split ',\s*'
                if ($f.Count -ge 5) {
                    row "  GPU $($f[0])"           $f[1]
                    row "    Driver version"        $f[2]
                    row "    VBIOS version"         $f[3]
                    row "    PCI bus ID"            $f[4]
                }
            }
        } catch {}

        # Memory
        Write-Host ""; Write-Host "  ${DIM}  Memory:${RST}"
        try {
            $smiMem = nvidia-smi --query-gpu=index,memory.total,memory.used,memory.free `
                                  --format=csv,noheader 2>$null
            foreach ($line in $smiMem) {
                $f = $line -split ',\s*'
                if ($f.Count -ge 4) {
                    row "    GPU $($f[0])" "total $($f[1].PadRight(10))  used $($f[2].PadRight(10))  free $($f[3])"
                }
            }
        } catch {}

        # Clocks
        Write-Host ""; Write-Host "  ${DIM}  Clocks:${RST}"
        try {
            $smiClk = nvidia-smi --query-gpu=index,clocks.gr,clocks.mem,clocks.sm,clocks.video `
                                  --format=csv,noheader 2>$null
            foreach ($line in $smiClk) {
                $f = $line -split ',\s*'
                if ($f.Count -ge 5) {
                    row "    GPU $($f[0])" "core $($f[1].PadRight(8))  mem $($f[2].PadRight(8))  sm $($f[3].PadRight(8))  video $($f[4])"
                }
            }
        } catch {}

        # Thermals & power
        Write-Host ""; Write-Host "  ${DIM}  Thermals & power:${RST}"
        try {
            $smiTherm = nvidia-smi --query-gpu=index,temperature.gpu,fan.speed,power.draw,power.limit,power.management `
                                    --format=csv,noheader 2>$null
            foreach ($line in $smiTherm) {
                $f = $line -split ',\s*'
                if ($f.Count -ge 6) {
                    row "    GPU $($f[0])" "temp $($f[1]) C  fan $($f[2].PadRight(6))  draw $($f[3].PadRight(8))  limit $($f[4].PadRight(8))  mgmt $($f[5])"
                }
            }
        } catch {}

        # Utilisation
        Write-Host ""; Write-Host "  ${DIM}  Utilisation:${RST}"
        try {
            $smiUtil = nvidia-smi --query-gpu=index,utilization.gpu,utilization.memory,utilization.encoder,utilization.decoder `
                                   --format=csv,noheader 2>$null
            foreach ($line in $smiUtil) {
                $f = $line -split ',\s*'
                if ($f.Count -ge 5) {
                    row "    GPU $($f[0])" "gpu $($f[1].PadRight(6))  mem $($f[2].PadRight(6))  enc $($f[3].PadRight(6))  dec $($f[4])"
                }
            }
        } catch {}

        # Capabilities & state
        Write-Host ""; Write-Host "  ${DIM}  Capabilities & state:${RST}"
        try {
            $smiCap = nvidia-smi --query-gpu=index,compute_mode,pstate,ecc.mode.current,cuda_version `
                                  --format=csv,noheader 2>$null
            foreach ($line in $smiCap) {
                $f = $line -split ',\s*'
                if ($f.Count -ge 5) {
                    row "    Compute mode"      $f[1]
                    row "    Perf state"        $f[2]
                    row "    ECC mode"          $f[3]
                    row "    CUDA version"      $f[4]
                }
            }
        } catch {}
    } else {
        Write-Host "  ${WARN}nvidia-smi not found - install NVIDIA drivers or CUDA toolkit for full details${RST}"
    }
}

# Vulkan info (if vulkaninfo is installed)
if (cmd_or 'vulkaninfo') {
    Write-Host ""
    Write-Host "  ${DIM}Vulkan:${RST}"
    try {
        $vkOut = vulkaninfo --summary 2>$null |
                 Select-String 'GPU|driverVersion|apiVersion|deviceType' |
                 Select-Object -First 12
        foreach ($line in $vkOut) {
            Write-Host "  $DIM$($line.Line.TrimStart())$RST"
        }
    } catch {}
}

# OpenGL via opengl32.dll version (rough indicator; no glxinfo on Windows)
$oglDll = "$env:SystemRoot\System32\opengl32.dll"
if (Test-Path $oglDll) {
    Write-Host ""
    Write-Host "  ${DIM}OpenGL (system opengl32.dll):${RST}"
    $oglVer = (Get-Item $oglDll).VersionInfo
    row "  opengl32.dll version"  "$($oglVer.ProductVersion)"
    row "  Note" "Full OpenGL caps require a vendor tool (e.g. GPU Caps Viewer)"
}

# ── 7. Miscellaneous ───────────────────────────────────────────────────────────
header "Miscellaneous"

row "User / SID"            "$env:USERNAME / $([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)"
row "Hostname"              $env:COMPUTERNAME
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
              [Security.Principal.WindowsBuiltInRole]::Administrator)
row "Running as admin"      $(if ($isAdmin) { "yes" } else { "no" })

row "OS"                    (Coalesce$os.Caption "unknown")
row "OS version"            (Coalesce$os.Version "unknown")
row "OS build"              (Coalesce$os.BuildNumber "unknown")

row "PowerShell version"    $PSVersionTable.PSVersion.ToString()
row "CLR version"           $PSVersionTable.CLRVersion.ToString()

$lang = [System.Globalization.CultureInfo]::CurrentCulture
row "Locale / culture"      "$($lang.Name) ($($lang.DisplayName))"
row "UI culture"            $([System.Globalization.CultureInfo]::CurrentUICulture.Name)
row "Timezone"              $([System.TimeZoneInfo]::Local.DisplayName)

# Uptime
$bootTime = $os.LastBootUpTime
if ($bootTime) {
    $upspan = (Get-Date) - $bootTime
    $upStr  = "$($upspan.Days)d $($upspan.Hours)h $($upspan.Minutes)m"
    row "Last boot"             $bootTime.ToString('yyyy-MM-dd HH:mm:ss')
    row "Uptime"                $upStr
}

# Environment variables relevant to display
$dispEnvVars = @('DISPLAY','WAYLAND_DISPLAY','TERM','TERM_PROGRAM','WT_SESSION',
                 'ConEmuPID','SESSIONNAME','LOGONSERVER','APPDATA','TEMP')
Write-Host ""
Write-Host "  ${DIM}Relevant environment variables:${RST}"
foreach ($v in $dispEnvVars) {
    $val = [System.Environment]::GetEnvironmentVariable($v)
    row "  $v" (Coalesce$val "not set")
}

Write-Host ""
hr
Write-Host ""
