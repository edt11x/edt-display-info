#Requires -Version 5.1
# display-info.ps1 -- show display/session environment at a glance (Windows 11)
# PowerShell equivalent of the display-info bash script

$WIDTH = 62

function hr {
    Write-Host ('─' * $WIDTH) -ForegroundColor DarkGray
}

function header([string]$title) {
    Write-Host ""
    hr
    Write-Host "  $($title.PadRight($WIDTH))" -ForegroundColor Cyan
    hr
}

function row([string]$key, [string]$val, [string]$extra = "") {
    $paddedKey = $key.PadRight(28)
    if ([string]::IsNullOrEmpty($val) -or $val -eq "unknown" -or $val -eq "not found") {
        Write-Host -NoNewline -ForegroundColor Yellow "  $paddedKey"
        Write-Host $(if ($val) { $val } else { 'not found' }) -ForegroundColor Red
    } elseif ($extra) {
        Write-Host -NoNewline -ForegroundColor Yellow "  $paddedKey"
        Write-Host -NoNewline $val -ForegroundColor White
        Write-Host "  $extra" -ForegroundColor DarkGray
    } else {
        Write-Host -NoNewline -ForegroundColor Yellow "  $paddedKey"
        Write-Host $val -ForegroundColor White
    }
}

function dim([string]$text) {
    Write-Host "  $text" -ForegroundColor DarkGray
}

