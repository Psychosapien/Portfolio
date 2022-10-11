Param(
    [string]$DisposalName,
    [Array]$sitesBeingDisposed,    
    [string]$dueDate
)

#region Basics

$organizationName = "ORGNAME"
$projectName = "PROJECTNAME"
$Token = "ADO-TOKEN" 					#This PAT Token is set for expiry on 01/06/2021 - Will need refreshing ahead of time
$adoHeader = @{Authorization = ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $Token)))) }

$adoUserStoryUri = "https://dev.azure.com/$organizationName/$projectName/_apis/wit/workitems/`$User story?api-version=5.1"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

## Do some magic stuff and get the current iteration path
$iteration = "https://dev.azure.com/$organizationName/$projectName/_apis/work/teamsettings/iterations?api-version=6.0"
$Paths = Invoke-RestMethod -Uri $iteration -Headers $adoHeader -Method get -ContentType "application/json"

## Lets figure out which sprint it should be in

$dueDate = (Get-date $dueDate).AddHours(8)

$chosenPath = ""

foreach ($path in $paths.value) {

    $startDate = $path.attributes.startdate
    $startDate = Get-date $startDate

    $finishDate = $path.attributes.finishDate
    $finishDate = Get-date $finishDate

    if ($dueDate -ge $startDate -and $dueDate -le $finishDate) { $chosenPath = $path }
}

$IterationPath = $chosenPath.path -replace "\\", "\\" # This transforms the iteration path into a workable JSON string

#endregion Basics

#region Function

function New-Task {
    [CmdletBinding()]
    param (
        [string]$DisposalName,
        [Array]$sitesBeingDisposed,
        [string]$Title,
        [string]$Description,
        [string]$IterationPath,
        [string]$Parent
    )
    
    begin {
        $adoTaskUri = "https://dev.azure.com/$organizationName/$projectName/_apis/wit/workitems/`$Task?api-version=5.1"

        $body = "[
                    {
                    `"op`": `"add`",
                    `"path`": `"/fields/System.Title`",
                    `"value`": `"$Title`"
                    },
                    {
                    `"op`": `"add`",
                    `"path`": `"/fields/System.Description`",
                    `"value`": `"$Description`"
                    },
                    {
                    `"op`": `"add`",
                    `"path`": `"/fields/System.State`",
                    `"value`": `"New`"
                    },	   	  
                    {
                    `"op`": `"add`",
                    `"path`": `"/fields/Microsoft.VSTS.Scheduling.OriginalEstimate`",
                    `"value`": `"1`"
                    },
                    {
                    `"op`": `"add`",
                    `"path`": `"/fields/System.IterationPath`",
                    `"value`": `"$IterationPath`"
                    },	   	  
                    {
                    `"op`": `"add`",
                    `"path`": `"/fields/System.AreaPath`",
                    `"value`": `"ADO-PATH`"
                    }	  
                ]"

    }
    
    process {
        $Task = Invoke-RestMethod -Uri $adoTaskUri -ContentType "application/json-patch+json" -Body $body -Headers $adoHeader -Method Patch 

        $child = $task.id

        $Relationshipuri = "https://dev.azure.com/$organizationName/$projectName/_apis/wit/workitems/$Parent?api-version=5.1"

        $body = "[
        {
        `"op`": `"add`",
        `"path`": `"/relations/-`",
        `"value`": {
        `"rel`": `"System.LinkTypes.Hierarchy-Forward`",
        `"url`": `"https://dev.azure.com/$organizationName/$projectName/_apis/wit/workitems/$child`",
            }
        }
        ]"

        Invoke-RestMethod -Uri $Relationshipuri -ContentType "application/json-patch+json" -Body $body -Headers $adoHeader -Method Patch 

    }
    
    end {
        
    }
}

#endregion Function

#region Create User Story

$DueDate = Get-date $dueDate -Format dd/MM/yyyy
$Title = "USER STORY TITLE"
$Description = "USER STORY DESCRIPTION"

## Create the body of the JSON file to pass through to ADO - This should contain all of the mandatory fields for ADO item creation
$body = "[
{
`"op`": `"add`",
`"path`": `"/fields/System.Title`",
`"value`": `"$Title`"
},
{
`"op`": `"add`",
`"path`": `"/fields/System.Description`",
`"value`": `"$Description`"
},
{
`"op`": `"add`",
`"path`": `"/fields/System.State`",
`"value`": `"New`"
},	   	  
{
`"op`": `"add`",
`"path`": `"/fields/Microsoft.VSTS.Scheduling.StoryPoints`",
`"value`": `"3`"
},	   	  
{
`"op`": `"add`",
`"path`": `"/fields/System.IterationPath`",
`"value`": `"$IterationPath`"
},	   	  
{
`"op`": `"add`",
`"path`": `"/fields/System.AreaPath`",
`"value`": `"ADO-PATH`"
}	  
]"

# LOG AN ADO TICKET TO UPDATE VERSION in the next Sprint
$UserStory = Invoke-RestMethod -Uri $adoUserStoryUri -ContentType "application/json-patch+json" -Body $body -Headers $adoHeader -Method Patch 

#endregion Create User Story

#region Task Creation

$Title = "TASK TITLE"
$Description = "TASK DESCRIPTION"
New-Task -DisposalName $DisposalName -sitesBeingDisposed $sitesBeingDisposed -Title $Title -Description $Description -IterationPath $IterationPath -Parent $UserStory.id

#endregion Task Creation
