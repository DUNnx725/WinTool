param(
    [ValidateSet('Scan','WindowsUpdate','Backup','Official','BIOS')]
    [string]$Mode,
    [string]$BackupDir
)

$ErrorActionPreference = 'Stop'

function Read-DriverYesNo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt
    )

    while ($true) {
        $answer = (Read-Host ($Prompt + ' [Y/N]')).Trim()

        if ($answer -match '^(?i:Y|YES|S|SI|SÍ)$') {
            return $true
        }

        if ($answer -match '^(?i:N|NO)$') {
            return $false
        }

        Write-Host 'Invalid response. Enter Y or N.'
    }
}

function Open-DriverOfficialUrl {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$Label
    )

    Write-Host
    Write-Host ('OFICIAL: ' + $Label)
    Write-Host $Url

    if (Read-DriverYesNo -Prompt 'Open this page') {
        try {
            Start-Process $Url
            Write-Host '[OK] Official page opened.'
        }
        catch {
            Write-Host ('[ERROR] Could not open the browser: ' + $_.Exception.Message)
        }
    }
}

function New-DriverTarget {
    param(
        [string]$Device,
        [string]$Manufacturer,
        [string]$Url,
        [int]$Layer,
        [string]$Resolution,
        [string]$Confidence,
        [string]$Note
    )

    return [pscustomobject]@{
        Device       = $Device
        Manufacturer = $Manufacturer
        Url          = $Url
        Layer        = $Layer
        Resolution   = $Resolution
        Confidence   = $Confidence
        Note         = $Note
    }
}

function Get-DriverHardwareInfo {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name })
    $system = Get-CimInstance Win32_ComputerSystem
    $board = Get-CimInstance Win32_BaseBoard | Select-Object -First 1

    $boardManufacturer = [string]$board.Manufacturer
    $boardProduct = [string]$board.Product

    if ([string]::IsNullOrWhiteSpace($boardManufacturer)) {
        $boardManufacturer = [string]$system.Manufacturer
    }

    if (
        [string]::IsNullOrWhiteSpace($boardProduct) -or
        $boardProduct -match '^(?i:Base Board|Default string|To be filled)'
    ) {
        $boardProduct = [string]$system.Model
    }

    return [pscustomobject]@{
        CPU                = [string]$cpu.Name
        GPUs               = @($gpus | ForEach-Object { [string]$_.Name })
        BoardManufacturer  = $boardManufacturer
        BoardProduct       = $boardProduct
        SystemManufacturer = [string]$system.Manufacturer
        SystemModel        = [string]$system.Model
    }
}

