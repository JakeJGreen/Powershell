
Function Invoke-ADStaleUserDiscovery{
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True)][ValidateSet("ALL","AVDC","BCC","CSB","WDC")]$Action,
    [Parameter(Mandatory=$False)][String]$ImportPath = (Invoke-DistrictTemplate -Action ALL).MasterDCOutputPath,
	[Parameter(Mandatory=$False)][Switch]$SendReport,
	[Parameter(Mandatory=$False)][String]$FileName,
	[Parameter(Mandatory=$False)][String]$ExportPath = "C:\Temp",
	[Parameter(Mandatory=$False)][String]$LogName = "StaleUserDiscoveryLog.csv",
	[Parameter(Mandatory=$False)][String]$LogPath = "C:\Temp",
	[Parameter(Mandatory=$False)][Switch]$NewDomainExports,
	[Parameter(Mandatory=$False)][ValidateSet(1,2,3)]$DebugLevel = 3
  )
  Process{
    # Create log file if a file does not exist
    New-LogFile -LogName $LogName -LogPath $LogPath
	# Title
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType Header -Operation "Stale User Discovery" -Details "Fetching $Action Stale users"
	# Import template settings
	$Settings = Invoke-DistrictTemplate -Action $Action
	# Generate export/s
	If($NewDomainExports){
	  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Domain Exports" -Details "You have chosen to generate new domain exports"
	  New-ADDistrictUserExport -Action $Action -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel
	}Else{
	  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Domain Exports" -Details "You have chosen NOT to generate new domain exports"
	}
	# Get AzureAD logons 
	$AzADLogons = Get-AzureADLogons -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel
	# Get Azure User Licenses
	$AllUserLicenses = Get-AzureADLicenses -LogName $LogName -LogPath $LogPath -DebugLevel 2
	# Import District users
	$ADUsers = Get-ADUserMaintenanceClass -Action $Action -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel
	$ExcludeOUPattern = $Settings.ExcludedOUs -join '|'
	$AllUsers = $ADUsers | Where-Object {($_.DistinguishedName -notmatch $ExcludeOUPattern)}
	# ========== Progress bar ==========
    # Reset counter
    $i = 0
	# Set Activity Title
	$Activity = "Retrieving User Licenses and Azure Logons"
	$Count = $AllUsers.Count
	# ========== Progress bar end ==========
	ForEach($User in $AllUsers){
	  # ========== Progress bar ==========
      $i ++
      $PercentComplete = ($i /$Count*100)
      $Status = "$i of $Count | %Complete: $PercentComplete"
      $Task = "Adding License and Azure Logon Information: $($User.UserPrincipalName)"
      Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $Task
      # ========== Progress bar end ==========
	  # Loop users get licenses
	  #$Licenses = Get-AzureADUserLicense -UserPrincipalName $User.UserPrincipalName
	  $Licenses = $AllUserLicenses | Where {$_.UserPrincipalName -like $($User.UserPrincipalName)}
	  # Get user Azure logon details
	  $AzLogon = $AzADLogons | Where {$_.UserPrincipalName -eq $User.UserPrincipalName}
	  # Add licenses property to user object
	  Write-LogFile -DebugLevel 2 -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Adding License Information" -Details "Fetching $($User.DisplayName) License Information"
	  If($Licenses){
	    Add-Member -InputObject $User -MemberType NoteProperty -Name Licensed -Value $True -Force
		If($Licenses -like "*SPE_E5*"){
		  Add-Member -InputObject $User -MemberType NoteProperty -Name E5 -Value $True -Force
		}Else{
		  Add-Member -InputObject $User -MemberType NoteProperty -Name E5 -Value $False -Force
		}
		Add-Member -InputObject $User -MemberType NoteProperty -Name Licenses -Value "$($Licenses.LicenseName)" -Force
	  }Else{
	    Add-Member -InputObject $User -MemberType NoteProperty -Name Licensed -Value $False -Force
		Add-Member -InputObject $User -MemberType NoteProperty -Name E5 -Value $False -Force
		Add-Member -InputObject $User -MemberType NoteProperty -Name Licenses -Value "N/A" -Force
	  }
	  # Add Azure information to user object
	  Write-LogFile -DebugLevel 2 -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Adding Azure Logon Information" -Details "Fetching $($User.DisplayName) Logon Information"
	  If($AzLogon){
	    Add-Member -InputObject $User -MemberType NoteProperty -Name AzureLogon -Value $True -Force
        Add-Member -InputObject $User -MemberType NoteProperty -Name AzureLastLogonDate -Value "$($AzLogon.AzureLastLogonDate)" -Force
	  }Else{
	    Add-Member -InputObject $User -MemberType NoteProperty -Name AzureLogon -Value $False -Force
        Add-Member -InputObject $User -MemberType NoteProperty -Name AzureLastLogonDate -Value "N/A" -Force
	  }
	}
	$Stale = $AllUsers | Where {(($_.MaintenanceClass.Split(" ") -notcontains "Active") -AND ($_.Licensed -eq "True") -AND ($_.AzureLastLoginDate -le $CheckDate))} | Select Name,UserPrincipalName,EmailAddress,MaintenanceClass,LastLogonDate,AccountExpirationDate,Created,Licensed,E5,ManagerName,ManagerUPN,AzureLogin,AzureLastLogonDate,CanonicalName,Licenses 
	$AllUsersReport = $AllUsers | Select Name,UserPrincipalName,EmailAddress,MaintenanceClass,LastLogonDate,AccountExpirationDate,Created,Licensed,E5,ManagerName,ManagerUPN,AzureLogin,AzureLastLogonDate,CanonicalName,Licenses 
    $Stale | Export-Csv ($ExportPath + "\" + "$($Action)Stale.Csv") -NoTypeInformation -Force
	$AllUsersReport | Export-Csv ($ExportPath + "\" + "$($Action)Users.Csv") -NoTypeInformation -Force
	If($SendReport){
	  $Attachment_Stale = Get-ChildItem ($ExportPath + "\" + "$($Action)Stale.Csv")
	  $Attachment_AllUsers = Get-ChildItem ($ExportPath + "\" + "$($Action)Users.Csv")
	  $Attachments = @($Attachment_Stale, $Attachment_AllUsers)
	  # Send to jake for auto upload
	  Send-MailMessage -To jake.green@buckinghamshire.gov.uk -From $($Settings.EmailSender) -Attachments $($Attachments.FullName) -SmtpServer mailgateway -Subject "Stale User Discovery"
	  # Send-MailMessage -To $($Settings.EmailRecipient) -From $($Settings.EmailSender) -Attachments $($Attachments.FullName) -SmtpServer mailgateway -Subject "Stale User Discovery"  
	}
  }
}
