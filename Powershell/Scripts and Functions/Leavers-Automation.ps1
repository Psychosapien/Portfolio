<#
.SYNOPSIS
    Powershell script for processing leavers
.DESCRIPTION
    Correctly ending the accounts for leavers has historically been semi automated.
    Until this script, there were still several tasks that the Service Desk needed to complete.
    My intention with this new leavers script is to eradicate as many manual jobs as possible.
    Some user are marked as VIPS within a (for now) manually updated Sharepoint list, they will be exempted from certain steps.
    Prior to the user processing, the script must successfuly connect to several resources and download a current data file from a Blob
    Once the script has finished running, an output of leaver information will be saved for Oracle to pick up and process.
    New additions to the script should follow the heavily commented format of the existing script. This is to help future engineers if they need to troubleshoot.
    Generating an output of the script's actions is done via write-output. This logs to log analytics workspace in AZ
    Environment checks are in place to ensure that commands are run with a -whatif statement if this is run on any server that is not a prod hybrid worker.
.OUTPUTS
    Outputs will be sent to log analytics workspace. There is a handy-dandy workbook to view the most meaningful of these outputs here > ###
.NOTES
    For full documentation, please refer to the documentation here > ###
#>

#region globalOutputArray

# Create an object for some global values to live in, these will eventually be output at the completion of the runbook.
$GlobalResult = New-Object psobject
add-member -InputObject $GlobalResult -MemberType NoteProperty -Name Resources_Connected -Value $False -TypeName boolean
add-member -InputObject $GlobalResult -MemberType NoteProperty -Name Running_Environment -Value $env:computerName -TypeName string
add-member -InputObject $GlobalResult -MemberType NoteProperty -Name Blob_Loaded -Value $False -TypeName boolean
add-member -InputObject $GlobalResult -MemberType NoteProperty -Name Total_Leavers -Value 0 -TypeName string

#endregion globalOutputArray

#region globalVars

# Switch to check if this is dev or PRD and set storage account info accordingly
switch -wildcard ($env:computerName) {
    "###" {
        $storageAccount = "###prd"
        $storageContainer = "###-prd"
    }
    Default {
        $storageAccount = "###dev"
        $storageContainer = "###-dev"   
    }
}


# Set global email vars
$From = "###Leavers@domain.com"
$Bcc = "Leavers@domain.com"
$SMTPServer = "mailrelay.domain.com"
$SMTPPort = "25"

# Initialise Oracle Array
$OracleLeaversExport = @()

#endregion globalVars

#region functions