# LAYER 1:
# Exact pages manually validated before inclusion.
function Resolve-DriverExactTarget {
    param(
        [ValidateSet('CPU','GPU','BOARD')]
        [string]$Kind,
        [string]$Name,
        [string]$Manufacturer = '',
        [string]$SystemModel = '',
        [string]$CpuName = ''
    )

    if ($Kind -eq 'CPU') {
        if ($Name -match '(?i)\bRyzen\s+5\s+5600G\b') {
            return New-DriverTarget `
                -Device 'AMD Ryzen 5 5600G' `
                -Manufacturer 'AMD' `
                -Url 'https://www.amd.com/es/support/downloads/drivers.html/processors/ryzen/ryzen-5000-series/amd-ryzen-5-5600g.html' `
                -Layer 1 `
                -Resolution 'EXACT OFFICIAL PAGE' `
                -Confidence 'VERY HIGH' `
                -Note 'AMD-specific page for Ryzen 5 5600G.'
        }
    }

    if ($Kind -eq 'GPU') {
        if (
            $Name -match '(?i)AMD Radeon\(TM\) Graphics|AMD Radeon Graphics' -and
            $CpuName -match '(?i)\bRyzen\s+5\s+5600G\b'
        ) {
            return New-DriverTarget `
                -Device 'AMD Radeon Graphics integrada - Ryzen 5 5600G' `
                -Manufacturer 'AMD' `
                -Url 'https://www.amd.com/es/support/downloads/drivers.html/processors/ryzen/ryzen-5000-series/amd-ryzen-5-5600g.html' `
                -Layer 1 `
                -Resolution 'EXACT OFFICIAL APU PAGE' `
                -Confidence 'VERY HIGH' `
                -Note 'The integrated graphics uses the official Ryzen 5 5600G page.'
        }
    }

    if ($Kind -eq 'BOARD') {
        if (
            ($Manufacturer -match '(?i)Micro-Star|MSI') -and
            (
                $Name -match '(?i)^A520M-A\s+PRO$' -or
                $Name -match '(?i)^MS-7C96$' -or
                $SystemModel -match '(?i)^MS-7C96$'
            )
        ) {
            return New-DriverTarget `
                -Device 'MSI A520M-A PRO' `
                -Manufacturer 'MSI' `
                -Url 'https://www.msi.com/Motherboard/A520M-A-PRO/support' `
                -Layer 1 `
                -Resolution 'EXACT OFFICIAL PAGE' `
                -Confidence 'VERY HIGH' `
                -Note 'Exact official motherboard support page.'
        }
    }

    return $null
}

# LAYER 2:
# Local catalog of common models. It does not store direct installer links.
# For manufacturers with dynamic official finders, recognizing the model
# allows WinTool to use the correct official resource without inventing URLs.
function Resolve-DriverLocalCatalog {
    param(
        [ValidateSet('CPU','GPU','BOARD')]
        [string]$Kind,
        [string]$Name
    )

    if ($Kind -eq 'GPU') {
        $nvidiaModels = @(
            'GTX 1050','GTX 1050 Ti','GTX 1060','GTX 1070','GTX 1070 Ti','GTX 1080','GTX 1080 Ti',
            'GTX 1630','GTX 1650','GTX 1650 SUPER','GTX 1660','GTX 1660 Ti','GTX 1660 SUPER',
            'RTX 2060','RTX 2060 SUPER','RTX 2070','RTX 2070 SUPER','RTX 2080','RTX 2080 SUPER','RTX 2080 Ti',
            'RTX 3050','RTX 3060','RTX 3060 Ti','RTX 3070','RTX 3070 Ti','RTX 3080','RTX 3080 Ti','RTX 3090','RTX 3090 Ti',
            'RTX 4060','RTX 4060 Ti','RTX 4070','RTX 4070 SUPER','RTX 4070 Ti','RTX 4070 Ti SUPER',
            'RTX 4080','RTX 4080 SUPER','RTX 4090',
            'RTX 5050','RTX 5060','RTX 5060 Ti','RTX 5070','RTX 5070 Ti','RTX 5080','RTX 5090'
        )

        foreach ($model in $nvidiaModels) {
            if ($Name -match [regex]::Escape($model)) {
                return New-DriverTarget `
                    -Device ('NVIDIA GeForce ' + $model) `
                    -Manufacturer 'NVIDIA' `
                    -Url 'https://www.nvidia.com/es-la/geforce/drivers/' `
                    -Layer 2 `
                    -Resolution 'RECOGNIZED MODEL / OFFICIAL FINDER' `
                    -Confidence 'HIGH' `
                    -Note 'The model is in the local catalog; NVIDIA uses an official product finder.'
            }
        }
    }

    if ($Kind -eq 'CPU') {
        $intelModels = @(
            'i3-10100','i3-10100F','i5-10400','i5-10400F','i5-10600K','i5-10600KF','i7-10700','i7-10700K','i9-10900','i9-10900K',
            'i3-11100','i5-11400','i5-11400F','i5-11600K','i5-11600KF','i7-11700','i7-11700K','i9-11900','i9-11900K',
            'i3-12100','i3-12100F','i5-12400','i5-12400F','i5-12500','i5-12600K','i5-12600KF','i7-12700','i7-12700K','i9-12900','i9-12900K',
            'i3-13100','i3-13100F','i5-13400','i5-13400F','i5-13500','i5-13600K','i5-13600KF','i7-13700','i7-13700K','i9-13900','i9-13900K',
            'i3-14100','i3-14100F','i5-14400','i5-14400F','i5-14500','i5-14600K','i5-14600KF','i7-14700','i7-14700K','i9-14900','i9-14900K',
            'Ultra 5 225','Ultra 5 225F','Ultra 5 245K','Ultra 5 245KF',
            'Ultra 7 265','Ultra 7 265F','Ultra 7 265K','Ultra 7 265KF','Ultra 9 285K'
        )

        foreach ($model in $intelModels) {
            if ($Name -match [regex]::Escape($model)) {
                return New-DriverTarget `
                    -Device ('Intel Core ' + $model) `
                    -Manufacturer 'Intel' `
                    -Url 'https://www.intel.com/content/www/us/en/support/detect.html' `
                    -Layer 2 `
                    -Resolution 'RECOGNIZED MODEL / OFFICIAL DETECTOR' `
                    -Confidence 'HIGH' `
                    -Note 'The model is in the local catalog; Intel DSA provides personalized support for compatible hardware.'
            }
        }
    }


    if ($Kind -eq 'GPU') {
        $amdGpuModels = @(
            'RX 570','RX 580','RX 590',
            'RX 5500 XT','RX 5600 XT','RX 5700','RX 5700 XT',
            'RX 6400','RX 6500 XT','RX 6600','RX 6600 XT','RX 6650 XT',
            'RX 6700','RX 6700 XT','RX 6750 XT','RX 6800','RX 6800 XT','RX 6900 XT','RX 6950 XT',
            'RX 7600','RX 7600 XT','RX 7700 XT','RX 7800 XT','RX 7900 GRE','RX 7900 XT','RX 7900 XTX',
            'RX 9060 XT','RX 9070','RX 9070 XT'
        )

        foreach ($model in $amdGpuModels) {
            if ($Name -match [regex]::Escape($model)) {
                return New-DriverTarget `
                    -Device ('AMD Radeon ' + $model) `
                    -Manufacturer 'AMD' `
                    -Url 'https://www.amd.com/es/support/download/drivers.html' `
                    -Layer 2 `
                    -Resolution 'RECOGNIZED MODEL / OFFICIAL AMD SUPPORT' `
                    -Confidence 'HIGH' `
                    -Note "Radeon model recognized; WinTool uses AMD's official resource instead of constructing an unverified URL."
            }
        }
    }

    if ($Kind -eq 'CPU') {
        $amdCpuModels = @(
            'Ryzen 3 3100','Ryzen 3 3300X','Ryzen 5 3500','Ryzen 5 3600','Ryzen 5 3600X','Ryzen 7 3700X','Ryzen 7 3800X','Ryzen 9 3900X','Ryzen 9 3950X',
            'Ryzen 3 4100','Ryzen 5 4500','Ryzen 5 4600G','Ryzen 5 4600GE','Ryzen 7 4700G','Ryzen 7 4700GE',
            'Ryzen 5 5500','Ryzen 5 5600','Ryzen 5 5600X','Ryzen 5 5600G','Ryzen 7 5700G','Ryzen 7 5700X','Ryzen 7 5800X','Ryzen 7 5800X3D','Ryzen 9 5900X','Ryzen 9 5950X',
            'Ryzen 5 7500F','Ryzen 5 7600','Ryzen 5 7600X','Ryzen 7 7700','Ryzen 7 7700X','Ryzen 7 7800X3D','Ryzen 9 7900','Ryzen 9 7900X','Ryzen 9 7900X3D','Ryzen 9 7950X','Ryzen 9 7950X3D',
            'Ryzen 5 8500G','Ryzen 5 8600G','Ryzen 7 8700G',
            'Ryzen 5 9600X','Ryzen 7 9700X','Ryzen 7 9800X3D','Ryzen 9 9900X','Ryzen 9 9900X3D','Ryzen 9 9950X','Ryzen 9 9950X3D'
        )

        foreach ($model in $amdCpuModels) {
            if ($Name -match [regex]::Escape($model)) {
                return New-DriverTarget `
                    -Device ('AMD ' + $model) `
                    -Manufacturer 'AMD' `
                    -Url 'https://www.amd.com/es/support/download/drivers.html' `
                    -Layer 2 `
                    -Resolution 'RECOGNIZED MODEL / OFFICIAL AMD SUPPORT' `
                    -Confidence 'HIGH' `
                    -Note 'Ryzen processor recognized; if no exact validated page is available, WinTool uses official AMD support.'
            }
        }
    }

    return $null
}

# LAYER 3:
# Recognizes families or series even when the exact model is not in the catalog.
function Resolve-DriverFamilyTarget {
    param(
        [ValidateSet('CPU','GPU','BOARD')]
        [string]$Kind,
        [string]$Name,
        [string]$Manufacturer = ''
    )

    $text = $Name + ' ' + $Manufacturer

    if ($Kind -eq 'GPU' -and $text -match '(?i)NVIDIA|GeForce') {
        if ($text -match '(?i)RTX\s+50|RTX\s+40|RTX\s+30|RTX\s+20|GTX\s+16|GTX\s+10') {
            return New-DriverTarget `
                -Device $Name `
                -Manufacturer 'NVIDIA' `
                -Url 'https://www.nvidia.com/es-la/geforce/drivers/' `
                -Layer 3 `
                -Resolution 'NVIDIA FAMILY / SERIES DETECTED' `
                -Confidence 'HIGH' `
                -Note 'The series was detected; the official selector lets you choose the exact product.'
        }
    }

    if ($Kind -eq 'CPU' -and $text -match '(?i)Intel') {
        if ($text -match '(?i)i[3579]-1[01234]\d{3}[A-Za-z]*|10th|11th|12th|13th|14th') {
            return New-DriverTarget `
                -Device $Name `
                -Manufacturer 'Intel' `
                -Url 'https://www.intel.com/content/www/us/en/support/detect.html' `
                -Layer 3 `
                -Resolution 'INTEL FAMILY DETECTED' `
                -Confidence 'MEDIUM-HIGH' `
                -Note 'Intel family detected; the official detector is used to avoid an incorrect URL.'
        }
    }

    if ($Kind -eq 'CPU' -and $text -match '(?i)Ryzen') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'AMD' `
            -Url 'https://www.amd.com/es/support/download/drivers.html' `
            -Layer 3 `
            -Resolution 'AMD RYZEN FAMILY DETECTED' `
            -Confidence 'MEDIUM' `
            -Note 'Ryzen model detected; when it is not exactly validated, WinTool uses official AMD support.'
    }

    return $null
}

# LAYER 4:
# Manufacturer official finder or detector.
function Resolve-DriverOfficialFinder {
    param(
        [ValidateSet('CPU','GPU','BOARD')]
        [string]$Kind,
        [string]$Name,
        [string]$Manufacturer = ''
    )

    $text = $Name + ' ' + $Manufacturer

    if ($text -match '(?i)NVIDIA|GeForce') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'NVIDIA' `
            -Url 'https://www.nvidia.com/es-la/geforce/drivers/' `
            -Layer 4 `
            -Resolution 'OFFICIAL NVIDIA FINDER' `
            -Confidence 'MEDIUM' `
            -Note 'Official manual search by product, series, and operating system.'
    }

    if ($text -match '(?i)Intel') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'Intel' `
            -Url 'https://www.intel.com/content/www/us/en/support/detect.html' `
            -Layer 4 `
            -Resolution 'INTEL DRIVER & SUPPORT ASSISTANT' `
            -Confidence 'MEDIUM' `
            -Note "Intel's official detector for most compatible Intel hardware."
    }

    if ($text -match '(?i)AMD|Radeon') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'AMD' `
            -Url 'https://www.amd.com/es/support/download/drivers.html' `
            -Layer 4 `
            -Resolution 'OFFICIAL AMD FINDER' `
            -Confidence 'MEDIUM' `
            -Note 'Official AMD support and detection.'
    }

    return $null
}

# LAYER 5:
# Final fallback. Official support only; never third-party sites.
function Resolve-DriverGeneralSupport {
    param(
        [ValidateSet('CPU','GPU','BOARD')]
        [string]$Kind,
        [string]$Name,
        [string]$Manufacturer = ''
    )

    $text = $Name + ' ' + $Manufacturer

    if ($text -match '(?i)Micro-Star|MSI') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'MSI' `
            -Url 'https://www.msi.com/support' `
            -Layer 5 `
            -Resolution 'OFFICIAL GENERAL SUPPORT' `
            -Confidence 'BASIC' `
            -Note 'No validated model-specific page was found.'
    }

    if ($text -match '(?i)ASUSTeK|ASUS') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'ASUS' `
            -Url 'https://www.asus.com/ar/support/download-center/' `
            -Layer 5 `
            -Resolution 'OFFICIAL DOWNLOAD CENTER' `
            -Confidence 'BASIC' `
            -Note 'Official ASUS download center.'
    }

    if ($text -match '(?i)Gigabyte') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'Gigabyte' `
            -Url 'https://www.gigabyte.com/Support' `
            -Layer 5 `
            -Resolution 'OFFICIAL GENERAL SUPPORT' `
            -Confidence 'BASIC' `
            -Note 'Official Gigabyte support center.'
    }

    if ($text -match '(?i)ASRock') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'ASRock' `
            -Url 'https://www.asrock.com/support/' `
            -Layer 5 `
            -Resolution 'OFFICIAL GENERAL SUPPORT' `
            -Confidence 'BASIC' `
            -Note 'Official ASRock support center.'
    }

    if ($text -match '(?i)NVIDIA|GeForce') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'NVIDIA' `
            -Url 'https://www.nvidia.com/es-la/drivers/' `
            -Layer 5 `
            -Resolution 'OFFICIAL GENERAL SUPPORT' `
            -Confidence 'BASIC' `
            -Note 'Official NVIDIA driver page.'
    }

    if ($text -match '(?i)Intel') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'Intel' `
            -Url 'https://www.intel.com/content/www/us/en/support/detect.html' `
            -Layer 5 `
            -Resolution 'OFFICIAL INTEL SUPPORT' `
            -Confidence 'BASIC' `
            -Note 'Intel Driver & Support Assistant.'
    }

    if ($text -match '(?i)AMD|Radeon') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'AMD' `
            -Url 'https://www.amd.com/es/support' `
            -Layer 5 `
            -Resolution 'OFFICIAL GENERAL SUPPORT' `
            -Confidence 'BASIC' `
            -Note 'Official AMD support center.'
    }

    return $null
}