function cmd_or([string]$cmd) {
    try { Get-Command $cmd -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}

# PS5.1-compatible null-coalescing
function Coalesce($val, $fallback) { if ($null -ne $val) { $val } else { $fallback } }

# ── title ─────────────────────────────────────────────────────────────────────
Write-Host ""
$titleText = "▐ display-info ▌"
$pad = [math]::Max(0, [math]::Floor(($WIDTH + 20) / 2))
Write-Host $titleText.PadLeft($pad) -ForegroundColor Cyan
Write-Host ""

# ── 1. Desktop / Session environment ─────────────────────────────────────────
header "Desktop Environment & Session"

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cs = Get-CimInstance Win32_ComputerSystem  -ErrorAction SilentlyContinue

row "Desktop environment"   "Windows Shell (explorer.exe)"
row "OS name"               $(Coalesce $os.Caption "unknown")
row "OS version"            $(Coalesce $os.Version "unknown")
row "OS build"              $(Coalesce $os.BuildNumber "unknown")
row "OS architecture"       $(Coalesce $os.OSArchitecture "unknown")
row "Primary owner"         $(Coalesce $cs.PrimaryOwnerName "unknown")

$sessionType = "Console"
if ($env:SESSIONNAME -match 'RDP') { $sessionType = "Remote Desktop (RDP)" }
elseif ($env:SESSIONNAME) { $sessionType = $env:SESSIONNAME }
row "Session name"          $sessionType

# ── 2. Login & Winlogon ───────────────────────────────────────────────────────
header "Login & Winlogon"

$winlogon = Get-Process winlogon -ErrorAction SilentlyContinue | Select-Object -First 1
row "winlogon.exe"          $(if ($winlogon) { "running (PID $($winlogon.Id))" } else { "not detected" })

$dwm = Get-Process dwm -ErrorAction SilentlyContinue | Select-Object -First 1
row "dwm.exe (DWM)"         $(if ($dwm) { "running (PID $($dwm.Id))" } else { "not detected" })

try {
    $lastLogon = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} `
                              -MaxEvents 5 -ErrorAction Stop |
                 Where-Object { $_.Properties[8].Value -in 2,10,11 } |
                 Select-Object -First 1
    if ($lastLogon) {
        $logonTypeMap = @{2='Interactive';3='Network';4='Batch';5='Service';7='Unlock';
                          10='RemoteInteractive';11='CachedInteractive'}
        $lt = $lastLogon.Properties[8].Value
        row "Last interactive logon type" "$lt ($(Coalesce $logonTypeMap[$lt] 'unknown'))"
    }
} catch {
    row "Last logon event" "not readable (needs admin)"
}

# ── 3. Session details ────────────────────────────────────────────────────────
header "Session Info"

row "Username"              $env:USERNAME
row "Domain / computer"     "$($env:USERDOMAIN) / $($env:COMPUTERNAME)"
row "Session ID"            $([System.Diagnostics.Process]::GetCurrentProcess().SessionId.ToString())

if (cmd_or 'qwinsta') {
    Write-Host ""
    dim "Active sessions (qwinsta):"
    try {
        $qwLines = qwinsta 2>$null
        foreach ($qwLine in $qwLines) {
            Write-Host "  $qwLine" -ForegroundColor DarkGray
        }
    } catch {}
}

# ── 4. Display compositor ─────────────────────────────────────────────────────
header "Display Compositor (DWM)"

row "Compositor"            "Desktop Window Manager (DWM)"

$dwmSvc = Get-Service -Name 'UxSms' -ErrorAction SilentlyContinue
if ($dwmSvc) {
    row "DWM service (UxSms)"   $dwmSvc.Status.ToString()
} else {
    row "DWM service"           "integrated (not a standalone service on Win10+)"
}

$dwmDll = "$env:SystemRoot\System32\dwmapi.dll"
if (Test-Path $dwmDll) {
    $dwmVer = (Get-Item $dwmDll).VersionInfo.ProductVersion
    row "dwmapi.dll version"    $(Coalesce $dwmVer "unknown")
}

try {
    $dwmReg = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' -ErrorAction Stop
    $composition = $dwmReg.Composition
    row "Composition (Aero)"    $(if ($null -ne $composition) { if ($composition -eq 1) { "enabled" } else { "disabled" } } else { "unknown" })
} catch {
    row "Composition (Aero)"    "unknown"
}

try {
    $hdrReg = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\VideoSettings' -ErrorAction Stop
    $hdrEnabled = $hdrReg.EnableHDROutput
    row "HDR output"            $(if ($hdrEnabled -eq 1) { "enabled" } elseif ($hdrEnabled -eq 0) { "disabled" } else { "unknown" })
} catch {
    row "HDR output"            "not configured / unknown"
}

# ── 5. Screen / Resolution ────────────────────────────────────────────────────
header "Screen / Resolution"

$vidCtrls = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue

foreach ($vc in $vidCtrls) {
    if ($vc.CurrentHorizontalResolution -and $vc.CurrentVerticalResolution) {
        row "Current resolution"    "$($vc.CurrentHorizontalResolution) x $($vc.CurrentVerticalResolution)"
        row "Refresh rate"          "$($vc.CurrentRefreshRate) Hz"
        row "Bits per pixel"        "$($vc.CurrentBitsPerPixel)"
    }
    break
}

$desktopMons = Get-CimInstance Win32_DesktopMonitor -ErrorAction SilentlyContinue
if ($desktopMons) {
    Write-Host ""
    dim "Connected monitors:"
    foreach ($mon in $desktopMons) {
        $monName = Coalesce (Coalesce $mon.Name $mon.Description) "Unknown Monitor"
        $monW    = Coalesce $mon.ScreenWidth  "?"
        $monH    = Coalesce $mon.ScreenHeight "?"
        Write-Host -NoNewline -ForegroundColor DarkGray "  $($monName.PadRight(30))"
        Write-Host "  $monW x $monH" -ForegroundColor White
    }
}

try {
    $monIds = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction Stop
    if ($monIds) {
        Write-Host ""
        dim "Physical monitor IDs:"
        foreach ($m in $monIds) {
            $mfr  = [System.Text.Encoding]::ASCII.GetString(
                        ($m.ManufacturerName | Where-Object { $_ -ne 0 })) -replace '\x00',''
            $prod = [System.Text.Encoding]::ASCII.GetString(
                        ($m.UserFriendlyName | Where-Object { $_ -ne 0 })) -replace '\x00',''
            $ser  = [System.Text.Encoding]::ASCII.GetString(
                        ($m.SerialNumberID   | Where-Object { $_ -ne 0 })) -replace '\x00',''
            $inst = $m.InstanceName -replace '\\.*$',''
            Write-Host -NoNewline -ForegroundColor DarkGray "  $($inst.PadRight(20))"
            Write-Host "  $mfr $prod$(if ($ser) { " [$ser]" })" -ForegroundColor White
        }
    }
} catch {}

try {
    $dpiReg  = Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction Stop
    $logPPIX = $dpiReg.LogPixels
    if ($logPPIX) { row "Logical DPI (registry)" "$logPPIX dpi" }
} catch {}

# ── 6. Graphics Hardware ───────────────────────────────────────────────────────
header "Graphics Hardware & DirectX"

foreach ($vc in $vidCtrls) {
    Write-Host ""
    dim "Video controller: $($vc.Name)"
    row "  Name"                $(Coalesce $vc.Name "unknown")
    row "  Driver version"      $(Coalesce $vc.DriverVersion "unknown")
    row "  Driver date"         $(if ($vc.DriverDate) { try { $vc.DriverDate.ToString('yyyy-MM-dd') } catch { 'unknown' } } else { 'unknown' })
    row "  Video RAM"           $(if ($vc.AdapterRAM) { "$([math]::Round($vc.AdapterRAM/1MB)) MB" } else { "unknown" })
    row "  Video processor"     $(Coalesce $vc.VideoProcessor "unknown")
    row "  Current mode"        $(Coalesce $vc.VideoModeDescription "unknown")
    row "  Status"              $(Coalesce $vc.Status "unknown")
    if ($vc.PNPDeviceID) { row "  PNP device ID" $vc.PNPDeviceID }
}

# dxdiag — use long temp path to avoid 8.3 path issues
$dxdiagPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "display_info_dxdiag.txt")
$dxRan = $false
if (cmd_or 'dxdiag') {
    try {
        Write-Host ""
        dim "Running dxdiag (this may take a few seconds)..."
        $dxProc = Start-Process dxdiag -ArgumentList "/t `"$dxdiagPath`"" `
                                -PassThru -WindowStyle Hidden
        $dxProc.WaitForExit(15000) | Out-Null
        if (Test-Path $dxdiagPath) { $dxRan = $true }
    } catch {}
}

