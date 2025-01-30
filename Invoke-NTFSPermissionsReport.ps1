Function Invoke-NTFSPermissionsReport{
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True)][ValidateSet("All","Directory","File")]$ItemType,
	[Parameter(Mandatory=$True)][String]$TargetPath,
	[Parameter(Mandatory=$False)][String]$OutputPath = (Invoke-NTFSTemplate).OutputPath,
	[Parameter(Mandatory=$False)][String]$LogPath = (Invoke-NTFSTemplate).LogPath,
	[Parameter(Mandatory=$False)][String]$LogName = (Invoke-NTFSTemplate).LogName
  )
  Process{
    # Concantenate full log path
    $FullLogPath = $LogPath + $LogName
	# Test log exists if not then create it
    If(Test-Path $FullLogPath){
      Write-Host "Log file available" -ForegroundColor Green
	}Else{
	  New-Item -Path $FullLogPath -ItemType File | Out-Null
	  Write-Host "Log file created" -ForegroundColor Green
	}
	# Log setup add first line of csv to serve as headers
	Try{
	  Add-Content -Path $FullLogPath -Value "Date,Time,Username,Action,Status,Details"
	}Catch{
	  # if cannot add content wait half a second and retry
	  Sleep -Milliseconds 500
	  Add-Content -Path $FullLogPath -Value "Date,Time,Username,Action,Status,Details" -ErrorAction SilentlyContinue
	}
	# Get the time
	$Time = (Get-Date -Format hh:mm:ss)
	Try{
	  Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Log Creation,Note,N/A"
	}Catch{
	  Sleep -Milliseconds 500
	  Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Log Creation,Note,N/A" -ErrorAction SilentlyContinue
	}
	$Validate = Test-Path $TargetPath
	If(!($Validate)){
	  Write-Host "Could not locate target path: $TargetPath" -ForegroundColor Red
      $ErrorMsg = $Error.Exception | Select -First 1
      # Get the time
      $Time = (Get-Date -Format hh:mm:ss)
      # Add to log
      Try{
        Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Validate Target Path,Error,Could not locate target path: $TargetPath"
      }Catch{
        Sleep -Milliseconds 500
        Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Validate Target Path,Error,Could not locate target path: $TargetPath" -ErrorAction SilentlyContinue
      }
	  Break
	}Else{
	  Write-Host "Target path successfully located: $TargetPath" -ForegroundColor Green
      $ErrorMsg = $Error.Exception | Select -First 1
      # Get the time
      $Time = (Get-Date -Format hh:mm:ss)
      # Add to log
      Try{
        Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Validate Target Path,Error,Target path successfully located: $TargetPath)"
      }Catch{
        Sleep -Milliseconds 500
        Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Validate Target Path,Error,Target path successfully located: $TargetPath)" -ErrorAction SilentlyContinue
      }
	}
	If($OutputPath -like "*\"){
	  # Remove '\' from the end of output path if it's there
	  $OutputPath = $OutputPath.Trim("\")
	}
	# Create empty array
	$Information = @()
	# Retreive all items in top level folder
	Switch($ItemType){
	  "All"{$AllItems = Get-ChildItem $TargetPath -Recurse}
	  "Directory"{$AllItems = Get-ChildItem $TargetPath -Directory -Recurse}
	  "File"{$AllItems = Get-ChildItem $TargetPath -File -Recurse}
	}
	If(!($AllItems)){
      Write-Host "Could not retrieve child items of $TopLevelFolder" -ForegroundColor Red
      $ErrorMsg = $Error.Exception | Select -First 1
      # Get the time
      $Time = (Get-Date -Format hh:mm:ss)
      # Add to log
      Try{
        Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Items,Error,Could not retrieve child items of $TopLevelFolder - $($ErrorMsg)"
      }Catch{
        Sleep -Milliseconds 500
        Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Items,Error,Could not retrieve child items of $TopLevelFolder - $($ErrorMsg)" -ErrorAction SilentlyContinue
      }
    }Else{
      Write-Host "Item count for $TopLevelFolder is: $($AllItems.Count)" -ForegroundColor Green
      # Get the time
      $Time = (Get-Date -Format hh:mm:ss)
      # Add to log
      Try{
        Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Items,Success,Item count for $TopLevelFolder is: $($AllItems.Count)"
      }Catch{
        Sleep -Milliseconds 500
        Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Items,Success,Item count for $TopLevelFolder is: $($AllItems.Count)" -ErrorAction SilentlyContinue
      }
      # ===== Progress Bar =====
      # Reset counter
      $i = 0
      # Set Activity Title
      $Activity = "Collecting $ItemType `& Permission Data"
      $Count = $AllItems.Count
      # ========================
      ForEach($Item in $AllItems){
        # ===== Progress Bar =====
        # Add to counter
        $i ++
        # Calculate percent complete
        $PercentComplete = ($i /$Count*100)
        # Calculate status
        $Status = "$i of $Count | %Complete: $PercentComplete"
        # Enter task name
        $Task = "Checking Access to: $($Item.FullName)"
        # Write progress
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $Task
        # ========================
        # Get folder permissions
        $Permissions = Get-Acl $Item.FullName
        If(!($Permissions)){
	      Write-Host "Could not retrieve permissions for $Item.FullName" -ForegroundColor Red
          $ErrorMsg = $Error.Exception | Select -First 1
          # Get the time
          $Time = (Get-Date -Format hh:mm:ss)
          # Add to log
          Try{
            Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Item Permissions,Error,Could not retrieve item permissions for `'$($Item.Name)`' - $($ErrorMsg)"
          }Catch{
            Sleep -Milliseconds 500
            Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Item Permissions,Error,Could not retrieve item permissions for `'$($Item.Name)`' - $($ErrorMsg)" -ErrorAction SilentlyContinue
          }
        }Else{
	      Write-Host "Permissions for `'$($Folder.Name)`' retrieved successfully" -ForegroundColor Green
          # Get the time
          $Time = (Get-Date -Format hh:mm:ss)
          # Add to log
          Try{
            Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Item Permissions,Success,Permissions for `'$($Item.Name)`' retrieved successfully"
          }Catch{
            Sleep -Milliseconds 500
            Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Item Permissions,Success,Permissions for `'$($Item.Name)`' retrieved successfully" -ErrorAction SilentlyContinue
          }
          # Loop retrieved permissions
          ForEach($PermissionRecord in $Permissions){
            $AccessRecordItem = 0
	        $AccessRecords = $PermissionRecord.Access
            $AccessRecordCount = $AccessRecords.Count
            Do{ # Loop until conditions are met
	          $AccessRecord = $AccessRecords[$AccessRecordItem]
		      If(!($AccessRecord)){
		        Write-Host "Could not retrieve access record for $($Item.FullNameName): Owner is $($PermissionRecord.Owner)" -ForegroundColor Red
			    $ErrorMsg = $Error.Exception | Select -First 1
			    # Get the time
			    $Time = (Get-Date -Format hh:mm:ss)
			     # Add to log
			    Try{
			      Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Individual Access Permissions,Error,Could not retrieve access record for $($Item.FullName): Owner is $($PermissionRecord.Owner) - $($ErrorMsg)"
			    }Catch{
			      Sleep -Milliseconds 500
			      Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Individual Access Permissions,Error,Could not retrieve access record for $($Item.FullName): Owner is $($PermissionRecord.Owner) - $($ErrorMsg)" -ErrorAction SilentlyContinue
			    }
		      }Else{
	            Write-Host "Access Record $AccessRecordItem of $AccessRecordCount | Access record for $($Item.FullName): $($AccessRecord.IdentityReference)" -ForegroundColor Yellow
			    # Get the time
			    $Time = (Get-Date -Format hh:mm:ss)
			    # Add to log
			    Try{
			      Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Individual Access Permissions,Success,Access Record $AccessRecordItem of $AccessRecordCount | Access record for $($Item.FullName): $($AccessRecord.IdentityReference)"
			    }Catch{
			      Sleep -Milliseconds 500
			      Add-Content -Path $FullLogPath -Value "`r`n$Date,$Time,$($env:UserName),Retreive Individual Access Permissions,Success,Access Record $AccessRecordItem of $AccessRecordCount | Access record for $($Item.FullName): $($AccessRecord.IdentityReference)" -ErrorAction SilentlyContinue
			    }
                $Information += New-Object -TypeName PSObject -Property @{Name = $Item.Name;
																                FullName = $Item.FullName;
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
      # Export information to output path in correct order
	  $DateTime = (Get-Date -format ddMMyyyy_hhmmss)
      $Information | Select Name,Root,Parent,FullName,LastAccessTime,LastWriteTime,Owner,IdentityReference,FileSystemRights,AccessControlType,IsInherited,InheritanceFlags,PropagationFlags | Export-Csv "$OutputPath\$($DateTime)_$($ItemType)PermissionsReport.csv" -NoTypeInformation -Force
      # Return information
	  Return $Information
	}
  }
}
