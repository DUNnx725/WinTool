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
        $answer = (Read-Host ($Prompt + ' [S/N]')).Trim()

        if ($answer -match '^(?i:S|SI|SÍ|Y|YES)$') {
            return $true
        }

        if ($answer -match '^(?i:N|NO)$') {
            return $false
        }

        Write-Host 'Respuesta no valida. Escribi S o N.'
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

    if (Read-DriverYesNo -Prompt 'Abrir esta pagina') {
        try {
            Start-Process $Url
            Write-Host '[OK] Pagina oficial abierta.'
        }
        catch {
            Write-Host ('[ERROR] No se pudo abrir el navegador: ' + $_.Exception.Message)
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

# CAPA 1:
# Paginas exactas que fueron verificadas manualmente antes de incluirse.
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
                -Resolution 'PAGINA OFICIAL EXACTA' `
                -Confidence 'MUY ALTA' `
                -Note 'Pagina especifica de AMD para Ryzen 5 5600G.'
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
                -Resolution 'PAGINA OFICIAL EXACTA DEL APU' `
                -Confidence 'MUY ALTA' `
                -Note 'La grafica integrada usa la pagina oficial del Ryzen 5 5600G.'
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
                -Resolution 'PAGINA OFICIAL EXACTA' `
                -Confidence 'MUY ALTA' `
                -Note 'Pagina oficial especifica de soporte de la placa madre.'
        }
    }

    return $null
}

# CAPA 2:
# Catalogo local de modelos comunes. No guarda enlaces directos a instaladores.
# Para fabricantes con buscadores oficiales dinamicos, reconocer el modelo
# permite enviar al usuario al recurso oficial correcto sin inventar URLs.
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
                    -Resolution 'MODELO RECONOCIDO / BUSCADOR OFICIAL' `
                    -Confidence 'ALTA' `
                    -Note 'El modelo esta en el catalogo local; NVIDIA usa un buscador oficial por producto.'
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
                    -Resolution 'MODELO RECONOCIDO / DETECTOR OFICIAL' `
                    -Confidence 'ALTA' `
                    -Note 'El modelo esta en el catalogo local; Intel DSA ofrece soporte personalizado para hardware compatible.'
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
                    -Resolution 'MODELO RECONOCIDO / SOPORTE OFICIAL AMD' `
                    -Confidence 'ALTA' `
                    -Note 'Modelo Radeon reconocido; se usa el recurso oficial AMD para evitar construir una URL no verificada.'
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
                    -Resolution 'MODELO RECONOCIDO / SOPORTE OFICIAL AMD' `
                    -Confidence 'ALTA' `
                    -Note 'Procesador Ryzen reconocido; si no existe una pagina exacta validada, se usa el soporte oficial AMD.'
            }
        }
    }

    return $null
}

# CAPA 3:
# Reconoce familias o series aunque el modelo exacto no este en el catalogo.
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
                -Resolution 'FAMILIA / SERIE NVIDIA DETECTADA' `
                -Confidence 'ALTA' `
                -Note 'La serie fue detectada; el selector oficial permite elegir el producto exacto.'
        }
    }

    if ($Kind -eq 'CPU' -and $text -match '(?i)Intel') {
        if ($text -match '(?i)i[3579]-1[01234]\d{3}[A-Za-z]*|10th|11th|12th|13th|14th') {
            return New-DriverTarget `
                -Device $Name `
                -Manufacturer 'Intel' `
                -Url 'https://www.intel.com/content/www/us/en/support/detect.html' `
                -Layer 3 `
                -Resolution 'FAMILIA INTEL DETECTADA' `
                -Confidence 'MEDIA-ALTA' `
                -Note 'Familia Intel detectada; se usa el detector oficial para evitar una URL incorrecta.'
        }
    }

    if ($Kind -eq 'CPU' -and $text -match '(?i)Ryzen') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'AMD' `
            -Url 'https://www.amd.com/es/support/download/drivers.html' `
            -Layer 3 `
            -Resolution 'FAMILIA AMD RYZEN DETECTADA' `
            -Confidence 'MEDIA' `
            -Note 'Modelo Ryzen detectado; si no esta validado exactamente, WinTool usa el soporte oficial AMD.'
    }

    return $null
}

