Function Get-ADUserMaintenanceClass{
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True)][ValidateSet("ALL","AVDC","BCC","CSB","WDC")]$Action,
    [Parameter(Mandatory=$False)][String]$ImportPath = (Invoke-DistrictTemplate -Action ALL).MasterDCOutputPath,
	[Parameter(Mandatory=$False)][String]$FileName,
	[Parameter(Mandatory=$False)][String]$LogName = "ADUserMaintenanceClassLog.csv",
	[Parameter(Mandatory=$False)][String]$LogPath = "C:\Temp",
	[Parameter(Mandatory=$False)][ValidateSet(1,2,3)]$DebugLevel = 3
  )
  Process{
	# Create log file if a file does not exist
    New-LogFile -LogName $LogName -LogPath $LogPath
	# Title
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType Header -Operation "AD User Maintenance Class" -Details "Import AD User list and add thier maintenance class"
	# Import template settings
	$Settings = Invoke-DistrictTemplate -Action $Action
	$StaleUserThreshold = $Settings.StaleUserThreshold
	# ===== VALIDATE IMPORT PATH =====
	If($ImportPath -ne $($Settings.MasterDCOutputPath)){
	  # If custom import path, test path
	  $TestPath = Test-Path $ImportPath
	  If($TestPath){
	    # If path found write log
	    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Custom AD User Import Path" -Details "Path is valid and accessible $ImportPath"
	  }Else{
	    # If path found write log
		Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Custom AD User Import Path" -Details "Import path could not be found $ImportPath"
	  }
	}Else{
	  $ImportPath = "\\$($Settings.MasterDC)\$($ImportPath.Replace(":","$"))"
	  # if the import path is set to the default export path on DC001 re-format the path for remote location i.e. \\DC001\C$...
      $TestPath = Test-Path $ImportPath
	  If($TestPath){
	    # If path found write log
	    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Default AD User Path" -Details "Path is valid and accessible"
	  }Else{
	    # If path found write log
		Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Default AD User Path" -Details "Import path is invalid or could not be found $ImportPath"
	  }
	}
	# ================================
	If($FileName){
	  $ADUsers = Import-ADDistrictUsers -Action $Action -ImportPath $ImportPath -FileName $FileName -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel
	}Else{
	  $ADUsers = Import-ADDistrictUsers -Action $Action -ImportPath $ImportPath -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel
	}
	# =================================
	# ===== Maintenance Class Calculations =====
	$CheckDate = (Get-Date).AddDays(-$StaleUserThreshold)
    $Today = Get-Date
    $ExpiryDate = (Get-Date).AddDays($StaleUserThreshold)
	# ========== Progress bar ==========
    # Reset counter
    $i = 0
	# Set Activity Title
	$Activity = "Setting User Maintenance Classifications"
	$Count = $ADUsers.Count
	# ========== Progress bar end ==========
	ForEach($User in $ADUsers){
	  # Set last logon date as datetime object for filtering
	  If($User.LastLogonDate){$LastLogonDate = [datetime]::Parse($User.LastLogonDate)}
      # Set Account Expiration Date as datetime object for filtering
	  If($User.AccountExpirationDate){$AccountExpirationDate = [datetime]::Parse($User.AccountExpirationDate)}
      # Set Created date as datetime object for filtering
	  If($User.Created){$Created = [datetime]::Parse($User.Created)}
      # ========== Progress bar ==========
      $i ++
      $PercentComplete = ($i /$Count*100)
      $Status = "$i of $Count | %Complete: $PercentComplete"
      $Task = "Adding Maintenance Classification to $($User.UserPrincipalName)"
      Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $Task
      # ========== Progress bar end ==========
      # Create empty array
      $MaintenanceClasses = @()
      If($LastLogonDate -le $CheckDate){
	    # Add Inactive classification
	    $MaintenanceClasses += "Inactive"
      }
      If($User.Enabled -eq $False){
        # Add Disabled classification
	    $MaintenanceClasses += "Disabled"
      }
      If(($AccountExpirationDate) -AND ($AccountExpirationDate -lt $Today)){
        # Add Expired classification
	    $MaintenanceClasses += "Expired"
        # If user account has an expiry date and its set earlier expiry date by set timeframe
      }ElseIf(($AccountExpirationDate) -AND ($AccountExpirationDate -lt $ExpiryDate)){
        # Add Expiring classification
	    $MaintenanceClasses += "Expiring"
      }
      If((!($User.LastLogonDate)) -AND ($Created -le $CheckDate)){
      # If user account is disabled
        # Add Unused classification
	    $MaintenanceClasses += "Unused"
      }
      If(($User.Enabled -eq $True) -AND ($LastLogonDate -gt $CheckDate)){
        # Add Unused classification
	    $MaintenanceClasses += "Active"
      }
	    # Add maintenanceclass field to user object
        Add-Member -InputObject $User -MemberType NoteProperty -Name MaintenanceClass -Value "$MaintenanceClasses" -Force
    }
	# Get totals for maintenance classifications
	$Active = $ADUsers | where {$_.MaintenanceClass -like "Active*"}
	$Unused = $ADUsers | where {$_.MaintenanceClass -like "*Unused*"}
	$Inactive = $ADUsers | where {$_.MaintenanceClass -like "*Inactive*"}
	$Disabled = $ADUsers | where {$_.MaintenanceClass -like "*Disabled*"}
	$Expiring = $ADUsers | where {$_.MaintenanceClass -like "*Expiring*"}
	$Expired = $ADUsers | where {$_.MaintenanceClass -like "*Expired*"}
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Maintenance Total" -Details " $($ADUsers.Count) - All Users"
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Maintenance Total" -Details " $($Active.Count) - Active Users"
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Maintenance Total" -Details " $($Unused.Count) - Unused Users"
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Maintenance Total" -Details " $($Inactive.Count) - Inactive Users"
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Maintenance Total" -Details " $($Disabled.Count) - Disabled Users"
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Maintenance Total" -Details " $($Expiring.Count) - Expiring Users"
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Maintenance Total" -Details " $($Expired.Count) - Expired Users"
	# Export data to report
	#$AllUsers | Select Name,SamAccountName,UserPrincipalName,MaintenanceClass,LastLogonDate,AccountExpirationDate,@{Name='Manager';Expression={(Get-ADUser $_.Manager).DisplayName}},@{Name='ManagerUPN';Expression={(Get-ADUser $_.Manager).UserPrincipalName}},EmailAddress,CanonicalName | Export-Csv $ExportPath -NoTypeInformation -Force
    # ==========================================
	# Return all users with maintenance classes now set
	Return $ADUsers
  }
}
