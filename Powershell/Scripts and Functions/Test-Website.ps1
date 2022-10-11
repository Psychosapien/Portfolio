function Test-Website {
    [CmdletBinding()]
    param (
        [string]$Url,
        [string]$testCount = 1000
    )
    
    begin {
        Write-Host `n"$Url test commencing..." -ForegroundColor Cyan

        $Result = New-Object psobject
        add-member -InputObject $Result -MemberType NoteProperty -Name Time -Value ""
        add-member -InputObject $Result -MemberType NoteProperty -Name Response -Value ""
        add-member -InputObject $Result -MemberType NoteProperty -Name ResponseTime -Value ""

        $ResultsArray = @()
    }
    
    process {
        for ($i = 0; $i -lt $testCount; $i++) {

            $progresspreference = "silentlyContinue"
            
            $Result = New-Object psobject
            add-member -InputObject $Result -MemberType NoteProperty -Name Time -Value ""
            add-member -InputObject $Result -MemberType NoteProperty -Name Response -Value ""
            add-member -InputObject $Result -MemberType NoteProperty -Name ResponseTime -Value ""
    
            $ResponseTime = Measure-Command -Expression { $status = Invoke-WebRequest -UseBasicParsing -Uri $URL -TimeoutSec 60 -ErrorAction SilentlyContinue }

            $timestamp = $status.Headers.date.split(" ")
            $Result.Time = $timestamp[$timestamp.count - 2]

            $Result.Response = $status.statusCode

            $Result.ResponseTime = $ResponseTime.Milliseconds

            $ResultsArray += $Result

            $progresspreference = "Continue"

            Write-Host "------------------------------------"
            
            if ($status.statusCode -eq 200) {
                Write-Host "Website up" -ForegroundColor Green
                Write-Host "Response time: $($ResponseTime.Milliseconds) ms" -ForegroundColor Yellow
                Write-Host "Status: $($status.statusCode)" -ForegroundColor Yellow
            }
            else {
                Write-Host "WEBSITE DOWN!" -ForegroundColor Red
                Write-Host "Status: $($status.statusCode)" -ForegroundColor Yellow
            }
            

            Write-Progress -Activity "Web check in Progress" -Status "$($i / 1000 * 100)% Complete:" -PercentComplete ($i / 1000 * 100)
        }    
        
    }
    
    end {
        Write-Host "Test finished!"

        $ArrayTotals = ($ResultsArray.responsetime | Measure-Object -Average -Maximum -Minimum)

        $FinalResult = New-Object psobject
        add-member -InputObject $FinalResult -MemberType NoteProperty -Name 'Maximum Response' -Value "$($ArrayTotals.Maximum) ms"
        add-member -InputObject $FinalResult -MemberType NoteProperty -Name 'Minimum Response' -Value "$($ArrayTotals.Minimum) ms"
        add-member -InputObject $FinalResult -MemberType NoteProperty -Name 'Average Response' -Value "$($ArrayTotals.Average) ms"

        Write-Host "Top Slowest response times:"
        $ResultsArray | Where-Object { $_.ResponseTime -ge $ArrayTotals.Maximum / 2 }

        $Failures = $ResultsArray | Where-Object { $_.Response -ne "200" }

        if ($Failres) {
            Write-Host "Failed requests:"
            $Failures
        }
    }
}
# SIG # Begin signature block
# MIII2wYJKoZIhvcNAQcCoIIIzDCCCMgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUre17KSiLQutmp83lUUZY5ZPV
# Oc+gggYzMIIGLzCCBRegAwIBAgIKERM1LAABAAABvTANBgkqhkiG9w0BAQsFADBj
# MRIwEAYKCZImiZPyLGQBGRYCdWsxEjAQBgoJkiaJk/IsZAEZFgJjbzEbMBkGCgmS
# JomT8ixkARkWC3VuaXRlLWdyb3VwMRwwGgYDVQQDExNUaGUgVU5JVEUgR3JvdXAg
# UExDMB4XDTIwMDQwMTA5MTM1NloXDTIyMDQwMTA5MjM1NlowgY8xEjAQBgoJkiaJ
# k/IsZAEZFgJ1azESMBAGCgmSJomT8ixkARkWAmNvMRswGQYKCZImiZPyLGQBGRYL
# dW5pdGUtZ3JvdXAxIjAgBgNVBAsTGUluZnJhc3RydWN0dXJlIE1hbmFnZW1lbnQx
# FzAVBgNVBAsTDkFjY291bnRzIEFkbWluMQswCQYDVQQDEwJUQzCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAL//ziyRxr4OiQbj2OnQKs0/4WUbB6UYb5ez
# 28PAwOHmEciLvwPDEt7YDkdiU95rO1YqtmU+p0Rfk+A5JB2+GUzFV9jiBHSuD5Fn
# D2KxNcAtI6JiRCi1UbgVuDtVADYSUIYQ7rO4GPuHXTkZXp/QJQk+CQ5jCzjbnVFa
# JuFJb8LftrER6zwZf257r1eI+bH4/2AwTyLY5fIT7KtDmnkx84AsCYsZ2qZjJY79
# OwB2miyNqZ3PA8Ody7ckpBqI9s7x15MZkZ39o2a1cxtfRIJrQfr5s1oucckB+tGv
# MgKCIKnmUaRZXeuEo5FU5PR5jmx/AOwSnF7LPacNuOAszpADtzECAwEAAaOCArYw
# ggKyMD0GCSsGAQQBgjcVBwQwMC4GJisGAQQBgjcVCIfIrmGBk4gCgeGTK4WH3VuB
# pIBwgXeD26c15aA3AgFkAgEEMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB
# /wQEAwIHgDAbBgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQf
# puiwPXpN1vA1xapdy9XRrvpieDAfBgNVHSMEGDAWgBT52xEVe7wLpSLqGvpvO71c
# vPpiCzCB5gYDVR0fBIHeMIHbMIHYoIHVoIHShoHPbGRhcDovLy9DTj1UaGUlMjBV
# TklURSUyMEdyb3VwJTIwUExDKDEpLENOPUFQVVBCMDFXQ0EsQ049Q0RQLENOPVB1
# YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRp
# b24sREM9dW5pdGUtZ3JvdXAsREM9Y28sREM9dWs/Y2VydGlmaWNhdGVSZXZvY2F0
# aW9uTGlzdD9iYXNlP29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50MIHU
# BggrBgEFBQcBAQSBxzCBxDCBwQYIKwYBBQUHMAKGgbRsZGFwOi8vL0NOPVRoZSUy
# MFVOSVRFJTIwR3JvdXAlMjBQTEMsQ049QUlBLENOPVB1YmxpYyUyMEtleSUyMFNl
# cnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9dW5pdGUtZ3Jv
# dXAsREM9Y28sREM9dWs/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNl
# cnRpZmljYXRpb25BdXRob3JpdHkwLwYDVR0RBCgwJqAkBgorBgEEAYI3FAIDoBYM
# FFRDQHVuaXRlLWdyb3VwLmNvLnVrMA0GCSqGSIb3DQEBCwUAA4IBAQCIkTRzdX0M
# zHPdpx4xbx3Xg3hh53Bsp4pdc4xgLAmspB4et/WYOJEdo/gOkIOUnG/UWyAnPq5c
# FYXqdLJI4cHlPMF8mbek8T+2pVq8f0h82Y2ke9sWsLpSC7Lz78T7t2W5lCLPNDRe
# qTbjaRyAw//lCF/Ft4ixncaOrUyBh4YwaUfXi1AbTRbKd5DkR/D3L6xlAAfiB5UG
# VtlEBZSyFYl7PcI3jOXaabbkjT9NTbUh47/42OkOcvVGYdImvipSaPgO2/ZH2LvZ
# 8YU6ZXilnRStmmJGh6RE9pxReuY1FTbcGOHX9uf6ovCSmNJKmi69Ycafj2abtUa3
# KW7Jm+Y5wHXKMYICEjCCAg4CAQEwcTBjMRIwEAYKCZImiZPyLGQBGRYCdWsxEjAQ
# BgoJkiaJk/IsZAEZFgJjbzEbMBkGCgmSJomT8ixkARkWC3VuaXRlLWdyb3VwMRww
# GgYDVQQDExNUaGUgVU5JVEUgR3JvdXAgUExDAgoREzUsAAEAAAG9MAkGBSsOAwIa
# BQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgor
# BgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3
# DQEJBDEWBBS9DHgPlB09rk4+yMhi+rPo58/hdjANBgkqhkiG9w0BAQEFAASCAQAB
# tQyeXC1p7LegVpZ5pWjvqgAGK5dtwf+zsa9LBGUkDdu6svB14OzkJK139/g4Uuti
# qJKzdXOLHfrHzRFYatOL9toh4fcdtfntkt9icQmsUQx/tO8riOwhZ0bkEu0LcgsQ
# 6jMPhUpZThDd/Sk3FfIboPMdweUNiNzCsOcTn84LaK7hDPjw8uLx/7CdbtFGpdrD
# k/wftV4dHh1dOZ+wKuZJKtcs+L6WUADooB8epk6UqL6Z6cwQzi55U1DwxuxhBIhS
# 4hA/Fe4q5ezrAhR5RT2C8YPXqwiJSCNzWAgdMJsUmKl8EnzvIdHLpCKUT7UuXGOG
# y92FYuwGTq8ChApnoUmc
# SIG # End signature block
