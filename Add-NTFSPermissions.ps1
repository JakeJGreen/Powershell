
# Current max runtime: 1.5 Seconds
Function Add-NTFSPermissions{
<#
  .SYNOPSIS
    Add NTFS permissions

  .DESCRIPTION
    Add NTFS permissions to a defined item

  .PARAMETER Target
    Mandatory. [String] Used to determine on which item to set the permissions

  .PARAMETER TargetUserDomain
    Optional. [String] Use to determine which user domain applies to the target user
	
  .PARAMETER TargetUser
    Mandatory. [String] Use to determine which user to set permissions for
	
  .PARAMETER ItemType
    Mandatory. Switch the type of item to add access to, examples: "File","Directory"

  .PARAMETER FileSystemRights
    Mandatory. Switch the level of access to set on an item, examples: "Read","Write","ReadandExecute","Modify","FullControl"
	
  .PARAMETER Inheritance
    Optional. Switch the level of inheritance to be set, examples: "ContainerInherit","ContainerInherit, ObjectInherit","Disable"
	
  .PARAMETER LogPath
    Optional. [String] Used to determine the destination of the output for this function
	
  .PARAMETER LogName
    Optional. [String] Used to determine the name of the log for this function
	
  .PARAMETER DebugLevel
    Optional. Switch the integer to determine the level of logging, examples: "1","2","3" - 1=ToScreen, 2=ToFile, 3=ToScreenandFile
    
  .INPUTS
    See parameters listed above
	
  .OUTPUTS
    Log file
    
  .NOTES
    Version:        1.0
    Author:         Jake Green
    Creation Date:  15/09/2021
    Purpose/Change: Initial function development and debug mode support
	
  .EXAMPLE
    Add-NTFSPermissions -Target C:\Temp -TargetUser jjgreen -ItemType Directory -FileSystemRights FullControl -Inheritance 'ContainerInherit, ObjectInherit'
#>
  [CmdletBinding()]
  Param(
	[Parameter(Mandatory=$True)][String]$Target,
	[Parameter(Mandatory=$False)][String]$TargetUserDomain = "$Env:USERDOMAIN",
	[Parameter(Mandatory=$True)][String]$TargetUser,
	[Parameter(Mandatory=$True)][ValidateSet("File","Directory")]$ItemType,
	[Parameter(Mandatory=$True)][ValidateSet("Read","Write","ReadandExecute","Modify","FullControl")]$FileSystemRights,
	[Parameter(Mandatory=$False)][ValidateSet("ContainerInherit","ContainerInherit, ObjectInherit")]$Inheritance,
	[Parameter(Mandatory=$False)][String]$LogPath = "C:\Temp",
	[Parameter(Mandatory=$False)][String]$LogName = "AddPermissionsLog",
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
	# Clear error variable 
	$Error = $Null
	$User = $TargetUserDomain + "\" + $TargetUser
	# Title
	Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Add NTFS Permissions" -EntryType HEADER -Details "Adding NTFS permissions - $Target - $TargetUser"
	Switch($ItemType){
	  "File"{
	    # Get item
	    $Item = Get-Item $Target
		If(!($Item)){
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Item" -EntryType ERROR -Details "Unable to retrieve item type $ItemType - $Target"
		  Break
		}ElseIf($Item.mode -eq "d-----"){
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Item" -EntryType ERROR -Details "Incorrect item type selected for $Target - $ItemType"
		  Break
		}
		$FileName = $Item.Name
	    If($Inheritance){
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Add NTFS Permissions" -EntryType ERROR -Details "Unable to set inherited permissions on item type $ItemType - $Target"
		  Break
		}
		Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Current Permissions" -EntryType NOTE -Details "Getting current permissions for: $Target"
		# Get current permissions 
		$ItemPermissions = Get-Acl -Path $Item.FullName -Audit
		If(!($ItemPermissions)){
		  #$ErrorMsg = $Error.Exception[1]
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Current Permissions" -EntryType ERROR -Details "Could not retrieve permissions for: $Target"
		}Else{
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check Current Permissions" -EntryType NOTE -Details "Checking permissions on $Target"
		  # Check current permissions
		  $CheckCurrentPermissions = $ItemPermissions.Access | Where {($_.IdentityReference -eq $User)}
		  # If check permissions returns a result
		  If($CheckCurrentPermissions){
		    # write log permissions already exist
		    Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check Current Permissions" -EntryType NOTE -Details "Permissions for $User already exist on: $Target - To overwright you will need to use Set-NTFSPermissions cmdlet"
		    # Return permissions
			$CheckCurrentPermissions
		  }Else{
		    # write log adding new permissions
			Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Adding New Permissions" -EntryType NOTE -Details "Proceeding to add proposed permissions Target: $Target - Permissions: $User | $FileSystemRights "
			# set permission arguements
            $Permissions = @("$User","$FileSystemRights","Allow")
		    # create file system access rule
		    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Permissions
		    # apply system access rule
            $ItemPermissions.SetAccessRule($AccessRule)
		    # set permissions according to new rule
		    Set-Acl -Path $ItemPermissions.Path -AclObject $ItemPermissions
			Start-Sleep -Milliseconds 100
			# Get permissions after changes made
	        $NewPermissions = Get-Acl -Path $Item.FullName -Audit
		    # Filter permissions to check newly set permissions exist
	        $CheckNewPerms = $NewPermissions.Access | Where {($_.IdentityReference -eq $User) -AND ($_.FileSystemRights -like "*$($FileSystemRights)*")}
	        # If filtered new permissions return false
		    If(!($CheckNewPerms)){
		      # report failure
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm New NTFS Permissions" -EntryType ERROR -Details "Unable to add NTFS permissions - $Target | $User - $FileSystemRights"
		    # If filtered new permissions return true
		    }Else{
		      # report success
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm New NTFS Permissions" -EntryType SUCCESS -Details "NTFS permissions added successfully - $Target | $User - $FileSystemRights"
			}
		  }
		}
	  }
	  "Directory"{
	    # Get item
	    $Item = Get-Item $Target
		If(!($Item)){
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Item" -EntryType ERROR -Details "Unable to retrieve item type $ItemType - $Target"
		  Break
		}ElseIf($Item.mode -ne "d-----"){
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Item" -EntryType ERROR -Details "Incorrect item type selected for $Target - $ItemType"
		  Break
		}
		$DirectoryName = $Item.Name
		Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Current Permissions" -EntryType NOTE -Details "Getting current permissions for: $Target"
		# Get current permissions 
		$ItemPermissions = Get-Acl -Path $Item.FullName -Audit
		If(!($ItemPermissions)){
		  #$ErrorMsg = $Error.Exception[1]
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retrieve Current Permissions" -EntryType ERROR -Details "Could not retrieve permissions for: $Target"
		}Else{
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check Current Permissions" -EntryType NOTE -Details "Checking permissions on $Target"
		  # If proposed permissions are not inherited
		  If(!($Inheritance)){
		    # Check current permissions
		    $CheckCurrentPermissions = $ItemPermissions.Access | Where {$_.IdentityReference -eq $User}
		    # If check permissions returns a result
			If($CheckCurrentPermissions){
		      # write log permissions already exist
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check Current Permissions" -EntryType NOTE -Details "Permissions for $User already exist on: $Target - To overwright you will need to use Set-NTFSPermissions cmdlet"
		      # Return permissions
			  $CheckCurrentPermissions
			}Else{
		      # write log adding new permissions
			  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Adding New Permissions" -EntryType NOTE -Details "Proceeding to add proposed permissions Target: $Target - Permissions: $User | $FileSystemRights"
		      # set permission arguements
              $Permissions = @("$TargetUser","$FileSystemRights","Allow")
		      # create file system access rule
		      $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Permissions
		      # apply system access rule
              $ItemPermissions.SetAccessRule($AccessRule)
		      # set permissions according to new rule
		      Set-Acl -Path $ItemPermissions.Path -AclObject $ItemPermissions
			  # Get permissions after changes made
	          $NewPermissions = Get-Acl -Path $Item.FullName -Audit
		      # Filter permissions to check newly set permissions exist
	          $CheckNewPerms = $NewPermissions.Access | Where {($_.IdentityReference -eq $User) -AND ($_.FileSystemRights -like "*$($FileSystemRights)*")}
	          # If filtered new permissions return false
		      If(!($CheckNewPerms)){
		        # report failure
		        Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm New NTFS Permissions" -EntryType ERROR -Details "Unable to add NTFS permissions - $Target | $User - $FileSystemRights"
		      # If filtered new permissions return true
		      }Else{
		        # report success
		        Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm New NTFS Permissions" -EntryType SUCCESS -Details "NTFS permissions added successfully - $Target | $User - $FileSystemRights"
		      }
		    }
		  # If proposed permissions are inherited
		  }Else{
		    # Check current permissions
	        $CheckCurrentPermissions = $ItemPermissions.Access | Where {$_.IdentityReference -eq $User}
	        If($CheckCurrentPermissions){
	          # write log permissions already exist
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Check Current Permissions" -EntryType NOTE -Details "Permissions for $User already exist on: $Target - To overwright you will need to use Set-NTFSPermissions cmdlet"
		      # Return permissions
			  $CheckCurrentPermissions
		    }Else{
		      # Write permissions do not currently exist adding new permissions
		      Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Adding New Permissions" -EntryType NOTE -Details "Proceeding to add proposed permissions Target: $Target - Permissions: $User | $FileSystemRights | $Inheritance"
	          Switch($Inheritance){
		        # Switch based on inheritance level
	            "ContainerInherit"{
		          # set permission arguements
		          $Permissions = @("$TargetUser","$FileSystemRights","$Inheritance","None","Allow")
			      # create file system access rule
		          $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Permissions
                  # apply system access rule
			      $ItemPermissions.SetAccessRule($AccessRule)
			      # set permissions according to new rule
		          Set-Acl -Path $ItemPermissions.Path -AclObject $ItemPermissions
		        }
		        "ContainerInherit, ObjectInherit"{
		          # set permission arguements
			      $Permissions = @("$TargetUser","$FileSystemRights","$Inheritance","None","Allow")
			      # create file system access rule
		          $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Permissions
                  # apply system access rule
			      $ItemPermissions.SetAccessRule($AccessRule)
		          # set permissions according to new rule
			      Set-Acl -Path $ItemPermissions.Path -AclObject $ItemPermissions
		        }
		      }
		      # Get permissions after changes made
	          $NewPermissions = Get-Acl -Path $Item.FullName -Audit
		      # Filter permissions to check newly set permissions exist
	          $CheckNewPerms = $NewPermissions.Access | Where {($_.IdentityReference -eq $User) -AND ($_.FileSystemRights -like "*$($FileSystemRights)*") -AND ($_.InheritanceFlags -eq $Inheritance)}
			  # If filtered new permissions return false
		      If(!($CheckNewPerms)){
		        # report failure
		        Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm NTFS Permissions" -EntryType ERROR -Details "Unable to add NTFS permissions - $Target | $User - $FileSystemRights - $Inheritance"
		      # If filtered new permissions return true
		      }Else{
		        # report success
		        Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Confirm NTFS Permissions" -EntryType SUCCESS -Details "NTFS permissions added successfully - $Target | $User - $FileSystemRights - $Inheritance"
			  }
	        }
		  }
		}
	  }
	}
    Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Add NTFS Permissions" -EntryType HEADER -Details "Function End"	
  }
}
