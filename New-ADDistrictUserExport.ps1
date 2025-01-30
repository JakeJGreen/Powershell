Function New-ADDistrictUserExport{
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True)][ValidateSet("ALL","AVDC","BCC","CSB","WDC")]$Action,
	[Parameter(Mandatory=$False)][String]$LogName = "ADDistrictUserExportLog.csv",
	[Parameter(Mandatory=$False)][String]$LogPath = "C:\Temp",
	[Parameter(Mandatory=$False)][ValidateSet(1,2,3)]$DebugLevel = 3
  )
  Process{
    # Create log file if does not already exist
	New-LogFile -LogName $LogName -LogPath $LogPath
    # Title
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType Header -Operation "Generate AD District Users Export" -Details "Exporting $Action Users"
    # Import template settings
	$Settings = Invoke-DistrictTemplate -Action $Action
	# Set ExludeOUPattern
	$ExcludeOUPattern = $Settings.ExcludedOUs -join '|'
	# Connect to DC1
	$Session = New-CustomRemoteSession -ComputerName $Settings.MasterDC -Domain Buckscc.gov.uk -Template $Settings -LogPath $LogPath -LogName $LogName -DebugLevel $DebugLevel
	# Run script block on DC1
	Write-LogFile -DebugLevel 2 -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Log Continuance" -Details "For further logging see log on $($Settings.MasterDC), path $($Settings.MasterDCOutputPath)"
	$AllUsers = Invoke-Command -Session $Session -ArgumentList $Settings,$Action -ScriptBlock{
	  Param($Settings,$Action)
	  # Import custom logging module
	  $Modules = Get-Module JG-Logging
	  If(!($Module)){
	    Import-Module JG-Logging
	  }
	  $LogPath = "$($Settings.MasterDCOutputPath)\Logs"
	  $LogName = "DistrictADUserExportLog.csv"
	  $DebugLevel = 3
	  New-LogFile -LogName $LogName -LogPath $LogPath
	  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType Header -Operation "Generate AD District Users Export" -Details "Exporting $Action Users"
	  # == Folder cleanup ==
	  # Get all AD exports
	  $ADExports = Get-ChildItem -Path $($Settings.MasterDCOutputPath)
	  #Write-Host "Current AD Exports: $($ADExports.Count)" -ForegroundColor Yellow
	  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Expired AD Export Cleanup" -Details "Total AD exports $($ADExports.Count)" 
	  # Set retention threshold
	  $RetentionThreshold = (Get-Date).AddDays(-$Settings.ExportRetentionThreshold)
	  # Get all AD exports with a last accessed or last modified time of over a month
	  $ToBeRemoved = $ADExports | Where {($_.LastAccessTime -le $Threshold) -AND ($_.LastWriteTime -le $Threshold)}
	  #Write-Host "AD Exports older than 30 days to be removed: $($ToBeRemoved.Count)" -ForegroundColor Yellow
	  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Expired AD Export Cleanup" -Details "AD exports older than 30 days to be removed $($ToBeRemoved.Count)"  
	  If($ToBeRemoved.Count -ge 1){
	    ForEach($Item in $ToBeRemoved){
	      #Write-Host "Removing AD Export: $($Item.Name)" -ForegroundColor Yellow  
	      Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Expired AD Export Cleanup" -Details "Removing AD export: $($Item.Name)"
		  Remove-Item $Item.FullName -Force
	    }
	    #Write-Host "Expired AD reports removed" -ForegroundColor Green 
		Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Expired AD Export Cleanup" -Details "Expired AD exports removed"
	  }Else{
	    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Expired AD Export Cleanup" -Details "There are no AD Exports older than 30 days to be removed"
		#Write-Host "There are no AD Exports older than 30 days to be removed" -ForegroundColor Green
	  }
	  # ====================
	  # Set short date
	  $ShortDate = Get-Date -Format ddMMyyyy
	  # loop district dns servers
	  #Write-Host "Testing District Server Connections" -ForegroundColor Cyan
	  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType Header -Operation "Testing District Server Connections" -Details "Executing Prerequisite NSLookup on District DNSs"
	  ForEach($Server in $Settings.Servers){
	    # test dns server connection (this needs doing on some district servers or the connection between DC001 and district does not work)
	    #Write-Host "Testing District Server Connections: $Server" -ForegroundColor Yellow
		Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Testing District Server Connections" -Details "Testing District Server Connection $Server"
		nslookup $Server 2>$null >> $Null
	  }
	  # If action is for all districts
	  If($Action -eq "ALL"){
	    # Title 
	    Write-Host "Retriving $Action Users" -ForegroundColor Cyan
		Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType Header -Operation "Retrieving District AD Users" -Details "$Action selected"
		# Create empty array
	    $AllUsers = @()
		# Loop primary servers
		ForEach($Primary in $Settings.Primary){
		  # write process which server is currenly active for ad user retrieval
		  #Write-Host "Retrieve AD District Users: Primary server $Primary" -ForegroundColor Yellow
		  # Get all AD users from primary server for the district
		  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Retrieving District AD Users" -Details "Primary server $Primary"
		  # Clear users variable
		  $Users = $Null
		  # Get ad users from primary server
		  $BCCPrimary = (Invoke-DistrictTemplate -Action BCC).Primary
		  If($Primary -eq $BCCPrimary){
		    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Retrieving District AD Users" -Details "Primary server is BCC $Primary - Some OUs will be excluded from discovery"
		    $Users = Get-ADUser -Server $Primary -Filter * -Properties * | Where-Object {($_.DistinguishedName -notmatch $ExcludeOUPattern)} | Select *,@{Name='ManagerName';Expression={(Get-ADUser $_.Manager).Name}},@{Name='ManagerUPN';Expression={(Get-ADUser $_.Manager).UserPrincipalName}}
		  }Else{
		    $Users = Get-ADUser -Server $Primary -Filter * -Properties * | Select *,@{Name='ManagerName';Expression={(Get-ADUser $_.Manager).Name}},@{Name='ManagerUPN';Expression={(Get-ADUser $_.Manager).UserPrincipalName}}
		  }
		  # If users returned
		  If($Users){
		    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Retrieving District AD Users" -Details "Users retrieved $($Users.Count)"
			# Add users to all users array
			$AllUsers += $Users
		    # Write count to screen	
		    #Write-Host "Retrieve AD District Users: Primary server $Primary | Users retrieved $($Users.Count)" -ForegroundColor Green
			Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Retrieving District AD Users" -Details "All users running count $($AllUsers.Count)"
		  }Else{
		    # If no users returned write error and command to screen
		    #Write-Host "Retrieve AD District Users: Primary server $Primary - Unable to retrieve users" -ForegroundColor Red
			#Write-Host "Retrieve AD District Users: Command run from DC001 >> Get-ADUser -Server $Primary -Filter * -Properties * | Select *,'@{Name='ManagerName';Expression={(Get-ADUser $_.Manager).Name}},@{Name='ManagerUPN';Expression={(Get-ADUser $_.Manager).UserPrincipalName}}'" -ForegroundColor Red
			Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Retrieving District AD Users" -Details "Primary server $Primary - Unable to retrieve users"
			Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Retrieving District AD Users" -Details "Command run from DC001 >> Get-ADUser -Server $Primary -Filter * -Properties * | Select *,'@{Name='ManagerName';Expression={(Get-ADUser $_.Manager).Name}},@{Name='ManagerUPN';Expression={(Get-ADUser $_.Manager).UserPrincipalName}}'"
		  }
		}
		If($AllUsers){
		  # Write total users
		  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Retrieving District AD Users" -Details "All users count $($AllUsers.Count)"
		  # Export all users to output location
		  $AllUsers | Export-Csv "$($Settings.MasterDCOutputPath)\AllUsers-AllDomains-$ShortDate.csv" -Force -NoTypeInformation
		  # Check users exported
		  Sleep 1
		  $TestOutput = Test-Path "$($Settings.MasterDCOutputPath)\AllUsers-AllDomains-$ShortDate.csv"
		  If($TestOutput){
		    #Write-Host "Users output was successful" -ForegroundColor Green
		    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Retrieving District AD Users" -Details "Users export was successful"
		  }Else{
		    #Write-Host "Users output failed" -ForegroundColor Red
		    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Retrieving District AD Users" -Details "Users export failed"
		  }
		}Else{
		  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Retrieving District AD Users" -Details "Unable to retrieve ALL users"
		}
	  }Else{
	    # Title
	    #Write-Host "Retriving $Action Users" -ForegroundColor Cyan
		Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType Header -Operation "Retrieving District AD Users" -Details "$Action selected"
		# Get all AD users from primary server for the district
		#Write-Host "Retriving $Action Users from $Action DC - $($Settings.Primary)" -ForegroundColor Yellow
		Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Retrieving District AD Users" -Details "Primary server $($Settings.Primary)"
	    $DistrictUsers = Get-ADUser -Server $Settings.Primary -Filter * -Properties * | Select *,@{Name='ManagerName';Expression={(Get-ADUser $_.Manager).Name}},@{Name='ManagerUPN';Expression={(Get-ADUser $_.Manager).UserPrincipalName}}
	    If($DistrictUsers){
		  # If all users has a value write count to screen
		  #Write-Host "Retrieve AD District Users: Primary server $($Settings.Primary) | Users retrieved $($DistrictUsers.Count)" -ForegroundColor Green
		  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Retrieving District AD Users" -Details "Users retrieved $($DistrictUsers.Count)"
		  # Export users to output location
		  $DistrictUsers | Export-Csv "$($Settings.MasterDCOutputPath)\AllUsers-$($Action)Domain-$ShortDate.csv" -Force -NoTypeInformation
		  # Check users exported
		  Sleep 1
		  $TestOutput = Test-Path "$($Settings.MasterDCOutputPath)\AllUsers-AllDomains-$ShortDate.csv"
		  If($TestOutput){
			#Write-Host "Users output was successful" -ForegroundColor Green
			Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Retrieving District AD Users" -Details "Users export was successful"
		  }Else{
			#Write-Host "Users output failed" -ForegroundColor Red
			Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Retrieving District AD Users" -Details "Users export failed"
		  }
		}Else{
		  # If users variable is null write error to screen
		  #Write-Host "Retrieve AD District Users: Primary server $($Settings.Primary) - Unable to retrieve users" -ForegroundColor Red
		  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Retrieving District AD Users" -Details "Unable to retrieve users"
		}
	  }
	}
	# Close open session to DC
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Closing Remote Session" -Details "Closing remote session to Master DC"
	Get-PSSession -Name $Settings.MasterDC | Remove-PSSession
  }
}
