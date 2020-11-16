$login = Login-AzAccount
$context = Set-AzContext -SubscriptionID "8036a580-ab74-4014-b1c3-5128b0f464a7"
$subname = (Get-AzSubscription -SubscriptionId "8036a580-ab74-4014-b1c3-5128b0f464a7").Name
$subscriptionId = (Get-AzSubscription -SubscriptionId "8036a580-ab74-4014-b1c3-5128b0f464a7").Id



$storageaccount = Get-AzStorageAccount
	
$ResourceGroupname = "ASR_Testing_Rec_Plan"
$Tablename = "servernames"
$Partitionkey = "server"
$storageAccountVar = "recplan"
 
 $storageAccountKey = $(Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountVar).Value[0]
 $stgtablecontext = New-AzStorageContext -storageAccountName $StorageAccountVar -StorageAccountKey $storageAccountKey
 $table = Get-AzStorageTable -name $Tablename -Context $stgtablecontext.context




$excludevmlist = $(Get-AzStorageTableRowByPartitionKey -table $table -partitionKey $Partitionkey | select rowkey).RowKey

	
Format-Out "Checking for |$SERVER_LIST| in |$INPUT_DIRECTORY|" -Color White Magenta
if (!$(Test-Path "$INPUT_DIRECTORY$SERVER_LIST" -PathType Leaf)) {
    Format-Out "Unable to find $SERVER_LIST" -Color Yellow
    Format-Out "Please verify that servers.txt exists in |$INPUT_DIRECTORY|" -Color Yellow Red
    mkdir -Path $INPUT_DIRECTORY -Force | Out-Null
    $total_runtime.Stop()
    exit
}

$DATETIME = Get-Date -U $FILE_DATE_FORMAT
$VMOUT = "vminfo.csv"
$BACKOUT = "backup_status.csv"
$OMSOUT = "oms_patching.csv"
$ALLTAGOUT = "all_tags.csv"
$NTPOUT = "NTPinfo.csv"
$ASROUT = "asr.csv"

Format-Out "Checking output directory"
$OUTPUT_DIRECTORY = "$BASE_OUTPUT_DIRECTORY$DATETIME\"
try {
    mkdir -Path $OUTPUT_DIRECTORY -Force | Out-Null
} catch {
    Format-Out "Error creating directory:`n|$_|" -Color Yellow Red
    exit
}

Format-Out "Checking current context"
if($null -eq (Get-AzContext)) {
    Format-Out "Please login before running the ORRScripts" -Color Yellow
    Format-Out "`tUse |Connect-AzAccount| for Global Azure" -Color White Magenta
    Format-Out "`tUse |Connect-AzAccount -Environment AzureUSGovernment| for Azure Gov" -Color White Magenta
    exit
}

try {
    Format-Out "Select a subscription to run" -Color Yellow
    $SUBSCRIPTION = Get-AzSubscription `
                    | Where-Object { $_.State -eq "Enabled" } `
                    | Out-GridView -Title "Select subscription to run:" -OutputMode Single
    $CONTEXT = Set-AzContext -Subscription $SUBSCRIPTION.Id
} catch {
    Format-Out "Error setting subscription - unable to continue" -Color Yellow
    exit
}
Format-Out "Working in |$($CONTEXT.Subscription.Name)| - |$($CONTEXT.Subscription.Id)|" -Color White Magenta

Format-Out "Building Identifier Object (collection of Azure VM ResourceId/Name(s))" -Color White
try {
    $resource_info = Get-VmIdentifiers -FilePath "$INPUT_DIRECTORY$SERVER_LIST"
} catch {
    Format-Out "Error Reading SERVER_LIST`n|$_|" -Color Yellow Red
    exit
}

Format-Out "`n###################################################"
Format-Out "Beginning to run selected scripts" -Color Magenta
Format-Out "###################################################`n"