# CAPA 4:
# Buscador o detector oficial del fabricante.
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
            -Resolution 'BUSCADOR OFICIAL NVIDIA' `
            -Confidence 'MEDIA' `
            -Note 'Busqueda manual oficial por producto, serie y sistema operativo.'
    }

    if ($text -match '(?i)Intel') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'Intel' `
            -Url 'https://www.intel.com/content/www/us/en/support/detect.html' `
            -Layer 4 `
            -Resolution 'INTEL DRIVER & SUPPORT ASSISTANT' `
            -Confidence 'MEDIA' `
            -Note 'Detector oficial de Intel para la mayor parte del hardware Intel compatible.'
    }

    if ($text -match '(?i)AMD|Radeon') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'AMD' `
            -Url 'https://www.amd.com/es/support/download/drivers.html' `
            -Layer 4 `
            -Resolution 'BUSCADOR OFICIAL AMD' `
            -Confidence 'MEDIA' `
            -Note 'Soporte y deteccion oficial de AMD.'
    }

    return $null
}

# CAPA 5:
# Ultimo fallback. Solo soporte oficial; nunca sitios de terceros.
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
            -Resolution 'SOPORTE GENERAL OFICIAL' `
            -Confidence 'BASICA' `
            -Note 'No se encontro una pagina especifica validada para este modelo.'
    }

    if ($text -match '(?i)ASUSTeK|ASUS') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'ASUS' `
            -Url 'https://www.asus.com/ar/support/download-center/' `
            -Layer 5 `
            -Resolution 'CENTRO DE DESCARGAS OFICIAL' `
            -Confidence 'BASICA' `
            -Note 'Centro de descargas oficial ASUS.'
    }

    if ($text -match '(?i)Gigabyte') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'Gigabyte' `
            -Url 'https://www.gigabyte.com/Support' `
            -Layer 5 `
            -Resolution 'SOPORTE GENERAL OFICIAL' `
            -Confidence 'BASICA' `
            -Note 'Centro de soporte oficial Gigabyte.'
    }

    if ($text -match '(?i)ASRock') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'ASRock' `
            -Url 'https://www.asrock.com/support/' `
            -Layer 5 `
            -Resolution 'SOPORTE GENERAL OFICIAL' `
            -Confidence 'BASICA' `
            -Note 'Centro de soporte oficial ASRock.'
    }

    if ($text -match '(?i)NVIDIA|GeForce') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'NVIDIA' `
            -Url 'https://www.nvidia.com/es-la/drivers/' `
            -Layer 5 `
            -Resolution 'SOPORTE GENERAL OFICIAL' `
            -Confidence 'BASICA' `
            -Note 'Pagina oficial de drivers NVIDIA.'
    }

    if ($text -match '(?i)Intel') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'Intel' `
            -Url 'https://www.intel.com/content/www/us/en/support/detect.html' `
            -Layer 5 `
            -Resolution 'SOPORTE OFICIAL INTEL' `
            -Confidence 'BASICA' `
            -Note 'Intel Driver & Support Assistant.'
    }

    if ($text -match '(?i)AMD|Radeon') {
        return New-DriverTarget `
            -Device $Name `
            -Manufacturer 'AMD' `
            -Url 'https://www.amd.com/es/support' `
            -Layer 5 `
            -Resolution 'SOPORTE GENERAL OFICIAL' `
            -Confidence 'BASICA' `
            -Note 'Centro de soporte oficial AMD.'
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
        -Resolution 'SIN RESOLUCION SEGURA' `
        -Confidence 'NINGUNA' `
        -Note 'WinTool no encontro una URL oficial segura y no abrira sitios de terceros.'
}

