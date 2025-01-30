# Current max runtime: 356 Milliseconds
Function Get-NTFSPermissions{
<#
  .SYNOPSIS
    Retrieve NTFS permissions 

  .DESCRIPTION
    Retrieve NTFS permissions for defined target

  .PARAMETER TargetPath
    Mandatory. [String] Used to determine target path
	
  .PARAMETER LogPath
    Optional. [String] Used to determine the destination of the log for this function
	
  .PARAMETER LogName
    Optional. [String] Used to determine the name of the log for this function

  .PARAMETER DebugLevel
    Optional. Switch the integer to determine the level of logging, examples: "1","2","3" - 1=ToScreen, 2=ToFile, 3=ToScreenandFile
    
  .INPUTS
    See parameters listed above
	
  .OUTPUTS
    Report of all items and permissions
    
  .NOTES
    Version:        1.0
    Author:         Jake Green
    Creation Date:  <Enter date>
    Purpose/Change: Initial function development and debug mode support
	
  .EXAMPLE
    <Enter example>
    
#>  
  [CmdletBinding()]
  Param(
	[Parameter(Mandatory=$True)][String]$TargetPath,
	[Parameter(Mandatory=$False)][String]$LogPath = "C:\Temp",
	[Parameter(Mandatory=$False)][String]$LogName = "PermissionsLog",
	[Parameter(Mandatory=$False)][ValidateSet(1,2,3)]$DebugLevel = 3
  )
  Process{
    # Create log file
    New-LogFile -LogPath $LogPath -LogName $LogName
	# Title
	Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Get NTFS Permissions" -EntryType HEADER -Details "Retreiving NTFS permissions for $TargetPath"
	# Validate target path
	$Validate = Test-Path $TargetPath
	If(!($Validate)){
	  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Validate Target Path" -EntryType ERROR -Details "Could not locate target path: $TargetPath"
	  Break
	}Else{
	  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Validate Target Path" -EntryType SUCCESS -Details "Target path successfully located: $TargetPath"
	}
	# Create empty array
	$Information = @()
	# Retreive item
	$Item = Get-Item $TargetPath -ErrorAction SilentlyContinue
	If($Item.Mode -eq "d-----"){
	  $ItemType = "Directory"
	}Else{
	  $ItemType = "File"
	}
	If(!($TargetPath)){
      # Get latest entry of error variable
	  $ErrorMsg = $Error.Exception | Select -First 1
	  # If could not retrieve item write error to log
	  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retreive Item" -EntryType ERROR -Details "Could not retrieve item of $TargetPath - ERROR: $($ErrorMsg) "
    }Else{
	  # If can retrieve item write success to log
	  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retreive Item" -EntryType SUCCESS -Details "$($Item.FullName) "
	  # Get permissions for target path
	  $Permissions = Get-Acl $Item.FullName -Audit
	  # If could not retrieve item permissions write error to log
	  If(!($Permissions)){
          # Get latest entry of error variable
		  $ErrorMsg = $Error.Exception | Select -First 1
		  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retreive Item Permissions" -EntryType ERROR -Details "Could not retrieve item permissions for `'$($Item.Name)`' - ERROR: $($ErrorMsg)"
	  # If can retrieve item write success to log  
      }Else{
	    Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retreive Item Permissions" -EntryType SUCCESS -Details "Permissions for `'$($Item.Name)`' retrieved successfully"
		# Loop retrieved permissions
        ForEach($PermissionRecord in $Permissions){
          $AccessRecordItem = 0
	      $AccessRecords = $PermissionRecord.Access
          $AccessRecordCount = $AccessRecords.Count
          Do{ # Loop until conditions are met
		    # Get individual user access
	        $AccessRecord = $AccessRecords[$AccessRecordItem]
			# If could not retrieve access record write error to log
		    If(!($AccessRecord)){
			  # Get latest error in error variable
		      $ErrorMsg = $Error.Exception | Select -First 1
			  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retreive Individual Access Permissions" -EntryType ERROR -Details "Could not retrieve access record for $($Item.FullName): Owner is $($PermissionRecord.Owner) - ERROR: $($ErrorMsg)"
		    }Else{
			  Write-LogFile -LogName $LogName -LogPath $LogPath -DebugLevel $DebugLevel -Operation "Retreive Individual Access Permissions" -EntryType SUCCESS -Details "Access Record $AccessRecordItem of $AccessRecordCount | Access record for $($Item.FullName): $($AccessRecord.IdentityReference)"
              $Information += New-Object -TypeName PSObject -Property @{Name = $Item.Name;
																        FullName = $Item.FullName;
																		ItemType = $ItemType;
															            Parent = $Item.Parent;
																        Root = $Item.Root;
																        LastAccessTime = $Item.LastAccesstime;
																        LastWriteTime = $Item.LastWriteTime;
																	    Owner = $PermissionRecord.Owner;
																	    FileSystemRights = $AccessRecord.FileSystemRights;
																	    AccessControlType = $AccessRecord.AccessControlType;
																	    IdentityReference = $AccessRecord.IdentityReference;
																	    IsInherited = $AccessRecord.IsInherited;
																	    InheritanceFlags = $AccessRecord.InheritanceFlags;
																	    PropagationFlags = $AccessRecord.PropagationFlags}
	          $AccessRecordItem ++
		    }
          }Until($AccessRecordItem -eq $AccessRecordCount)
        }     
      }
    }
	Return $Information
  }
}
