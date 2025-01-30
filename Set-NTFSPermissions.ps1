# Current max runtime: 2.5
Function Set-NTFSPermissions{
<#
  .SYNOPSIS
    Set NTFS permissions

  .DESCRIPTION
    Set NTFS permissions on a defined item

  .PARAMETER Target
    Mandatory. [String] Used to determine which item to set the permissions

  .PARAMETER TargetUserDomain
    Optional. [String] User to determine which user domain applies to the target user
	
  .PARAMETER TargetUser
    Mandatory. [String] User to determine which user to set permissions for
	
  .PARAMETER FileSystemRights
    Mandatory. Switch the type of item to set access on, examples: "File","Directory"
	
  .PARAMETER Backup
    Optional. Switch choose to create backup of previous permissions

  .PARAMETER FileSystemRights
    Mandatory. Switch the level of access to set on an item, examples: "Read","Write","ReadandExecute","Modify","FullControl","Owner"
	
  .PARAMETER Inheritance
    Optional. Switch the level of inheritance to be set, examples: "ContainerInherit","ContainerInherit, ObjectInherit","Disable"
	
  .PARAMETER LogPath
    Optional. [String] Used to determine the destination of the log for this function
	
  .PARAMETER LogName
    Optional. [String] Used to determine the name of the log for this function
	
  .PARAMETER DebugLevel
    Optional. Switch the integer to determine the level of logging, examples: "1","2","3" - 1=ToScreen, 2=ToFile, 3=ToScreenandFile
    
  .INPUTS
    See parameters listed above
	
  .OUTPUTS
    None.
    
  .NOTES
    Version:        1.0
    Author:         Jake Green
    Creation Date:  15/09/2021
    Purpose/Change: Initial function development and debug mode support
	
  .EXAMPLE
    
#>
  [CmdletBinding()]
  Param(
	[Parameter(Mandatory=$True)][String]$Target,
	[Parameter(Mandatory=$False)][String]$TargetUserDomain = "$Env:USERDOMAIN",
	[Parameter(Mandatory=$True)][String]$TargetUser,
	[Parameter(Mandatory=$True)][ValidateSet("File","Directory")]$ItemType,
	[Parameter(Mandatory=$True)][ValidateSet("Read","Write","ReadandExecute","Modify","FullControl","Owner")]$FileSystemRights,
	[Parameter(Mandatory=$False)][Switch]$Backup,
	[Parameter(Mandatory=$False)][ValidateSet("ContainerInherit","ContainerInherit, ObjectInherit")]$Inheritance,
	[Parameter(Mandatory=$False)][String]$LogPath = "C:\Temp",
	[Parameter(Mandatory=$False)][String]$LogName = "SetPermissionsLog",
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
	# clear error variable
	$Error = $null
	$User = $TargetUserDomain + "\" + $TargetUser
	# Title
	Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Set NTFS Permissions" -EntryType HEADER -Details "Setting NTFS Permissions - $Target - $TargetUser"
	# Switch File / Directory
    Switch($ItemType){
	  "File"{
	    # Get item
	    $Item = Get-Item $Target
	    If(!($Item)){
	      #$ErrorMsg = $Error.Exception[1]
		  # Write log could not find item
	      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Item" -EntryType ERROR -Details "Unable to retrieve item type $ItemType - $Target"
	    }ElseIf($Item.mode -eq "d-----"){
		  # Write log wrong item type selected for target
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Item" -EntryType ERROR -Details "Incorrect item type selected - $Target - $ItemType"
		}ElseIf($Inheritance){
		  # If inheritance write log cannot set inherited permissions on a file
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "File Inheritance" -EntryType ERROR -Details "Unable to set inherited permissions on item type $ItemType - $Target"
		}ElseIf($FileSystemRights -eq "Owner"){
		  # Get Item permissions
		  $Permissions = Get-Acl -Path $Item.FullName -Audit
		  If($Permissions.Owner -like "*$User*"){
		    # if proposed permissions already exist log and stop script
			Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check Current Owner" -EntryType NOTE -Details "Proposed owner already set on $($Item.FullName)"
		  }Else{
		    # Add current owner to log
		    $CurrentOwner = $Permissions.Owner
	        Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Backup Current Owner" -EntryType NOTE -Details "Current owner of $($Item.FullName) - $CurrentOwner"
		    Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel 2 -Operation "Backup Permission Entry" -EntryType NOTE -Details "$CurrentOwner"
		    # If current owner and new owner the same
			Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Set New Owner" -EntryType NOTE -Details "Setting new owner of $($Item.FullName) - $User"
			# Set new file owner
		    $NewOwner = New-Object System.Security.Principal.NTAccount("$User")
            $Permissions.SetOwner($NewOwner) | Out-Null
		    Set-Acl -Path $Permissions.Path -AclObject $Permissions
		    # Confirm new owner
		    $Permissions = Get-Acl -Path $Item.FullName -Audit
		    If($Permissions.Owner -eq "$User"){
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm New Owner" -EntryType SUCCESS -Details "New owner has been set: $User - $($Item.FullName)"
		    }Else{
		      #$ErrorMsg = $Error.Exception[1]
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm New Owner" -EntryType ERROR -Details "Unable to set new owner $($Item.FullName) - $User"
		    }
		  }
		}Else{
		  # Get Item permissions
		  $Permissions = Get-Acl -Path $Item.FullName -Audit
		  $PermissionsExist = $Permissions.Access | Where {($_.IdentityReference -eq $User) -AND ($_.FileSystemRights -like "*$($FileSystemRights)*") -AND ($_.InheritanceFlags -eq $Inheritance)} 
		  If($PermissionsExist){
		    # if proposed permissions already exist log and stop script
			Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check Current Permissions" -EntryType NOTE -Details "Proposed permissions are already set on $($Item.FullName)"
		  }Else{
		    # Remove current permissions
			If($Backup){
		      Remove-NTFSPermissions -Target $Item.FullName -TargetUser $User -Backup -LogPath $LogPath -LogName $LogName -DebugLevel $DebugLevel
		    }Else{
			  Remove-NTFSPermissions -Target $Item.FullName -TargetUser $User -LogPath $LogPath -LogName $LogName -DebugLevel $DebugLevel
			}
			# Set new permissions
		    Add-NTFSPermissions -Target $Item.FullName -TargetUser $User -ItemType $ItemType -FileSystemRights $FileSystemRights -LogPath $LogPath -LogName $LogName -DebugLevel $DebugLevel
		    # Confirm new permissions
		    $Permissions = Get-Acl -Path $Item.FullName -Audit
		    $ConfirmPermissions = $Permissions.Access | Where {($_.IdentityReference -eq $User) -AND ($_.FileSystemRights -like "*$($FileSystemRights)*")}
		    If($ConfirmPermissions){
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm New Permissions" -EntryType SUCCESS -Details "New permissions have been set: $User - $FileSystemRights - $($Item.FullName)"
		    }Else{
		      #$ErrorMsg = $Error.Exception[1]
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm New Permissions" -EntryType ERROR -Details "Unable to set new permissions $($Item.FullName) - $User"
		    }
		  }
		}
	  }
	  "Directory"{
	    # Get item
	    $Item = Get-Item $Target
	    If(!($Item)){
	      #$ErrorMsg = $Error.Exception[1]
		  # Write log could not find item
	      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Item" -EntryType ERROR -Details "Unable to retrieve item type $ItemType - $Target"
	    }ElseIf($Item.mode -ne "d-----"){
		  # Write log wrong item type selected for target
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Item" -EntryType ERROR -Details "Incorrect item type selected - $Target - $ItemType"
		}ElseIf($FileSystemRights -eq "Owner"){
		  # Get Item permissions
		  $Permissions = Get-Acl -Path $Item.FullName -Audit
		  If($Permissions.Owner -like "*$User*"){
		    # if proposed permissions already exist
			Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check Current Owner" -EntryType NOTE -Details "Proposed owner already set on $($Item.FullName)"
		  }Else{
		    # Add current owner to log
		    $CurrentOwner = $Permissions.Owner[0]
	        Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Backup Current Owner" -EntryType NOTE -Details "Current owner of $($Item.FullName) - $CurrentOwner"
		    Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Set New Owner" -EntryType NOTE -Details "Setting new owner of $($Item.FullName) - $User"
		    # Set new file owner
		    $NewOwner = New-Object System.Security.Principal.NTAccount("$User")
            $Permissions.SetOwner($NewOwner) | Out-Null
		    Set-Acl -Path $Permissions.Path -AclObject $Permissions
		    # Confirm new owner
		    $Permissions = Get-Acl -Path $Item.FullName -Audi
		    If($Permissions.Owner -eq "$User"){
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm New Owner" -EntryType SUCCESS -Details "New owner has been set: $User - $($Item.FullName)"
		    }Else{
		      #$ErrorMsg = $Error.Exception[1]
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm New Owner" -EntryType ERROR -Details "Unable to set new owner $($Item.FullName) - $User"
		    }
		  }
		}ElseIf($Inheritance){
		  # Get Item permissions
		  $Permissions = Get-Acl -Path $Item.FullName -Audit
		  $PermissionsExist = $Permissions.Access | Where {($_.IdentityReference -eq $User) -AND ($_.FileSystemRights -like "*$($FileSystemRights)*") -AND ($_.InheritanceFlags -eq $Inheritance)} 
		  If($PermissionsExist){
		    # if proposed permissions already exist log and stop script
			Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check Current Permissions" -EntryType NOTE -Details "Proposed permissions are already set on $($Item.FullName)"
		  }Else{
		    # Remove current permissions
		    If($Backup){
		      Remove-NTFSPermissions -Target $Item.FullName -TargetUser $User -Backup -LogPath $LogPath -LogName $LogName -DebugLevel $DebugLevel
		    }Else{
			  Remove-NTFSPermissions -Target $Item.FullName -TargetUser $User -LogPath $LogPath -LogName $LogName -DebugLevel $DebugLevel
			}
			# Set new permissions
		    Add-NTFSPermissions -Target $Item.FullName -TargetUser $User -ItemType $ItemType -FileSystemRights $FileSystemRights -Inheritance $Inheritance -LogPath $LogPath -LogName $LogName -DebugLevel $DebugLevel	  
	      }
		}Else{
		  # Get Item permissions
		  $Permissions = Get-Acl -Path $Item.FullName -Audit
		  $PermissionsExist = $Permissions.Access | Where {($_.IdentityReference -eq $User) -AND ($_.FileSystemRights -like "*$($FileSystemRights)*")} 
		  If($PermissionsExist){
		    # if proposed permissions already exist log and stop script
			Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check Current Permissions" -EntryType NOTE -Details "Proposed permissions are already set on $($Item.FullName)"
		  }Else{
		    # Remove current permissions
			If($Backup){
		      Remove-NTFSPermissions -Target $Item.FullName -TargetUser $User -Backup -LogPath $LogPath -LogName $LogName -DebugLevel $DebugLevel
		    }Else{
			  Remove-NTFSPermissions -Target $Item.FullName -TargetUser $User -LogPath $LogPath -LogName $LogName -DebugLevel $DebugLevel
			}
		    # Set new permissions
		    Add-NTFSPermissions -Target $Item.FullName -TargetUser $User -ItemType $ItemType -FileSystemRights $FileSystemRights -LogPath $LogPath -LogName $LogName -DebugLevel $DebugLevel
		  }
		}
 	  }
	}
	Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Set NTFS Permissions" -EntryType HEADER -Details "Function End"
  }
}