if ($dxRan) {
    $dx = Get-Content $dxdiagPath -Raw -ErrorAction SilentlyContinue
    Write-Host ""
    dim "DirectX info (dxdiag):"

    function dxval([string]$content, [string]$label) {
        if ($content -match "(?m)^\s*$([regex]::Escape($label)):\s*(.+)$") {
            return $Matches[1].Trim()
        }
        return $null
    }

    $dxVer     = dxval $dx "DirectX Version"
    $dxFeature = dxval $dx "Feature Levels"
    $dxD3d9Ver = dxval $dx "D3D9 Version"
    $dxD3d10   = dxval $dx "D3D10 DDI Version"
    $dxD3d11   = dxval $dx "D3D11 DDI Version"
    $dxD3d12   = dxval $dx "D3D12 DDI Version"
    $dxVertBuf = dxval $dx "Vertex Shader Version"
    $dxPixShad = dxval $dx "Pixel Shader Version"

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

# NVIDIA via nvidia-smi
$nvidiaVcs = $vidCtrls | Where-Object { $_.Name -match 'NVIDIA' }
if ($nvidiaVcs -or (cmd_or 'nvidia-smi')) {
    Write-Host ""
    dim "NVIDIA GPU detected:"

    if (cmd_or 'nvidia-smi') {
        Write-Host ""
        dim "nvidia-smi:"

        try {
            $smiId = nvidia-smi --query-gpu=index,name,driver_version,vbios_version,pci.bus_id `
                                 --format=csv,noheader 2>$null
            foreach ($smiLine in $smiId) {
                $f = $smiLine -split ',\s*'
                if ($f.Count -ge 5) {
                    row "  GPU $($f[0])"        $f[1]
                    row "    Driver version"     $f[2]
                    row "    VBIOS version"      $f[3]
                    row "    PCI bus ID"         $f[4]
                }
            }
        } catch {}

        Write-Host ""; dim "  Memory:"
        try {
            $smiMem = nvidia-smi --query-gpu=index,memory.total,memory.used,memory.free `
                                  --format=csv,noheader 2>$null
            foreach ($smiLine in $smiMem) {
                $f = $smiLine -split ',\s*'
                if ($f.Count -ge 4) {
                    row "    GPU $($f[0])" "total $($f[1].PadRight(10))  used $($f[2].PadRight(10))  free $($f[3])"
                }
            }
        } catch {}

        Write-Host ""; dim "  Clocks:"
        try {
            $smiClk = nvidia-smi --query-gpu=index,clocks.gr,clocks.mem,clocks.sm,clocks.video `
                                  --format=csv,noheader 2>$null
            foreach ($smiLine in $smiClk) {
                $f = $smiLine -split ',\s*'
                if ($f.Count -ge 5) {
                    row "    GPU $($f[0])" "core $($f[1].PadRight(8))  mem $($f[2].PadRight(8))  sm $($f[3].PadRight(8))  video $($f[4])"
                }
            }
        } catch {}

        Write-Host ""; dim "  Thermals & power:"
        try {
            $smiTherm = nvidia-smi --query-gpu=index,temperature.gpu,fan.speed,power.draw,power.limit,power.management `
                                    --format=csv,noheader 2>$null
            foreach ($smiLine in $smiTherm) {
                $f = $smiLine -split ',\s*'
                if ($f.Count -ge 6) {
                    row "    GPU $($f[0])" "temp $($f[1]) C  fan $($f[2].PadRight(6))  draw $($f[3].PadRight(8))  limit $($f[4].PadRight(8))  mgmt $($f[5])"
                }
            }
        } catch {}

        Write-Host ""; dim "  Utilisation:"
        try {
            $smiUtil = nvidia-smi --query-gpu=index,utilization.gpu,utilization.memory,utilization.encoder,utilization.decoder `
                                   --format=csv,noheader 2>$null
            foreach ($smiLine in $smiUtil) {
                $f = $smiLine -split ',\s*'
                if ($f.Count -ge 5) {
                    row "    GPU $($f[0])" "gpu $($f[1].PadRight(6))  mem $($f[2].PadRight(6))  enc $($f[3].PadRight(6))  dec $($f[4])"
                }
            }
        } catch {}

        Write-Host ""; dim "  Capabilities & state:"
        try {
            $smiCap = nvidia-smi --query-gpu=index,compute_mode,pstate,ecc.mode.current,cuda_version `
                                  --format=csv,noheader 2>$null
            foreach ($smiLine in $smiCap) {
                $f = $smiLine -split ',\s*'
                if ($f.Count -ge 5) {
                    row "    Compute mode"   $f[1]
                    row "    Perf state"     $f[2]
                    row "    ECC mode"       $f[3]
                    row "    CUDA version"   $f[4]
                }
            }
        } catch {}
    } else {
        Write-Host "  nvidia-smi not found - install NVIDIA drivers or CUDA toolkit for full details" -ForegroundColor Red
    }
}

# Vulkan
if (cmd_or 'vulkaninfo') {
    Write-Host ""
    dim "Vulkan:"
    try {
        $vkOut = vulkaninfo --summary 2>$null |
                 Select-String 'GPU|driverVersion|apiVersion|deviceType' |
                 Select-Object -First 12
        foreach ($vkLine in $vkOut) {
            Write-Host "  $($vkLine.Line.TrimStart())" -ForegroundColor DarkGray
        }
    } catch {}
}

# OpenGL
$oglDll = "$env:SystemRoot\System32\opengl32.dll"
if (Test-Path $oglDll) {
    Write-Host ""
    dim "OpenGL (system opengl32.dll):"
    $oglVer = (Get-Item $oglDll).VersionInfo
    row "  opengl32.dll version"  $oglVer.ProductVersion
    row "  Note" "Full OpenGL caps require a vendor tool (e.g. GPU Caps Viewer)"
}

# ── 7. Miscellaneous ───────────────────────────────────────────────────────────
header "Miscellaneous"

row "User / SID"            "$env:USERNAME / $([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)"
row "Hostname"              $env:COMPUTERNAME
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
              [Security.Principal.WindowsBuiltInRole]::Administrator)