function Write-Outcome {
    param (
        [PSCustomObject[]]$InputObject,
        [string]$Status,
        [string]$User,
        [string]$AdditionalInfo,
        [string]$JobType
    )

    # build on output object using the input object and a status value
    $Output = New-Object psobject
    add-member -InputObject $Output -MemberType NoteProperty -Name Status -Value $Status -TypeName string
    add-member -InputObject $Output -MemberType NoteProperty -Name JobType -Value $JobType -TypeName string
    add-member -InputObject $Output -MemberType NoteProperty -Name Result -Value $InputObject -TypeName string   
    
    # Output the output as json, this allows it to be picked up nicely from Log Analytics
    $Output | convertto-json -Depth 4 | Out-String | Write-Output

    # If there is an error, log a ticket, I'm doing this in comic sans because I am a bastard man
    if ($Status -eq "Error") {

        # Quick check on the env to set the $To address
        if ($env:computerName -like "PRODHYBRIDSERVER") {
            $To = "infrastructuresupport@domain.com"
        }
        else {
            $To = "Tom.Colyer@domain.com"
        }

        $ConstructedError = New-Object psobject
        add-member -InputObject $ConstructedError -MemberType NoteProperty -Name ScriptRegion -Value $Region -TypeName string
        add-member -InputObject $ConstructedError -MemberType NoteProperty -Name ErrorLine -Value $error.invocationinfo.ScriptLineNumber -TypeName string
        add-member -InputObject $ConstructedError -MemberType NoteProperty -Name ErrorLinePos -Value $error.invocationinfo.OffsetInLine -TypeName string
        add-member -InputObject $ConstructedError -MemberType NoteProperty -Name ErrorCMD -Value $error.invocationinfo.Line -TypeName string
        add-member -InputObject $ConstructedError -MemberType NoteProperty -Name ErrorException -Value $error.Exception.message -TypeName string
        add-member -InputObject $ConstructedError -MemberType NoteProperty -Name AdditionalInfo -Value $AdditionalInfo -TypeName string

        # If if it's a leaver that's errored then 
        if ($User) {

            $Subject = "Leaver Script issues for $($User)"
        }
        else {

            $Subject = "Leaver Script Failure"
        }

        $Body = "<p>Hello friends,</p>
        <p>It looks like there has been a problem with the leaver script:</p>
        <p><strong>Error Information:</strong></p>
        <p>-----------------------------------------------------</p>
        <p>Line: $($ConstructedError.ErrorLine)</p>
        <p>Char:&nbsp;$($ConstructedError.ErrorLinePos)</p>
        <p>Cmdlet Causing the error:&nbsp;$($ConstructedError.ErrorCMD)</p>
        <p>Error Exception:&nbsp;$($ConstructedError.ErrorException)</p>
        $(if ($AdditionalInfo) {
        "<p>Additional Info:&nbsp;$($ConstructedError.AdditionalInfo)</p>"
        })
        <p>-----------------------------------------------------</p>
        <p>There is every chance you need to do something about this.</p>
        <p>Kind regards,</p>
        <p>A Powershell Runbook</p>"

        Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer $SMTPServer -port $SMTPPort

        if ($env:computerName -like "PRODHYBRIDSERVER") {

            # Log an additional ticket to the Service Desk to advise that a leaver may not have been fully processed - only in PRD
            $To = "Supportportal@domain.com"
            $Subject = "Leaver Script Failed for $($Leaver)"
        
            $Body = "
                    <p>Hello friends,</p>
                    Whilst processing $($Leaver), we have encountered a big fat error.</p>
                    This means that this user may not have been full processed.</p>
                    Just double check if the leaver has been processed correctly and if not, you'll have to do it the boring old fashioned way.
                    There is every chance you need to do something about this.</p>
                    Kind regards,</p>
                    A Powershell Runbook</p>
                    </span><br></p>"
            Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer $SMTPServer -port $SMTPPort -Bcc $Bcc
        }
    }

}
#endregion functions

#region connectToResources

# Wrap this whole section in a try/catch to terminate the script if it fails to run and return any relevant errors
Try {

    $ErrorActionPreference = "Stop"
    # If we fail to connect to any of the below, halt the script and send the error

    Import-module Az.Storage

    Import-Module AzureAD

    $resourcePath = "$env:SystemDrive\COMPANYNAME\Certificates"

    #Connect to Exchange Online
    $ExchangeOnlineArgs = @{
        CertificateFilePath = "$resourcePath\CERT-NAME.pfx"
        CertificatePassword = (Get-AutomationPSCredential -Name EXO-On-Prem).password
        AppId               = 'APPID'
        Organization        = "TENANT"
        ShowBanner          = $false
    }

    Connect-ExchangeOnline @ExchangeOnlineArgs

    # Connect to the PnP Sharepoint Online module
    $url = "SHAREPOINT-URL"

    $password = (Get-AutomationPSCredential -Name SP-AZURE-RO-CERT).password

    Connect-PnPOnline -Url $url -ClientId "CLIENT-ID" -CertificatePath "$resourcePath\CERT-NAME.pfx" -CertificatePassword $password  -Tenant "TENANT"
    
    # Build a really quick list of VIPs, based on employee number
    # This list can be found and added to here > "SHAREPOINT-URL"
    $VIPS = @()

    Get-PnPListitem VIPStaff | ForEach-Object { $VIPS += $_.FieldValues.EmployeeNumber0 }

    Write-Output $VIPS

    # Connect to MS Graph / Intune using certificate

    # Intune Service principal application ID
    $IntuneAppID = 'APPID'

    # Dot source script to build authorization token
    $Request = .\Get-MSGraphToken.ps1 -CertName 'CERT-NAME' -AppID $IntuneAppID

    # Set the auth header with the granted token
    $Header = @{
        Authorization = "$($Request.token_type) $($Request.access_token)"
    }

    # Set the connect flag to $true
    $GlobalResult.Resources_Connected = $True

    #region fileImport

    <# Notes
        Get file from AZ blob storage (using AZ powershell cmdlets)
        Check date on file, if it is older than 1 day - log some kind of error
        If file is ok then begin the process
    #>

    # Import the storage account key from a saved credential in the automation account - This then needs to be decrypted to plaintext as the cmdlet does not like a secure string
    $storageKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-AutomationPSCredential -Name $storageAccount).password))

    # Connect to the Storage Account
    $context = New-AzStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageKey

    # Check the date on the ### file, if it is less than 1 day old, set the global blobdatecorrect flag to true and download the file
    $FileDate = (Get-AzStorageBlob -Container $storageContainer -Context $context -Blob EXPORTNAME.csv).LastModified.datetime
    $DateCheck = (get-date).AddDays(-1)

    if ($FileDate -gt $DateCheck) {

        # Build array for downloading the blob
        $BlobSplat = @{
            Blob        = '###_Data.csv'
            Container   = $storageContainer
            Destination = '.\'
            Context     = $Context
        }
        
        # Download the blob locally to work from
        Get-AzStorageBlobContent @BlobSplat

        $GlobalResult.Blob_Loaded = $true
    }
    
    # Import the csv file
    $Data = Import-Csv -Path .\EXPORTNAME.csv

    #endregion fileImport
}
Catch {

    # If anything fails, use the write-outcome function to send the failure information to log analytics
    add-member -InputObject $GlobalResult -MemberType NoteProperty -Name Errors -Value $Error.Exception.message -TypeName string

    Write-Outcome -InputObject $GlobalResult -Status "Error" -JobType "Script"

}