if($VMINFO_RUN) {
    Format-Out "Beginning to run |Get-VMInfo|" -Color Green Magenta
    $stopwatch = [system.diagnostics.stopwatch]::StartNew()

    Format-Out "`tGathering VM information" -Color Yellow
    $output = Get-VMInfo -IdList $resource_info.ResourceId -GenerateCSVOutput

    Format-Out "`tWriting output file: |$OUTPUT_DIRECTORY$VMOUT|" -Color Yellow Magenta
    $output | Sort-Object -Property Name `
            | Export-Csv -NoTypeInformation `
                         -Delimiter ',' `
                         -Path "$OUTPUT_DIRECTORY$VMOUT"
    
    $stopwatch.Stop()
    $time = $stopwatch.Elapsed.ToString('hh\:mm\:ss')
    Format-OutMultiple -Text @("Get-VMInfo"," script run complete - Runtime: ","$time`n") `
                       -Color @("Magenta", "Green", "Red")
}

if($LOG_ANALYTICS_RUN) {
    ### Workspaces ###
    Format-Out "Gathering workspace information" -Color Green
    $workspaces = Get-AzOperationalInsightsWorkspace
    $workspace = if($workspaces.Count -gt 1) {
        Format-Out "`tPlease select a workspace for subscription |$($CONTEXT.Subscription.Id)|" -Color Yellow Magenta
        
        $ws = $workspaces | Out-GridView -Title "Select primary workspace in DXC-Maint-RG" -OutputMode Single
        $ws

        Format-Out "`t$($ws.Name)| selected for |$($CONTEXT.Subscription.Id)" -Color Magenta Yellow
    } else {
        Format-Out "`t$($ws.Name)| selected for |$($CONTEXT.Subscription.Id)" -Color Magenta Yellow    
        $workspaces
    }
    Format-Out "Workspace information gathered`n" -Color Green
    
    ### Script Run ###
    Format-Out "Beginning to run |Get-LogAnalyticsData|" -Color Green Magenta
    $stopwatch = [system.diagnostics.stopwatch]::StartNew()

    Format-Out "`tGathering LogAnalytics information" -Color Yellow
    $output = Get-LogAnalyticsData -Workspace $workspace `
                                   -IdList $resource_info.ResourceId `
                                   -GenerateCSVOutput

    Format-Out "`tWriting output file: |$OUTPUT_DIRECTORY$OMSOUT|" -Color Yellow Magenta
    $output | Sort-Object -Property VirtualMachine `
            | Export-Csv -NoTypeInformation `
                         -Delimiter ',' `
                         -Path "$OUTPUT_DIRECTORY$OMSOUT"

    $stopwatch.Stop()
    $time = $stopwatch.Elapsed.ToString('hh\:mm\:ss')
    Format-OutMultiple -Text @("Get-LogAnalyticsData"," script run complete - Runtime: ","$time`n") `
                       -Color @("Magenta", "Green", "Red")
}

if($ALL_TAGGING_RUN) {
    Format-Out "Beginning to run |Get-AzVmTags|" -Color Green Magenta
    $stopwatch = [system.diagnostics.stopwatch]::StartNew()
    
    Format-Out "`tCollecting all tags" -Color Yellow
    $output = Get-AzVmTags -IdList $resource_info.ResourceId -GenerateCSVOutput
    
    Format-Out "`tWriting output file: |$OUTPUT_DIRECTORY$ALLTAGOUT|" -Color Yellow Magenta
    $output | Sort-Object -Property Name `
            | Export-Csv -NoTypeInformation `
                         -Delimiter ',' `
                         -Path "$OUTPUT_DIRECTORY$ALLTAGOUT"
    
    $stopwatch.Stop()
    $time = $stopwatch.Elapsed.ToString('hh\:mm\:ss')
    Format-OutMultiple -Text @("Get-AzVmTags"," script run complete - Runtime: ","$time`n") `
                       -Color @("Magenta", "Green", "Red")
}


