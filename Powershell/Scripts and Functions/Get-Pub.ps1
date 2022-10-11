Function Get-Pub {

    [CmdletBinding()]
    param (
        [Parameter()]
        [String]$IWantToEat = "Pub",
        [String]$WhereAreYou = "HOME POSTCODE",
        [String]$HowFarCanYouBeBotheredToWalk = 1000,
        [Switch]$UseCurrentLocation, ## This is buggy as fuck
        [Switch]$ICanDriveThere ## This is buggy as fuck

    )

    begin {

        if (Get-Module -ListAvailable -Name GoogleMap) {
        } else {
            Install-module GoogleMap -AllowClobber
        }

        $GoogleAPIKey = "APIKEY"

        $env:GoogleGeocode_API_Key = $GoogleAPIKey
        $env:GooglePlaces_API_Key = $GoogleAPIKey
        $env:GoogleDistance_API_Key = $GoogleAPIKey
        $env:GoogleDirection_API_Key = $GoogleAPIKey
        $env:GoogleGeoloc_API_Key = $GoogleAPIKey
    }
    process {
        $swears = ((Invoke-WebRequest -URI "https://swearylistofswears.azurewebsites.net/swears.html").Content).split() | Select-Object -Unique

        if ($UseCurrentLocation) {
            $Current = Get-GeoLocation
    
            $Location = Get-GeoCoding -Address $Current[$current.length - 1]    
        }
        else {
            $Location = Get-GeoCoding -Address $WhereAreYou
        }
    
        $Pub = Get-Random -InputObject (Get-NearbyPlace -Coordinates "$($Location.Latitude),$($Location.Longitude)" -Keyword $IWantToEat -radius $HowFarCanYouBeBotheredToWalk)

        if (!$Pub) {
            Write-Error "I can't fucking find anything for you, try asking for a less obscure thing to eat..."

            Break
        }
    
        if ($ICanDriveThere) {
            $distance = Get-Distance -From "$($Location.Latitude),$($Location.Longitude)" -To $pub.Coordinates -Mode Driving
        } else {
            $distance = Get-Distance -From "$($Location.Latitude),$($Location.Longitude)" -To $pub.Coordinates -Mode walking
        }
    
        $ChoicePhrases = @(
            "Why don't you just fucking choose $($Pub.name), you $(Get-random $swears).",
            "Don't be such a $(Get-random $swears), go to $($Pub.name).",
            "Only a $(Get-random $swears) wouldn't want to go to $($Pub.name).",
            "If you don't go to $($Pub.name), then you are a proper $(Get-random $swears)."
        )
    }
    
    end {
        Write-host "$(Get-random $ChoicePhrases)`n" -ForegroundColor Green
        write-host "It is only a $($Distance.Time -replace "s",'') walk.`n" -ForegroundColor Green
    
        $YesOrNo = Read-Host "Would you like directions? (y/n)"
        while ("y", "n" -notcontains $YesOrNo ) {
            $YesOrNo = Read-Host "Would you like directions? (y/n)"
        }
    
        if ($YesOrNo -eq "y") {
    
            Write-Host "`nNo problem, here you go...`n" -ForegroundColor Cyan
    
            (Get-Direction -From "$($Location.Latitude),$($Location.Longitude)"  -To $pub.Coordinates -Mode walking).Instructions
        }
    }
}
# SIG # Begin signature block
# MIII2wYJKoZIhvcNAQcCoIIIzDCCCMgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUt3zwpXCoJ19xZkZbpGMGODGw
# DbCgggYzMIIGLzCCBRegAwIBAgIKHKxmxgABAABk2jANBgkqhkiG9w0BAQsFADBj
# MRIwEAYKCZImiZPyLGQBGRYCdWsxEjAQBgoJkiaJk/IsZAEZFgJjbzEbMBkGCgmS
# JomT8ixkARkWC3VuaXRlLWdyb3VwMRwwGgYDVQQDExNUaGUgVU5JVEUgR3JvdXAg
# UExDMB4XDTIyMDQyMDA2NTg1N1oXDTI3MDQyMDA3MDg1N1owgY8xEjAQBgoJkiaJ
# k/IsZAEZFgJ1azESMBAGCgmSJomT8ixkARkWAmNvMRswGQYKCZImiZPyLGQBGRYL
# dW5pdGUtZ3JvdXAxIjAgBgNVBAsTGUluZnJhc3RydWN0dXJlIE1hbmFnZW1lbnQx
# FzAVBgNVBAsTDkFjY291bnRzIEFkbWluMQswCQYDVQQDEwJUQzCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBANFANTOhO/aNxgopzmGTINfuPa6C08664B2c
# L/qTo4I99UuFJJhkXnl80f/dXIMqOet3UVL8O1wD7UGB659lBzZ4ANLQGnb7U3yR
# 5l09G2ILemD4HJlZ4UQ49EpUT4N8HuIMpgeVCQ97j5sVYcQDQ0xLQQyolvdld5LE
# hbJ1zOczg1qc64cfHL51tYu+XHlIZUhwnM9KK8UStt28zb7iCL73hTLigdsZ3IRL
# QSYFQuSB/JaPIt1EPcPNLiP0VlSkh3/o797nBeer0DPNIOuzwDEX8LVLlxznmKzG
# eyVqiRH+3MMKfnfG/LGCFIY4Rhkob7GYZtTVazmkDW9bYT1wfu0CAwEAAaOCArYw
# ggKyMD0GCSsGAQQBgjcVBwQwMC4GJisGAQQBgjcVCIfIrmGBk4gCgeGTK4WH3VuB
# pIBwgXeD26c15aA3AgFkAgEEMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB
# /wQEAwIHgDAbBgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQh
# +HKu9Ae0LPOz6d+QDM5VHlXpIjAfBgNVHSMEGDAWgBT52xEVe7wLpSLqGvpvO71c
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
# FFRDQHVuaXRlLWdyb3VwLmNvLnVrMA0GCSqGSIb3DQEBCwUAA4IBAQCf3J5IRpix
# pFH/Y43Pcz2pNhxursbCVHrawbrgO4iMLDs1rQofjczTl79Z91VyZc/kWMfz2glI
# /NoaI7KWlmSIEU13/6NsbqkvPcORzt9d9bjcyOOWQAUBJ4CEBByCyi4sRYnVdBve
# nn04J1fRhyCoiED+sPCd8z/oR3vGHdM0uzevLP+jR/9SLlDG+Yx75uXH1VaxTjtT
# T+mzQuhIA+DEvSlnIEJ+ctRoy6zPUZkNkOB3CongCL28LNUmxVdgz6VzAoQKZevN
# FacrmQT6XsoEwbnqrR4h4xmEKpPS55S4qVGo7hTfxY42NKBeAKIJkTfa0ZvVup1U
# +WVVUzk4EnkMMYICEjCCAg4CAQEwcTBjMRIwEAYKCZImiZPyLGQBGRYCdWsxEjAQ
# BgoJkiaJk/IsZAEZFgJjbzEbMBkGCgmSJomT8ixkARkWC3VuaXRlLWdyb3VwMRww
# GgYDVQQDExNUaGUgVU5JVEUgR3JvdXAgUExDAgocrGbGAAEAAGTaMAkGBSsOAwIa
# BQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgor
# BgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3
# DQEJBDEWBBSJ1KPh0rIcuzheNaKhTsGZHBr81TANBgkqhkiG9w0BAQEFAASCAQDM
# lBS7H30HMRAnwOIO0SEQIFnjfYpLR0g6Kr7WlzbLtIdz4AOu0obXUhEYvcCqFy9M
# Zl9K10qyqTmhnATiEFQhB55k+7Er1pgvJrpPDW3cqYn/BARL7efIC8FCnFu1n0EV
# XYdQTe/4ZSCEPKhr2k+Ulh3ASbxbPDKn4HN8zTMTk//V4ZtMhRolD3yBbDnmQxXa
# H+6kvnOJuNqtan/iSufd2UeM0HPHsGRqoMG6RDFW78QKUv9FmJlt6vnlirCacovI
# Wb7BVcEe/P+g85H23OLeKa2xv1m/2JijVJCgHWwhCmZOxA5Us3gmGROftRhEs82u
# +fvu9xU8LTy8O8+xT3WC
# SIG # End signature block