#endregion connectToResources

#region envCheck

# Quick check if this is running in PRD - if not, then set the $whatifpreference and $verbosepreference to $true
if ($env:computername -notlike "PRODHYBRIDSERVER") { 
    
    $WhatIfPreference = $true 
    $VerbosePreference = "Continue"
}

#endregion envCheck

# If the blob exists, and is within the right date - let's get cracking

#region forEachLeaverLoop

<# Notes
    This is the main meat of the script
    Here we are going to ultimately do the following

        Import core hr file
        Check for users with a leave date
        If the leave date is before 10 pm yesterday check the user in ad
        If the user is still enabled carry out the following

            Disable the user
            Move them to the disabled users ou
            Remove ad group membership
            Change ad group ownership to line manager
            Change mailbox to shared
            Remove all licences and disable in azure ad
            Set ext att 10 to their leave date
            Get a list of assigned devices in intune
            Email line manager to advise of all of this
            Log ticket to sd to chase for devices
        
        The foreach loop will also output certain data for Log Analytics

    Any errors should be caught in that output and should also email infrastructuresupport@domain.com
#>

# Begin foreach loop that checks for leavers within the last 30 days
foreach ($leaver in $Data) {
   
    # Clear the error buffer for each new user, for better logging
    $Error.Clear()
    
    #region userPreparation
    
    # The ###_Data csv file is a bit funny. It has people marked as leavers, even though they've only changed roles.
    # To get around this, we are checking for people in the csv that have a termination date and then checking that there isn't another 
    # entry with the same employee number
    # I hope this works well enough.
    
    if ($leaver.Termination_Date -and ($Data | Where-object { $_.ID -eq $Leaver.ID }).count -lt 2 ) {

        # Just a couple of date formats, because I had a hard time with the if statement
        $TerminationDate = Get-Date $leaver.Termination_Date

        # We're adding an additional check to factor in the ECC staff that might be working a night shift, because they're special.
        if ($Leaver.Job_Title -like "*24/7*") {
            $enddate = Get-date ([DateTime]::Today.AddHours(22))
        }
        else {
            $enddate = Get-date ([DateTime]::Today.AddDays(-1).AddHours(22))
        }

        # Build a psobject of the user, this will be added to the final output
        # We will be adding to this object as we go through the script, to avoid ugly output
        $Result = New-Object psobject
        add-member -InputObject $Result -MemberType NoteProperty -Name Full_Name -Value "$($Leaver.Known_as) $($Leaver.Surname)" -TypeName string
        add-member -InputObject $Result -MemberType NoteProperty -Name Termination_Date -Value $($TerminationDate.ToString("dd/MM/yyyy")) -TypeName string
    
        # Check each user, if their termination date is not in the future - do the good stuff

        if ($TerminationDate -lt $enddate) {


            <# Notes
                We are just going to build a few variables and an array of information for the user and their manager
                This information will be used at various stages later and is used for the output for Log Analytics
            #>
        
            # clear any errors for each new user
            $Error.Clear()

        
            # Build user variable
            $User = Get-ADUser -Filter "employeenumber -eq '$($leaver.ID)' -or employeenumber -eq '0$($leaver.ID)'" -properties name, employeenumber, MemberOf, extensionAttribute1, mobile, DistinguishedName, enabled

            # Add more items to the user object
            add-member -InputObject $Result -MemberType NoteProperty -Name Employee_ID -Value $User.employeenumber -TypeName string
            add-member -InputObject $Result -MemberType NoteProperty -Name Username -Value $User.samaccountname -TypeName string

            # Only continue if the user is enabled in AD
            if ($User.Enabled -eq $True) { 

                # Encapsulate all of this in a try/catch block to capture any errors
                try {

                    #region oracleData

                    # Yet another date re-format because why the hell not
                    $oracleLeaverDate = $Result.Termination_Date | get-date -Format "dd-MMM-yyyy"

                    # Add leaver information to a custom PS Object for the Oracle export
                    $OracleLeaversInfo = New-Object psobject
                    add-member -InputObject $OracleLeaversInfo -MemberType NoteProperty -Name ###_EmpNo -Value $user.employeenumber
                    add-member -InputObject $OracleLeaversInfo -MemberType NoteProperty -Name Termination_Date -Value $oracleLeaverDate

                    # Append the Leaver information to the Oracle leavers array
                    $OracleLeaversExport += $OracleLeaversInfo
                
                    #endregion oracleData

                    $Groups = @()

                    # Make the group membership list a little nicer for the final output
                    foreach ($Group in $User.MemberOf) {

                        $ProperGroup = Get-ADGroup -filter "DistinguishedName -like '$Group'"
                        $Groups += "$($ProperGroup.samaccountname),"
                    }

                    # Add group membership to the final output object
                    add-member -InputObject $Result -MemberType NoteProperty -Name Group_Membership -Value $Groups -TypeName string

                    # Get the manager from ###, not AD
                    $Manager = Get-ADUser -Filter "employeenumber -eq '$($leaver.Manager_ID)' -or employeenumber -eq '0$($leaver.Manager_ID)' -or employeenumber -eq '$($leaver.Manager_ID.trimstart("0"))'" -properties name, userPrincipalName

                    # Check if manager actually populated
                    $AdditionalInfo = "The script could not find a manager with employee id - $($leaver.Manager_ID)"
                    Get-ADUser -identity $Manager.samaccountname
                    $AdditionalInfo = ""

                    add-member -InputObject $Result -MemberType NoteProperty -Name Manager -Value $Manager.samaccountname -TypeName string
                    add-member -InputObject $Result -MemberType NoteProperty -Name Manager_Email -Value $Manager.userPrincipalName -TypeName string
        
                    # Get groups the user is an owner of
                    $ownedGroups = Get-ADGroup -LDAPFilter "(ManagedBy=$($user.distinguishedname))"

                    # If there are owned group, add them to the final output object
                    if ($OwnedGroups) {
                        add-member -InputObject $Result -MemberType NoteProperty -Name Owned_Groups -Value $OwnedGroups.samaccountname -TypeName string
                    }

                    # Check for mobile numbers and add to array for use in the Service Desk email
                    # Initialise Array
                    $Mobiles = @()

                    if ($User.extensionAttribute1 -or $User.mobile) {

                        # Tidy extension attribute 1
                        $Attribute1 = $User.extensionAttribute1 -replace "\+44", "" `
                            -replace "\(", "" `
                            -replace "\)", "" `
                            -replace " ", ""

                        # Tidy mobile attribute
                        $Mobile = $User.mobile -replace "\+44", "" `
                            -replace "\(", "" `
                            -replace "\)", "" `
                            -replace " ", ""
            
                        # If either attribute is a mobile number, add it to the array.
                        # Also check them against each other to avoid duplicates
                        if ($Attribute1 -like "07*") {
                            $Mobiles += "$Attribute1"
                        }
                        if ($Mobile -like "07*" -and $mobile -ne $Attribute1) {
                            $Mobiles += "$Mobile"
                        }

                        # Add any found mobiles to the final output object
                        add-member -InputObject $Result -MemberType NoteProperty -Name Mobile_Numbers -Value $Mobiles -TypeName string    
                    }
                }
                catch {

                    # If it goes Pete Tong, capture the error and output to the log analytics and then continue to the next
                    add-member -InputObject $Result -MemberType NoteProperty -Name Errors -Value $PSItem.Exception.Message -TypeName string  
                    Write-Outcome -InputObject $Result -Status "Error" -Leaver $User.samaccountname -JobType Leaver
                    Continue
                }
                    
                #region intuneDevices

                # Check for Devices registered in Azure AD first
                # If these exist, check Intune for more information

                $ErrorActionPreference = "SilentlyContinue"

                # Build URI for MS Graph call
                $Uri = "https://graph.microsoft.com/v1.0/users/$($User.userPrincipalName)/ownedDevices"

                # Make MS Graph API call, using header built earlier and uri for user
                # This will return an array of devices assigned to the user in Intune
                $IntuneDevices = (Invoke-RestMethod -Uri $Uri -Headers $Header -Method Get -ContentType "application/json").value

                $ErrorActionPreference = "Stop"

                # Build a shitty array of the devices because the formatting of $IntuneDevices is no good for an email later on
                $DeviceArray = @()

                # A foreach loop will now go through each device and extrapolate just the useful information
                foreach ($Device in $IntuneDevices) {

                    # If the device has a model, then add its details to the array. If there is no model then it will just add the device name
                    # Also, ignore any Optiplex devices as these are site PCs
                    if ($Device.model -notlike "*optiplex*") {
                        $DeviceArray += "$($Device.displayName) - $(if ($Device.model) {$Device.model} else {"Unknown Device Type"})"
                    }
                }

                # If there are Intune devices, add them to the final output object
                if ($IntuneDevices) {
                    add-member -InputObject $Result -MemberType NoteProperty -Name Intune_Devices -Value $DeviceArray -TypeName string
                }    

                $Error.Clear()
                        
                #endregion intuneDevices
            
                #endregion userPreparation

                Try {
                    #region userProcessing

                    # Change user's mailbox to shared
                    # Check if their mailbox is on prem
                    $MailboxOnPrem = (Get-Mailbox -identity $User.userPrincipalName -ErrorAction Ignore).IsDirSynced

                    # Switch statement, depending on whether the mailbox is on prem or not
                    # If the mailbox is on prem, disconnect from excchange online and connect to the on prem exchange server, then disconnect from that and reconnect to exchange online
                    # Either way, we are setting the mailbox to shared
                    switch ($MailboxOnPrem) {
                        $false {
                            # Disconnect from Exchange online
                            Disconnect-ExchangeOnline -confirm:$False

                            # Add info to results object
                            add-member -InputObject $Result -MemberType NoteProperty -Name Mailbox -Value "On-Prem" -TypeName string

                            # Connect to Exchange on prem
                            $remoteUsername = (Get-AutomationPSCredential -Name SAADMIN).username
                            $remoteEncrypted = (Get-AutomationPSCredential -Name SAADMIN).password
                            $remoteCredential = New-Object System.Management.Automation.PsCredential($remoteusername, $remoteencrypted)
                            $mailSession = New-PSSession -Authentication Kerberos  -ConfigurationName Microsoft.Exchange -ConnectionUri 'http://MAILSERVER.domain.com/PowerShell/' -Credential $remotecredential -Verbose
                            Import-PSSession $mailSession -CommandName Get-mailbox, set-mailbox -allowclobber

                            # Because the $whatifpreference doesn't affect exchange commands, we need an annoying if statement here
                            if ($env:computername -like "PRODHYBRIDSERVER") { 
                                Set-Mailbox -Identity $User.userPrincipalName -Type Shared -ErrorAction Ignore -confirm:$False
                            }
                            else {
                                Set-Mailbox -Identity $User.userPrincipalName -Type Shared -ErrorAction Ignore -confirm:$False -WhatIf
                            }                    # Set mailbox to shared

                            # Remove the mail session
                            Remove-PSSession $mailSession

                            # Reconnect to Exchange online
                            Connect-ExchangeOnline @ExchangeOnlineArgs
                        }
                        Default {

                            # Add info the results object
                            add-member -InputObject $Result -MemberType NoteProperty -Name Mailbox -Value "O365" -TypeName string

                            # Because the $whatifpreference doesn't affect exchange commands, we need an annoying if statement here
                            if ($env:computername -like "PRODHYBRIDSERVER") { 
                                Set-Mailbox -Identity $User.userPrincipalName -Type Shared -ErrorAction Ignore -confirm:$False
                            }
                            else {
                                Set-Mailbox -Identity $User.userPrincipalName -Type Shared -ErrorAction Ignore -confirm:$False -WhatIf
                            }                    
                        }
                    }

                    # Disable user
                    Set-ADUser -Identity $user.samaccountname -Enabled $false -confirm:$False

                    # Move the AD Object into the disabled users OU
                    Move-ADObject -Identity $User.DistinguishedName -TargetPath "OU=Disabled Objects Users,OU=Disabled Objects,OU=Infrastructure Management,DC=COMPANYNAME-group,DC=co,DC=uk" -confirm:$False
           
                    # Only do the meaty leaver stuff if the leaver is not a VIP
                    if ($VIPs -notcontains $User.employeenumber) {

                        # Remove AD group membership
                        foreach ($Group in $User.memberOf) {
                            Remove-ADGroupMember -Identity $Group -Members $user.samaccountname -confirm:$False
                        }

                        # Set line manager as owner for any groups that would be orphaned by the user leaving
                        foreach ($group in $ownedGroups) {
                            Set-ADGroup -Identity $Group -ManagedBy $Manager -confirm:$False
                        }

                        # Set Extension Attribute 4 to the user's leave date
                        Set-ADuser -identity $User.samaccountname -replace @{extensionattribute4 = $TerminationDate.ToString() } -confirm:$False

                        #endregion userProcessing

                        #region sendManagerEmail
        
                        <# Notes         
                        Construct email to send to the line manager, information to include is:
                            Name
                            Leaver date
                            AD Group ownership changes
                            Instructions on changing owner of groups 
                        #>

                        # Conditional email vars
                        # Quick check on env to determin $To address
                        if ($env:computerName -like "PRODHYBRIDSERVER") {
                            $To = $Manager.userPrincipalName
                        }
                        else {
                            $To = "Tom.Colyer@domain.com"
                        }
                            
                        $Subject = "Confirmation of removal of account for $($User.name)"

                        # Build owned groups list to pass through in case of ownership changes
                        $Folders = $ownedGroups | Where-Object { $_.Name -like "FF_*" -or $_.Name -like "CS.*" }
                        $Mailboxes = $ownedGroups | Where-Object { $_.Name -like "EX_*" }
                        $Distribution = $ownedGroups | Where-Object { $_.Name -like "All.*" }
                        $otherGroups = $ownedGroups | Where-Object { $_.Name -notlike "EX_*" -and $_.Name -notlike "FF_*" -and $_.Name -notlike "CS.*" -and $_.Name -notlike "All.*" }

                        #region emailBody

                        # Build email body in html, so we can make it pretty.
                        # The foreach loops should insert the group name and description of any groups that have been given to the line manager.
                        $Body = "<p>Hello $($Manager.name),</p>
                    <p>We are contacting you to advise that the account for $($User.name) has now been removed.</p>
                    <p>This has been completed as they have a termination date of $($Result.Termination_Date) within ###.</p>
                    $(
                        if ($ownedGroups){
                            "<p>As $($User.name) was the owner of some groups, ownership of the following groups have been transferred to yourself:</p>"
                            $(
                                if ($Folders) {              
                                    "<p><strong>Folders:</strong><br>
                                    $(
                                        foreach ($Group in $Folders) {
                                            $Description = Get-AdGroup -Identity "$Group" -properties Description
                                            if ($Description.Description) {
                                                $Description.Description; "<br>"
                                            } else {
                                                $Group; "<br>"
                                            }
                                        }
                                    )</p>"
                                }
                            )
                            $(
                                if ($Mailboxes) {
                                    "<p><strong>Mailboxes:</strong><br>
                                    $(
                                        foreach ($Group in $Mailboxes) {
                                    
                                            $Description = Get-AdGroup -Identity "$Group" -properties Description
                                            if ($Description.Description) {
                                                $Description.Description; "<br>"
                                            } else {
                                                $Group; "<br>"
                                            }
                                        }
                                    )</p>"
                                }
                            )
                            $(
                                if ($Distribution) {
                                    "<p><strong>Distribution Groups:</strong><br>
                                    $(
                                        foreach ($Group in $Distribution) {
                                        $Group.Name; "<br>"
                                        }
                                    )</p>"
                                }
                            )
                            $(
                                if ($otherGroups) {
                                    "<p><strong>Other Groups:</strong><br>
                                    $(
                                        foreach ($Group in $otherGroups) {
                                        $Group.Name; "<br>"
                                        }
                                    )</p>"
                                }"<p>If you wish to change ownership of any of these groups to someone else, please submit this request via the following form:</p>"
                            )             
                        
                        }
                    )

                    $(
                        if ($Result.Intune_Devices) {
                                "<p>We have also detected the following devices registered to $($User.name):</p>
                                $(foreach ($Device in $Result.intune_Devices) {
                                    $Device; "<br>"
                                }
                            )<p>You will be contacted by a member of the team to discuss the return of this equipment. As their line manager, you will be responsible for safely storing and returning the equipment.</p>"
                        }
                    )
                    <p>A ticket has also been created with the IT Service Desk to remove access to any other systems and to arrange collection of any hardware belonging to $($User.name).</p>
                    <p>Kind regards,</p>
                    <p>IT Ops</p>
                    <DIV><a href=""https://thehub.domain.com/""> <img alt=""The Hub"" src=""URLFORFOOTERIMAGE"" width=""520"" height=""115""></a></DIV><br />"

                        #endregion emailBody

                        # Send the email, a copy is also sent to Leavers@domain.com so the service desk can see that they are being sent properly.
                        Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer $SMTPServer -port $SMTPPort -Bcc $Bcc

                        #endregion sendManagerEmail

                        #region logServiceDeskTicket

                        <# Notes
                        Time to send a ticket to the IT Service Desk to action last bits for leaver
                        This should include:

                            Check Audim
                            If user is in QFM_Users, do EMMS
                            List of assets in intune
                            Check for phones
                        #>

                        # Quick check on the env to set the $To address
                        if ($env:computerName -like "PRODHYBRIDSERVER") {
                            $To = "SupportPortal@domain.com"
                        }
                        else {
                            $To = "Tom.Colyer@domain.com"
                        }

                        $Subject = "Leaver Processed - $($User.name)"

                        #region emailBody

                        # Build email body in html, so we can make it pretty.
                        # The foreach loops should insert the group name and description of any groups that have been given to the line manager.
                        $Body = "<p>Hello IT Service Desk Friends,</p>
                    <p>$($User.name) has been processed as a leaver.</p>
                    <p>This has been completed as they have a termination date of $($Result.Termination_Date) within ###.</p>
                    $(
                        if ($ownedGroups){
                            "<p><strong>As $($User.name) was the owner of some groups, ownership of the following groups has been transferred to their line manager ($($Manager.Name)):</strong></p>"
                            $(
                                if ($Folders) {              
                                    "<p><strong>Folders:</strong><br>
                                    $(
                                        foreach ($Group in $Folders) {
                                            $Group.name; "<br>"                              
                                        }
                                    )</p>"
                                }
                            )
                            $(
                                if ($Mailboxes) {
                                    "<p><strong>Mailboxes:</strong><br>
                                    $(
                                        foreach ($Group in $Mailboxes) {
                                            $Group.name; "<br>"                              
                                        }
                                    )</p>"
                                }
                            )
                            $(
                                if ($Distribution) {
                                    "<p><strong>Distribution Groups:</strong><br>
                                    $(
                                        foreach ($Group in $Distribution) {
                                            $Group.Name; "<br>"
                                        }
                                    )</p>"
                                }
                            )
                            $(
                                if ($otherGroups) {
                                    "<p><strong>Other Groups:</strong><br>
                                    $(
                                        foreach ($Group in $otherGroups) {
                                        $Group.Name; "<br>"
                                        }
                                    )</p>"
                                }
                            )             
                        }
                    )

                    $(
                        if ($Result.Intune_Devices) {
                                "<p><strong>The following devices are registered to this user in Intune:</strong></p>
                                $(
                                    foreach ($Device in $Result.Intune_Devices) {
                                    $Device; "<br>"
                                }
                            )"
                        }
                    )
                    $(
                        if ($Result.Mobile_Numbers) {
                                "<p><strong>The following Mobile numbers are associated with their AD account:</strong></p>
                                $(foreach ($Number in $Result.Mobile_Numbers) {
                                    $Number; "<br>"
                                }
                            )"
                        }
                    )
                    <p> I am not clever enough to see if they exist in Audim so please double check there.</p>
                    $(
                        if ($Result.Group_Membership -contains "*QFM*") {
                            "<p><strong>They are a member of a QFM group so check QFM:</strong></p>"
                        }
                    )
                    <p>Kind regards,</p>
                    <p>A Powershell Runbook</p>"

                        #endregion emailBody

                        # Send the email, a copy is also sent to Leavers@domain.com so the service desk can see that they are being sent properly.
                        Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer $SMTPServer -port $SMTPPort

                        #endregion logServiceDeskTicket
                    
                        # Increment the total leavers count
                        $GlobalResult.Total_Leavers ++

                    }
                    else {
                            
                        #region vipLeaver

                        <# Notes
                            If the leaver is in the VIP list in sharepoint, we want to send the email to Someone else.
                            This bit is TBC but I think it is going to be HR that want the information, and to make a decision on owned groups and mailbox access etc
                        #>


                        #endregion vipLeaver
                    }

                }
                catch {
    
                    # If it goes Pete Tong, capture the error and output to the log analytics and then continue to the next
                    add-member -InputObject $Result -MemberType NoteProperty -Name Errors -Value $Error.Exception.message -TypeName string    

                    Write-Outcome -InputObject $Result -Status "Error" -Leaver $User.samaccountname -JobType "Leaver"
                    Continue
                }

                #region diversityData

                # I have to do this bit outside of the try/catch statement as the invoke-webrequest is causing all sorts of problems.
                # It turns out you cannot ignore the error it gives back so it just breaks the loop

                # Convert the date to ISO8601 format
                $FormattedDate = $Result.Termination_Date | Get-Date -Format "o"

                # Build array for the logic app
                $DiversityArray = @{

                    leaverUPN   = $User.userPrincipalName
                    leavingDate = $FormattedDate

                }

                # Convert the array to JSON
                $body = ConvertTo-Json -InputObject $DiversityArray

                # URL for the logic app's trigger
                $url = "URL"

                # Make the call
                $DiversityData = Invoke-WebRequest -Uri $url -Method Post -Body $body -ContentType "application/json" -useBasicParsing

                # If there is data to remove, flag this in the leaver object
                if ($DiversityData.statusCode -eq "200") {
                    add-member -InputObject $Result -MemberType NoteProperty -Name Diversity_Data -Value $true -TypeName boolean
                }

                # Once we're finished, send the output to log analytics workspace
                Write-Outcome -InputObject $Result -Status "Success" -JobType "Leaver" -leaver $User.Samaccountname
                
                #endregion diversityData

                $Error.Clear()
            }
        }
    }
}
#endregion forEachLeaverLoop