row "Running as admin"      $(if ($isAdmin) { "yes" } else { "no" })

row "OS"                    $(Coalesce $os.Caption "unknown")
row "OS version"            $(Coalesce $os.Version "unknown")
row "OS build"              $(Coalesce $os.BuildNumber "unknown")

row "PowerShell version"    $PSVersionTable.PSVersion.ToString()
row "CLR version"           $PSVersionTable.CLRVersion.ToString()

$lang = [System.Globalization.CultureInfo]::CurrentCulture
row "Locale / culture"      "$($lang.Name) ($($lang.DisplayName))"
row "UI culture"            $([System.Globalization.CultureInfo]::CurrentUICulture.Name)
row "Timezone"              $([System.TimeZoneInfo]::Local.DisplayName)

$bootTime = $os.LastBootUpTime
if ($bootTime) {
    $upspan = (Get-Date) - $bootTime
    row "Last boot"         $bootTime.ToString('yyyy-MM-dd HH:mm:ss')
    row "Uptime"            "$($upspan.Days)d $($upspan.Hours)h $($upspan.Minutes)m"
}

$dispEnvVars = @('DISPLAY','WAYLAND_DISPLAY','TERM','TERM_PROGRAM','WT_SESSION',
                 'ConEmuPID','SESSIONNAME','LOGONSERVER','APPDATA','TEMP')
Write-Host ""
dim "Relevant environment variables:"
foreach ($v in $dispEnvVars) {
    $envVal = [System.Environment]::GetEnvironmentVariable($v)
    row "  $v" $(Coalesce $envVal "not set")
}

Write-Host ""
hr
Write-Host ""