function Resolve-OfficialDriverTarget {
    param(
        [ValidateSet('CPU','GPU','BOARD')]
        [string]$Kind,
        [string]$Name,
        [string]$Manufacturer = '',
        [string]$SystemModel = '',
        [string]$CpuName = ''
    )

    $target = Resolve-DriverExactTarget `
        -Kind $Kind `
        -Name $Name `
        -Manufacturer $Manufacturer `
        -SystemModel $SystemModel `
        -CpuName $CpuName

    if ($null -ne $target) {
        return $target
    }

    $target = Resolve-DriverLocalCatalog -Kind $Kind -Name $Name
    if ($null -ne $target) {
        return $target
    }

    $target = Resolve-DriverFamilyTarget -Kind $Kind -Name $Name -Manufacturer $Manufacturer
    if ($null -ne $target) {
        return $target
    }

    $target = Resolve-DriverOfficialFinder -Kind $Kind -Name $Name -Manufacturer $Manufacturer
    if ($null -ne $target) {
        return $target
    }

    $target = Resolve-DriverGeneralSupport -Kind $Kind -Name $Name -Manufacturer $Manufacturer
    if ($null -ne $target) {
        return $target
    }

    return New-DriverTarget `
        -Device $Name `
        -Manufacturer $Manufacturer `
        -Url '' `
        -Layer 0 `
        -Resolution 'NO SAFE MATCH' `
        -Confidence 'NONE' `
        -Note 'WinTool did not find a safe official URL and will not open third-party sites.'
}