#region disconnectSessions

# Disconnect sessions

Disconnect-ExchangeOnline -confirm:$False

#endregion disconnectSessions

#region oracleExport

<# Notes 
        Take the $oracleArray and build a csv export with it    
        Then send the Oracle export, with a little switch statement to determine if it is dev or prd
    #>


try {
    switch -wildcard ($env:computerName) {
        "PRODHYBRIDSERVER" {
            # Build out the file name and path
            $OracleLeaverExportFilename = "XX###_TERMINATIONS_" + (get-date -Format "ddMMyyyy") + '.csv'
            $OracleLeaverExportPath = "\\PATHTOEXTRACT\$OracleLeaverExportFilename"

            # Do the export
            $OracleLeaversExport | export-csv -Path $OracleLeaverExportPath  -NoTypeInformation -Append -Force
        }
        Default {

            # Change the whatifpreference back to $false so we can finish off the script in dev
            $WhatIfPreference = $false

            # Build out the file name and path
            $OracleLeaverExportFilename = "XX###_TERMINATIONS_DEV_" + (get-date -Format "ddMMyyyy") + '.csv'
            $OracleLeaverExportPath = "\\PATHTOEXTRACT\\Archive\$OracleLeaverExportFilename"
            
            # Do the export
            $OracleLeaversExport | export-csv -Path $OracleLeaverExportPath  -NoTypeInformation -Append -Force
        }
    }

    # Final bit of output for the logs
    Write-Outcome -Status "Success" -InputObject $GlobalResult -JobType "Script"

}
catch {
    
    # If we fall at the last hurdle, record this in the log
    add-member -InputObject $GlobalResult -MemberType NoteProperty -Name Errors -Value $PSItem.Exception.Message -TypeName string    
    Write-Outcome -InputObject $GlobalResult -Status "Error" -JobType "Script"

}
#endregion oracleExport
