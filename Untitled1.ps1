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

	