function Show-DriverTarget {
    param(
        [Parameter(Mandatory=$true)]
        $Target,
        [switch]$Detailed
    )

    Write-Host $Target.Device
    Write-Host ($Target.Resolution + ' | Confidence: ' + $Target.Confidence)

    if ($Detailed) {
        Write-Host ('Manufacturer....... ' + $Target.Manufacturer)
        Write-Host ('Layer used......... ' + $Target.Layer)

        if (-not [string]::IsNullOrWhiteSpace([string]$Target.Note)) {
            Write-Host ('Details............ ' + $Target.Note)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Target.Url)) {
        Write-Host $Target.Url
    }
}

function Invoke-OfficialDriverFinder {
    $hardware = Get-DriverHardwareInfo

    $cpuTarget = Resolve-OfficialDriverTarget `
        -Kind 'CPU' `
        -Name $hardware.CPU `
        -Manufacturer $hardware.SystemManufacturer `
        -SystemModel $hardware.SystemModel `
        -CpuName $hardware.CPU

    $gpuTargets = @()

    foreach ($gpuName in @($hardware.GPUs)) {
        $gpuTargets += Resolve-OfficialDriverTarget `
            -Kind 'GPU' `
            -Name $gpuName `
            -Manufacturer $gpuName `
            -SystemModel $hardware.SystemModel `
            -CpuName $hardware.CPU
    }

    $boardTarget = Resolve-OfficialDriverTarget `
        -Kind 'BOARD' `
        -Name $hardware.BoardProduct `
        -Manufacturer $hardware.BoardManufacturer `
        -SystemModel $hardware.SystemModel `
        -CpuName $hardware.CPU

    while ($true) {
        Clear-Host
        Write-Host 'OFFICIAL DRIVER FINDER'
        Write-Host
        Write-Host ('CPU................. ' + $hardware.CPU)

        if (@($hardware.GPUs).Count -gt 0) {
            Write-Host ('GPU................. ' + ($hardware.GPUs -join ' | '))
        }
        else {
            Write-Host 'GPU................. NOT DETECTED'
        }

        Write-Host ('Motherboard......... ' + $hardware.BoardManufacturer + ' ' + $hardware.BoardProduct)
        Write-Host
        Write-Host '[1] Processor / APU'
        Write-Host '[2] GPU'
        Write-Host '[3] Motherboard'
        Write-Host '[4] View resolution details'
        Write-Host '[5] Open recommended pages'
        Write-Host '[0] Back'
        Write-Host

        $choice = (Read-Host 'Choose').Trim()

        switch ($choice) {
            '0' {
                return
            }

            '1' {
                Clear-Host
                Write-Host 'PROCESSOR / APU'
                Write-Host
                Show-DriverTarget -Target $cpuTarget

                if (-not [string]::IsNullOrWhiteSpace([string]$cpuTarget.Url)) {
                    Open-DriverOfficialUrl -Url $cpuTarget.Url -Label $cpuTarget.Resolution
                }

                Write-Host
                [void](Read-Host 'Press ENTER to continue')
            }

            '2' {
                Clear-Host
                Write-Host 'GPU'
                Write-Host

                if (@($gpuTargets).Count -eq 0) {
                    Write-Host '[INFO] No GPU was detected.'
                    [void](Read-Host 'Press ENTER to continue')
                    continue
                }

                for ($index = 0; $index -lt @($gpuTargets).Count; $index++) {
                    Write-Host ('[' + ($index + 1) + '] ' + $gpuTargets[$index].Device)
                }

                Write-Host '[0] Back'
                Write-Host

                $gpuChoice = (Read-Host 'Choose').Trim()

                if ($gpuChoice -eq '0') {
                    continue
                }

                $selected = 0

                if ([int]::TryParse($gpuChoice, [ref]$selected)) {
                    $selected--

                    if ($selected -ge 0 -and $selected -lt @($gpuTargets).Count) {
                        Clear-Host
                        Write-Host 'GPU'
                        Write-Host
                        Show-DriverTarget -Target $gpuTargets[$selected]

                        if (-not [string]::IsNullOrWhiteSpace([string]$gpuTargets[$selected].Url)) {
                            Open-DriverOfficialUrl `
                                -Url $gpuTargets[$selected].Url `
                                -Label $gpuTargets[$selected].Resolution
                        }

                        Write-Host
                        [void](Read-Host 'Press ENTER to continue')
                    }
                }
            }

            '3' {
                Clear-Host
                Write-Host 'MOTHERBOARD'
                Write-Host
                Show-DriverTarget -Target $boardTarget

                if (-not [string]::IsNullOrWhiteSpace([string]$boardTarget.Url)) {
                    Open-DriverOfficialUrl -Url $boardTarget.Url -Label $boardTarget.Resolution
                }

                Write-Host
                [void](Read-Host 'Press ENTER to continue')
            }

            '4' {
                Clear-Host
                Write-Host 'RESOLUTION DETAILS'
                Write-Host
                Write-Host '1. Validated exact official page'
                Write-Host '2. Local catalog of common models'
                Write-Host '3. Detected family / series'
                Write-Host '4. Official finder or detector'
                Write-Host '5. Official general support'
                Write-Host
                Write-Host 'CPU'
                Show-DriverTarget -Target $cpuTarget -Detailed
                Write-Host
                Write-Host 'GPU'

                foreach ($gpuTarget in @($gpuTargets)) {
                    Show-DriverTarget -Target $gpuTarget -Detailed
                    Write-Host
                }

                Write-Host 'MOTHERBOARD'
                Show-DriverTarget -Target $boardTarget -Detailed
                Write-Host
                [void](Read-Host 'Press ENTER to continue')
            }

            '5' {
                $targets = @($cpuTarget) + @($gpuTargets) + @($boardTarget)
                $openedUrls = @()

                foreach ($target in $targets) {
                    if ([string]::IsNullOrWhiteSpace([string]$target.Url)) {
                        continue
                    }

                    if ($openedUrls -contains $target.Url) {
                        continue
                    }

                    Open-DriverOfficialUrl `
                        -Url $target.Url `
                        -Label ($target.Device + ' - ' + $target.Resolution)

                    $openedUrls += $target.Url
                }

                Write-Host
                [void](Read-Host 'Press ENTER to continue')
            }
        }
    }
}

# Original WinTool driver modes preserved.
if ($Mode -eq 'Scan') {
    Get-CimInstance Win32_PnPSignedDriver |
        Where-Object { $_.DeviceName -and $_.DriverVersion } |
        Sort-Object DeviceName |
        Select-Object DeviceName,Manufacturer,DriverVersion,@{N='Fecha';E={$_.DriverDate}} |
        Format-Table -AutoSize
    exit
}

if ($Mode -eq 'Backup') {
    $destination = Join-Path $BackupDir ('Drivers_' + (Get-Date -Format yyyyMMdd_HHmmss))
    New-Item $destination -ItemType Directory -Force | Out-Null
    pnputil /export-driver * $destination
    Write-Host ('Backup: ' + $destination)
    exit
}

if ($Mode -eq 'WindowsUpdate') {
    Write-Host 'Opening Windows Update > Optional updates.'
    Start-Process 'ms-settings:windowsupdate-optionalupdates'
    exit
}

$computerSystem = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS

if ($Mode -eq 'BIOS') {
    Write-Host ('Manufacturer: ' + $computerSystem.Manufacturer)
    Write-Host ('Model: ' + $computerSystem.Model)
    Write-Host ('BIOS: ' + $bios.SMBIOSBIOSVersion + ' | ' + $bios.ReleaseDate)
    Write-Host 'WinTool does not automatically download or install BIOS updates.'
    exit
}

if ($Mode -eq 'Official') {
    Invoke-OfficialDriverFinder
    exit
}
