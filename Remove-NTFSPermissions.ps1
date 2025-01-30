# Current max runtime: 1.3 Seconds
Function Remove-NTFSPermissions{
<#
  .SYNOPSIS
    Remove NTFS permissions

  .DESCRIPTION
    Remove a users NTFS permissions to a defined item

  .PARAMETER Target
    Mandatory. [String] Used to determine on which item to set the permissions

  .PARAMETER TargetUserDomain
    Optional. [String] User to determine which user domain applies to the target user
	
  .PARAMETER TargetUser
    Mandatory. [String] User to determine which user to set permissions for

  .PARAMETER Backup
    Optional. Switch choose to create backup of previous permissions
	
  .PARAMETER LogPath
    Optional. [String] Used to determine the destination of the output for this function
	
  .PARAMETER LogName
    Optional. [String] Used to determine the name of the log for this function
	
  .PARAMETER DebugLevel
    Optional. Switch the integer to determine the level of logging, examples: "1","2","3" - 1=ToScreen, 2=ToFile, 3=ToScreenandFile
    
  .INPUTS
    See parameters listed above
	
  .OUTPUTS
    Log file (Pending BackupPermissions switch: permissions records)
    
  .NOTES
    Version:        1.0
    Author:         Jake Green
    Creation Date:  15/09/2021
    Purpose/Change: Initial function development and debug mode support
	
  .EXAMPLE
    Remove-NTFSPermissions -Target C:\Temp -TargetUser pv-jbrainch
#>
  [CmdletBinding()]
  Param(
	[Parameter(Mandatory=$True)][String]$Target,
	[Parameter(Mandatory=$False)][String]$TargetUserDomain = "$Env:USERDOMAIN",
	[Parameter(Mandatory=$True)][String]$TargetUser,
	[Parameter(Mandatory=$False)][Switch]$Backup,
	[Parameter(Mandatory=$False)][String]$LogPath = "C:\Temp",
	[Parameter(Mandatory=$False)][String]$LogName = "RemovePermissionsLog",
	[Parameter(Mandatory=$False)][ValidateSet(1,2,3)]$DebugLevel = 3
  )
  Process{
    $ConfirmedDetails = Confirm-LogDetails -LogName $LogName -LogPath $LogPath
	# If target user domain end in backslash remove it
	If($TargetUserDomain -like "*\"){
	  $TargetUserDomain = $TargetUserDomain.Trim("\")
	}
	# If user provided is formatted Domain\Username split and set target user to Username
	If($TargetUser -like "*\*"){
	  $Tokens = $TargetUser.Split("\")
	  $TargetUser = $Tokens[1]
	}
	# Clear Error variable 
	$Error = $Null
	$User = $TargetUserDomain + "\" + $TargetUser
	# Title
	Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Remove NTFS Permissions" -EntryType HEADER -Details "Removing NTFS Permissions - $Target - $TargetUser"
    # Get target item
	Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Get Target Item" -EntryType NOTE -Details "Retrieving target item - $Target"
	$Item = Get-Item -Path $Target
	If(!($Item)){
	  #$ErrorMsg = $Error.Exception[1]
	  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Get Target Item" -EntryType ERROR -Details "Unable to retrieve - $Target"
	}Else{
	  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Get Item Permissions" -EntryType NOTE -Details "Retrieving item permissions - $($Item.FullName)"
	  # Get permissions
	  $Permissions = Get-Acl -Path $Item.FullName -Audit
	  If(!($Permissions)){
	    #$ErrorMsg = $Error.Exception[1]
		Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Get Item Permissions" -EntryType ERROR -Details "Unable to retrieve item permissions - $($Item.FullName)"
	  }Else{
	    If($Backup){
		  # Write log backups enabled
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Backup Option" -EntryType NOTE -Details "Backups - ENABLED"
		  # Create new log path 
		  $BackupLogPath = $LogPath + "\" + "Backups"
		  # Get backup permissions
		  $BackupPermissions = Get-NTFSPermissions -TargetPath $($Item.FullName) -LogPath $LogPath -LogName $LogName -DebugLevel 2
		  # Reset counter
		  $BPCount = 0
		  # Loop backup data
		  ForEach($Entry in $BackupPermissions){
		    $BPCount ++ 
		    $BPTotal = $BackupPermissions.Count
			# Write backup count to operations log
		    Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Backup Permissions" -EntryType NOTE -Details "Item $($Item.FullName) - Permissions Backup: $BPCount of $BPTotal"
			$Date = (Get-Date).ToShortDateString()
			$Time = (Get-Date).ToShortTimeString()
			Write-LogFile -LogName "NTFS Legacy Permissions Backups" -LogPath $BackupLogPath -DebugLevel 2 -Operation "Access Record $BPCount" -EntryType NOTE -Details "BackupDate#$($Date)"
			Write-LogFile -LogName "NTFS Legacy Permissions Backups" -LogPath $BackupLogPath -DebugLevel 2 -Operation "Access Record $BPCount" -EntryType NOTE -Details "BackupTime#$($Time)"
	        Write-LogFile -LogName "NTFS Legacy Permissions Backups" -LogPath $BackupLogPath -DebugLevel 2 -Operation "Access Record $BPCount" -EntryType NOTE -Details "FullName#$($Entry.FullName)"
			Write-LogFile -LogName "NTFS Legacy Permissions Backups" -LogPath $BackupLogPath -DebugLevel 2 -Operation "Access Record $BPCount" -EntryType NOTE -Details "User#$($Entry.IdentityReference)"
			Write-LogFile -LogName "NTFS Legacy Permissions Backups" -LogPath $BackupLogPath -DebugLevel 2 -Operation "Access Record $BPCount" -EntryType NOTE -Details "ItemType#$($Entry.ItemType)"
			Write-LogFile -LogName "NTFS Legacy Permissions Backups" -LogPath $BackupLogPath -DebugLevel 2 -Operation "Access Record $BPCount" -EntryType NOTE -Details "FileSystemRights#$($Entry.FileSystemRights)"
			$InheritanceFlags = "$($Entry.InheritanceFlags)".Replace(",","_")
			Write-LogFile -LogName "NTFS Legacy Permissions Backups" -LogPath $BackupLogPath -DebugLevel 2 -Operation "Access Record $BPCount" -EntryType NOTE -Details "InheritanceFlags#$InheritanceFlags"
		  }
		}Else{
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Backup Option" -EntryType NOTE -Details "Backups - DISABLED"
		}
	    # filter permissions to specific user 
		Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Get User Permissions" -EntryType NOTE -Details "Retrieve permissions for target user - $User - $($Item.FullName) "
		$TargetUserAccess = $Permissions.Access | Where {$_.IdentityReference -eq $User}
		If(!($TargetUserAccess)){
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check User Permissions" -EntryType ERROR -Details "User $User does not currently have permissions on item - $($Item.FullName) "
		}Else{
		  # If permissions are inherited disable inheritance
		  If($TargetUserAccess.IsInherited -eq $True){
		    Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Disable Inheritance" -EntryType NOTE -Details "Permissions for $User on $($Item.FullName) are inherited"
		    # Disable inheritance
		    $isProtected = $true
            $preserveInheritance = $true
            $Permissions.SetAccessRuleProtection($isProtected, $preserveInheritance)
			Set-Acl -Path $Permissions.Path -AclObject $Permissions
			# Check inheritance is disabled
			$Permissions = Get-Acl -Path $Item.FullName -Audit
			$TargetUserAccess = $Permissions.Access | Where {$_.IdentityReference -eq $User}
			$CheckInheritance = $TargetUserAccess.IsInherited
			# If inheritance has been removed
			If($CheckInheritance -eq $False){
			  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Disable Inheritance" -EntryType SUCCESS -Details "Inheritance has been disabled on $($Item.FullName)"
			  # Remove permissions	
		      $Permissions.RemoveAccessRule($TargetUserAccess) | Out-Null
		      Set-Acl -Path $Permissions.Path -AclObject $Permissions
		      # Confirm permissions removed
		      $Permissions = Get-Acl -Path $Item.FullName -Audit
		      $TargetUserAccess = $Permissions.Access | Where {$_.IdentityReference -eq $User}
		      If(!($TargetUserAccess)){
		        Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm User Permissions Removed" -EntryType SUCCESS -Details "Permissions for $User on $($Item.FullName) have now been removed"
		      }Else{
		        Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm User Permissions Removed" -EntryType ERROR -Details "Unable to remove permissions for $User on $($Item.FullName)"
		      }
			}Else{
			  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Disable Inheritance" -EntryType ERROR -Details "Unable to remove inheritance for $User on $($Item.FullName)"
			}
		  }Else{
		    Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Remove User Permissions" -EntryType NOTE -Details "Removing permissions for target user - $User - $($Item.FullName)"
            # Remove permissions	
		    $Permissions.RemoveAccessRule($TargetUserAccess) | Out-Null
		    Set-Acl -Path $Permissions.Path -AclObject $Permissions
		    # Confirm permissions removed
		    $Permissions = Get-Acl -Path $Item.FullName -Audit
		     $TargetUserAccess = $Permissions.Access | Where {$_.IdentityReference -eq $User}
		    If(!($TargetUserAccess)){
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm User Permissions Removed" -EntryType SUCCESS -Details "Permissions for $User on $($Item.FullName) have now been removed"
		    }Else{
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm User Permissions Removed" -EntryType ERROR -Details "Unable to remove permissions for $User on $($Item.FullName)"
		    }
		  }
		}
	  }
	}
	Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Remove NTFS Permissions" -EntryType HEADER -Details "Function End"
  }
}
