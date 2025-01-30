#Connect-MicrosoftTeams
#Connect-AzureAD
$Queues = Get-CsCallQueue -First 5000
$i = 0
$Activity = "Fetching Distribution Groups Assigned to Call Queues"
$Count = $Queues.Count
ForEach($Q in $Queues){
	If($i -eq 0){$StartTime = (Get-Date); $EstFin = "Calculating..."}
	$i ++
	$PercentComplete = ($i /$Count*100)
	$Status = "Estimated Completion Time: $EstFin | $i of $Count | %Complete: $PercentComplete"
	$Task = "Queue: $($Q.Name)"
	Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $Task
	If(!($Q.DistributionLists.Guid)){
		$DGNames = "No Distribution List Guid Found"
	}ElseIf($Q.DistributionLists.Count -ge 2){
		$DGNames = @()
		ForEach($DG in $Q.DistributionLists){
			$DGNames += Get-AzureADGroup -ObjectId $DG.Guid -ErrorAction SilentlyContinue
		}	
	}Else{
			$DGNames = Get-AzureADGroup -ObjectId $Q.DistributionLists.Guid -ErrorAction SilentlyContinue
	}
	Add-Member -InputObject $Q -MemberType NoteProperty -Name DistributionGroupName -Value $DGNames.DisplayName -Force
	If($i -le 1){
		$EndTime = (Get-Date)
		$Span = New-TimeSpan -Start $StartTime -End $EndTime
		$NewSpan = [TimeSpan]::FromMilliseconds($Span.TotalMilliseconds * $Count)
		$EstFin = (Get-Date).Add($NewSpan).ToString("dd.MM.yyyy HH:mm:ss")
		Write-Host "Span: $NewSpan | Estimated Completion Time: $EstFin" -F Cyan
	}
}
