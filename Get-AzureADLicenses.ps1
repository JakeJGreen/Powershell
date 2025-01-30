Function Get-AzureADLicenses{
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$False)][String]$LogName = "AzureADLicensesLog.csv",
    [Parameter(Mandatory=$False)][String]$LogPath = "C:\Temp",
    [Parameter(Mandatory=$False)][ValidateSet(1,2,3)]$DebugLevel = 3
  )
  Process{
    # Create log file if a file does not exist
    New-LogFile -LogName $LogName -LogPath $LogPath
	# Title
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType Header -Operation "Retrieve Azure License Information" -Details "Fetching Azure License Information"
    # Import template settings
	$Settings = Invoke-DistrictTemplate -Action ALL
	# Set credentials
	$Username = $Settings.AzUserName
	$EncryptedPassword = $Settings.AzEncryptedPassword
	$AESKey = $Settings.AzAESKey
	# Convert encrypted password to secure string
	$SecureString = $EncryptedPassword | ConvertTo-SecureString -Key $AESKey
	# Use settings to produce credentials for new PSSession
	$Credentials = New-Object -TypeName 'System.Management.Automation.PSCredential' -ArgumentList $Username, $SecureString
	# Connect to Azure AD
	Connect-AzureAD -Credential $Credentials -Confirm:$False | Out-Null
	$AzureADUsers = Get-AzureADUser -All $True
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Retrieve Azure License Information" -Details "Azure users retrieved - $($AzureADUsers.count)"
	# ========== Progress bar ==========
    # Reset counter
    $i = 0
	# Set Activity Title
	$Activity = "Retrieving User Licenses"
	$Count = $AzureADUsers.Count
	# ========== Progress bar end ==========
	ForEach($User in $AzureADUsers){
	  # ========== Progress bar ==========
      $i ++
      $PercentComplete = ($i /$Count*100)
      $Status = "$i of $Count | %Complete: $PercentComplete"
      $Task = "Adding License Information: $($User.UserPrincipalName)"
      Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $Task
      # ========== Progress bar end ==========
	  $SkuID = $User.AssignedLicenses.Skuid
	  $License = Get-AzureADSubscribedSku | ?{$_.ObjectID -like "*$skuID"}
	  If($License){
	    $LicenseString = $License.SkuPartNumber -join ','
	    Add-Member -InputObject $User -MemberType NoteProperty -Name LicenseName -Value $LicenseString -Force
	  }Else{
	    Add-Member -InputObject $User -MemberType NoteProperty -Name LicenseName -Value "N/A" -Force
	  }
	}
	Return $AzureADUsers
  }
}