function Show-DriverTarget {
    param(
        [Parameter(Mandatory=$true)]
        $Target,
        [switch]$Detailed
    )

    Write-Host $Target.Device
    Write-Host ($Target.Resolution + ' | Confianza: ' + $Target.Confidence)

    if ($Detailed) {
        Write-Host ('Fabricante......... ' + $Target.Manufacturer)
        Write-Host ('Capa utilizada...... ' + $Target.Layer)

        if (-not [string]::IsNullOrWhiteSpace([string]$Target.Note)) {
            Write-Host ('Detalle............. ' + $Target.Note)
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
        Write-Host 'BUSCAR DRIVERS OFICIALES'
        Write-Host
        Write-Host ('CPU................. ' + $hardware.CPU)

        if (@($hardware.GPUs).Count -gt 0) {
            Write-Host ('GPU................. ' + ($hardware.GPUs -join ' | '))
        }
        else {
            Write-Host 'GPU................. NO DETECTADA'
        }

        Write-Host ('Placa madre......... ' + $hardware.BoardManufacturer + ' ' + $hardware.BoardProduct)
        Write-Host
        Write-Host '[1] Procesador / APU'
        Write-Host '[2] GPU'
        Write-Host '[3] Placa madre'
        Write-Host '[4] Ver detalles de resolucion'
        Write-Host '[5] Abrir paginas recomendadas'
        Write-Host '[0] Volver'
        Write-Host

        $choice = (Read-Host 'Elegir').Trim()

        switch ($choice) {
            '0' {
                return
            }

            '1' {
                Clear-Host
                Write-Host 'PROCESADOR / APU'
                Write-Host
                Show-DriverTarget -Target $cpuTarget

                if (-not [string]::IsNullOrWhiteSpace([string]$cpuTarget.Url)) {
                    Open-DriverOfficialUrl -Url $cpuTarget.Url -Label $cpuTarget.Resolution
                }

                Write-Host
                [void](Read-Host 'Presiona ENTER para continuar')
            }

            '2' {
                Clear-Host
                Write-Host 'GPU'
                Write-Host

                if (@($gpuTargets).Count -eq 0) {
                    Write-Host '[INFO] No se detecto una GPU.'
                    [void](Read-Host 'Presiona ENTER para continuar')
                    continue
                }

                for ($index = 0; $index -lt @($gpuTargets).Count; $index++) {
                    Write-Host ('[' + ($index + 1) + '] ' + $gpuTargets[$index].Device)
                }

                Write-Host '[0] Volver'
                Write-Host

                $gpuChoice = (Read-Host 'Elegir').Trim()

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
                        [void](Read-Host 'Presiona ENTER para continuar')
                    }
                }
            }

            '3' {
                Clear-Host
                Write-Host 'PLACA MADRE'
                Write-Host
                Show-DriverTarget -Target $boardTarget

                if (-not [string]::IsNullOrWhiteSpace([string]$boardTarget.Url)) {
                    Open-DriverOfficialUrl -Url $boardTarget.Url -Label $boardTarget.Resolution
                }

                Write-Host
                [void](Read-Host 'Presiona ENTER para continuar')
            }

            '4' {
                Clear-Host
                Write-Host 'DETALLES DE RESOLUCION'
                Write-Host
                Write-Host '1. Pagina oficial exacta validada'
                Write-Host '2. Catalogo local de modelos comunes'
                Write-Host '3. Familia / serie detectada'
                Write-Host '4. Buscador o detector oficial'
                Write-Host '5. Soporte general oficial'
                Write-Host
                Write-Host 'CPU'
                Show-DriverTarget -Target $cpuTarget -Detailed
                Write-Host
                Write-Host 'GPU'

                foreach ($gpuTarget in @($gpuTargets)) {
                    Show-DriverTarget -Target $gpuTarget -Detailed
                    Write-Host
                }

                Write-Host 'PLACA MADRE'
                Show-DriverTarget -Target $boardTarget -Detailed
                Write-Host
                [void](Read-Host 'Presiona ENTER para continuar')
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
                [void](Read-Host 'Presiona ENTER para continuar')
            }
        }
    }
}

# Modos originales de drivers de WinTool conservados.
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
    Write-Host 'Abriendo Windows Update > Actualizaciones opcionales.'
    Start-Process 'ms-settings:windowsupdate-optionalupdates'
    exit
}

$computerSystem = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS

if ($Mode -eq 'BIOS') {
    Write-Host ('Fabricante: ' + $computerSystem.Manufacturer)
    Write-Host ('Modelo: ' + $computerSystem.Model)
    Write-Host ('BIOS: ' + $bios.SMBIOSBIOSVersion + ' | ' + $bios.ReleaseDate)
    Write-Host 'WinTool no descarga ni instala BIOS automaticamente.'
    exit
}

if ($Mode -eq 'Official') {
    Invoke-OfficialDriverFinder
    exit
}
