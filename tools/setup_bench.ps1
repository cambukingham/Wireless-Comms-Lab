param([switch]$SkipShortcut)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$venvFolder = Join-Path $projectRoot '.venv'
$venvPython = Join-Path $venvFolder 'Scripts\python.exe'
$venvPythonW = Join-Path $venvFolder 'Scripts\pythonw.exe'

function Invoke-PythonChecked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed (exit $LASTEXITCODE)."
    }
}

try {
    if (-not (Test-Path -LiteralPath $venvPython)) {
        $basePython = $null
        $launcher = Get-Command py.exe -ErrorAction SilentlyContinue
        if ($launcher) {
            foreach ($version in @('-3.12', '-3.13', '-3.11')) {
                try {
                    $found = & $launcher.Source $version -c 'import sys; assert sys.maxsize > 2**32; print(sys.executable)' 2>$null
                } catch {
                    $found = $null
                }
                if ($LASTEXITCODE -eq 0 -and $found -and (Test-Path -LiteralPath $found)) {
                    $basePython = $found
                    break
                }
            }
        }
        if (-not $basePython) {
            $command = Get-Command python.exe -ErrorAction SilentlyContinue
            if ($command) {
                try {
                    $found = & $command.Source -c 'import sys; assert (3, 11) <= sys.version_info[:2] < (3, 14); assert sys.maxsize > 2**32; print(sys.executable)' 2>$null
                } catch {
                    $found = $null
                }
                if ($LASTEXITCODE -eq 0 -and $found -and (Test-Path -LiteralPath $found)) {
                    $basePython = $found
                }
            }
        }
        if (-not $basePython) {
            throw 'Install 64-bit Python 3.12 with Tcl/Tk and the Python launcher, then run setup again.'
        }
        Write-Host 'Creating a local Python environment...'
        Invoke-PythonChecked $basePython @('-m', 'venv', $venvFolder)
    }

    Write-Host 'Installing the bench analysis dependency...'
    Invoke-PythonChecked $venvPython @('-m', 'pip', 'install', '-r', (Join-Path $projectRoot 'requirements.txt'))
    Invoke-PythonChecked $venvPython @('-B', '-c', "import sys, tkinter, numpy; print('Python', sys.version.split()[0], '| Tk', tkinter.TkVersion, '| NumPy', numpy.__version__)")
    if (-not (Test-Path -LiteralPath $venvPythonW)) {
        throw 'The Python environment is missing pythonw.exe. Recreate it with Windows Python.'
    }

    if (-not $SkipShortcut) {
        $programsFolder = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'
        New-Item -ItemType Directory -Path $programsFolder -Force | Out-Null
        $shortcutPath = Join-Path $programsFolder 'WINLAB Bench.lnk'
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $venvPythonW
        $shortcut.Arguments = '"' + (Join-Path $projectRoot 'proteus_control\bench_panel.py') + '"'
        $shortcut.WorkingDirectory = Join-Path $projectRoot 'proteus_control'
        $shortcut.IconLocation = (Join-Path $projectRoot 'proteus_control\winlab-antenna.ico') + ',0'
        $shortcut.Description = 'WINLAB Proteus research bench'
        $shortcut.Save()
        Write-Host "Created Start-menu shortcut: $shortcutPath"
    }
    Write-Host 'The application is ready. Setup did not connect to the instrument.'
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
