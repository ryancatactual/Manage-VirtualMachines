<#

.Synopsis
   This script, when fed a properly populated CSV file, will deploy virtual machines to the infrastructure.

.DESCRIPTION
   For each item within the CSV, this cmdlet will deploy virtual machines, IP address them, modify their
   network backing, and can be configured to also run local scripts on the virtual machines for further
   modification.

   AUTHOR: SSGT CASEY RYAN
           casey.ryan@usmc.mil
           20190117

.EXAMPLE
   Manage-VirtualMachines -File C:\Users\Example\Desktop\VMs.csv -VMType DC -NetworkMod:$true -StartMachines:$true

.EXAMPLE
   Manage-VirtualMachines -File C:\Users\Example\Desktop\VMs.csv -VMType WIN10 -NetworkMod:$true -StartMachines:$false

#>

function Manage-VirtualMachines
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        # Full path to the CSV file being used to deploy virtual machines
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $File,

        # Define which particular machines to create. Choices are: DC, WIN10, WIN7, SC, NS
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        $VMType,

        # Define the name of the snapshot you wish to create
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        $SnapshotName,

        # Define the description of the snapshot you wish to create
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        $SnapshotDesc,

        # Declare whether machines should be created 
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [switch]$Create,

        # Declare whether machines should join domain 
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [switch]$StartMachines,

        # Declare whether DCs should be promoted 
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [switch]$DCSetup,

        # Declare script location to copy to DCs 
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [string]$ScriptLoc,

        # Declare whether machines should join domain 
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [switch]$DomainJoin,

        # Declare whether machines should have their networks modified 
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [switch]$NetworkMod,

        # Declare whether machines should have their networks modified 
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [switch]$CreateCSV,

        # Declare whether machines should have their networks modified 
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [switch]$Clone

    )

    Begin
    {

        $CheckVIConnection = $global:defaultviserver.count

        if($CheckVIConnection -eq 0){
        
            Write-Host "Not connected to VCenter! Connect to VCenter and reattempt command!" -ForegroundColor Red

            Start-Sleep 1

            $Continue = $false
        
            }

        else{

            $Continue = $true

            Get-OSCustomizationSpec | Remove-OSCustomizationSpec -Confirm:$false -Server vcenter

            $VCSession = Get-View $global:DefaultVIServer.ExtensionData.Client.ServiceContent.SessionManager
        
            $VCUser = $VCSession.CurrentSession.Username
        
            $VCUser = $VCUser.Split('\')[1]
            
            }

    }

    Process
    {

        if($CreateCSV){

            $CustCSV = [pscustomobject]@{ 

                                          Name =  '1XXMEUWIN10'
                                          OS = 'Windows'
                                          Template = '1XXMEUWIN10'
                                          TempLoc = 'Templates'
                                          Folder = 'Student 1XX'
                                          Network1 = '1XX_MEU_1'
                                          Network2 = '1XX_MEU_2'
                                          Network3 = '1XX_MEU_3'
                                          IP = '10.10.10.100'
                                          Netmask = '255.255.255.0'
                                          Gateway = '10.10.10.1'
                                          DNS1 = '10.10.10.30'
                                          AccountName = 'student'
                                          AccountPassword = 'p@$$w0rd' 
                                      
                                        }

            $CustCSV | Export-Csv -Path "$env:USERPROFILE\DeployVMs.csv" -NoTypeInformation
            
            Write-Host "CSV created! File path is: $env:USERPROFILE\DeployVMs.csv" -ForegroundColor Yellow
            
            Start-Process "$env:USERPROFILE\DeployVMs.csv"

            $Continue = $false
        
            }

        $VMs = if($Continue){
            
            $Test = Test-Path $File -ErrorAction SilentlyContinue

            if($Test){
            
                Import-Csv $File

                }
            
            }

        $DCs = $VMs | Where-Object {$_.Name -match 'MEUDC'} | Sort-Object
            
        $SRVs = $VMs | Where-Object {$_.Name -match 'MEUSRV'} | Sort-Object
            
        $CUCMs = $VMs | Where-Object {$_.Name -match 'CUCM'} | Sort-Object
            
        $WIN10s = $VMs | Where-Object {$_.Name -match 'MEUWIN10'} | Sort-Object
           
        $WIN7s = $VMs | Where-Object {$_.Name -match 'MEUWIN7'} | Sort-Object
            
        $NSs = $VMs | Where-Object {$_.Name -match 'MEUNS'} | Sort-Object
            
        $SCs = $VMs | Where-Object {$_.Name -match 'MEUSC'} | Sort-Object
            
        $ESXIVMs = $VMs | Where-Object {$_.Name -match 'MEUESXI'} | Sort-Object

        $VMCount = $DCs.Name.Count + $SRVs.Name.Count + $CUCMs.Name.Count + $WIN10s.Name.Count + $WIN7s.Name.Count + $NSs.Name.Count + $SCs.Name.Count + $ESXIVMs.Name.Count

        if($VMs.length -eq 0 -or !$Test -and $Continue){
        
            Write-Host "CSV doesn't exist or CSV empty!" -ForegroundColor Red
            
            Start-Sleep 1

            $Continue = $false
            
            }

        elseif($VMCount -eq 0 -and $Test -and $Continue){

            Write-Host "No matching VM names found in CSV! Check VM 'Name' for the correct format!" -ForegroundColor Red
            
            Start-Sleep 1

            $Continue = $false

        }

        elseif(!$CreateCSV -and $Continue){

            if($VMType -eq 'DC' -and $Create){
        
                foreach($DC in $DCs){

                    Write-Host "Creating $($DC.Name)..." -ForegroundColor Green
                
                    Start-Sleep 1

                    $Datastore = @($(Get-Datastore | Sort-Object -Property FreeSpaceGB -Descending | Where-Object {$_.name -match "vsan"}).name)
                    
                    $ESXIHost = @($(Get-VMHost | Where-Object {$_.Name -match 'fx2esx' -and $_.Name -notmatch 'esx06'} | Sort-Object -Property MemoryUsageGB | Sort-Object -Property MemoryTotalGB -Descending | Sort-Object -Property CpuUsageMhz | Sort-Object -Property CpuTotalMhz -Descending).name)
                
                    if(!$Clone){

                        Get-OSCustomizationSpec -ErrorAction SilentlyContinue -Name $DC.Name | Remove-OSCustomizationSpec -ErrorAction SilentlyContinue -Confirm:$false
                    
                        $OSCustomSpec = New-OSCustomizationSpec -OSType Windows -ChangeSid:$true -Name $DC.Name -Type Persistent -NamingScheme fixed -NamingPrefix $DC.Name -FullName $DC.AccountName -AdminPassword $DC.AccountPassword -OrgName workgroup -Workgroup workgroup
                    
                        Get-OSCustomizationSpec $OSCustomSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode:UseStaticIP -IpAddress $DC.IP -SubnetMask $DC.Netmask -DefaultGateway $DC.Gateway -Dns $DC.DNS1 | Out-Null    

                        New-VM -Name $DC.Name -Template $DC.Template -Location $DC.Folder -OSCustomizationSpec $DC.Name -ResourcePool $(Get-Random $ESXIHost) -Datastore $Datastore[0] -DiskStorageFormat Thin -ErrorAction Inquire -RunAsync | out-null
                
                        }

                    else{

                        New-VM -Name $DC.Name -Template $DC.Template -Location $DC.Folder -ResourcePool $(Get-Random $ESXIHost) -Datastore $Datastore[0] -DiskStorageFormat Thin -ErrorAction Inquire -RunAsync | out-null
                        
                        }
                
                    }
        
                }

            if($VMType -eq 'WIN10' -and $Create){
        
                foreach($WIN10 in $WIN10s){

                    Write-Host "Creating $($WIN10.Name)..." -ForegroundColor Green

                    Start-Sleep 1

                    $Datastore = @($(Get-Datastore | Sort-Object -Property FreeSpaceGB -Descending | Where-Object {$_.name -match "vsan"}).name)
                    
                    $ESXIHost = @($(Get-VMHost | Where-Object {$_.name -match 'fx2esx' -and $_.name -notmatch 'esx06'} | Sort-Object -Property MemoryUsageGB | Sort-Object -Property MemoryTotalGB -Descending | Sort-Object -Property CpuUsageMhz | Sort-Object -Property CpuTotalMhz -Descending).name)
                
                    if(!$Clone){

                        if($DomainJoin){

                            $MEU = $($WIN10.IP).Split('.')[2]
                        
                            Get-OSCustomizationSpec $WIN10.Name -ErrorAction SilentlyContinue | Remove-OSCustomizationSpec -Confirm:$false -ErrorAction SilentlyContinue

                            $OSCustomSpec = New-OSCustomizationSpec -OSType Windows -ChangeSid:$true -Name $WIN10.Name -Type Persistent -NamingScheme fixed -NamingPrefix $WIN10.Name -FullName $WIN10.AccountName -AdminPassword $WIN10.AccountPassword -DomainUsername "$MEU`MEUDC\$($DC.AccountName)" -DomainPassword $DC.AccountPassword -OrgName "$MEU`MEU.usmc.mil" -Domain "$MEU`MEU.usmc.mil"
                        
                            Get-OSCustomizationSpec $OSCustomSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode:UseStaticIP -IpAddress $WIN10.IP -SubnetMask $WIN10.Netmask -DefaultGateway $WIN10.Gateway -Dns $WIN10.DNS1 | Out-Null    
                
                            }

                        else{

                            Get-OSCustomizationSpec $WIN10.Name -ErrorAction SilentlyContinue | Remove-OSCustomizationSpec -Confirm:$false -ErrorAction SilentlyContinue
                        
                            $OSCustomSpec = New-OSCustomizationSpec -OSType Windows -ChangeSid:$true -Name $WIN10.Name -Type Persistent -NamingScheme fixed -NamingPrefix $WIN10.Name -FullName $WIN10.AccountName -AdminPassword $WIN10.AccountPassword -OrgName workgroup -Workgroup workgroup
                        
                            Get-OSCustomizationSpec $OSCustomSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode:UseStaticIP -IpAddress $WIN10.IP -SubnetMask $WIN10.Netmask -DefaultGateway $WIN10.Gateway -Dns $WIN10.DNS1 | Out-Null    
                
                            }

                        New-VM -Name $WIN10.Name -Template $WIN10.Template -Location $WIN10.Folder -OSCustomizationSpec $WIN10.Name -ResourcePool $(Get-Random $ESXIHost) -Datastore $Datastore[0] -DiskStorageFormat Thin -ErrorAction Inquire -RunAsync | out-null
                    
                        }

                    else{
                
                        New-VM -Name $WIN10.Name -Template $WIN10.Template -Location $WIN10.Folder -ResourcePool $(Get-Random $ESXIHost) -Datastore $Datastore[0] -DiskStorageFormat Thin -ErrorAction Inquire -RunAsync | out-null
                    
                        }

                    }
                        
                }

            if($VMType -eq 'CUCM' -and $Create){
        
                foreach($CUCM in $CUCMs){

                    Write-Host "Creating $($CUCM.Name)..." -ForegroundColor Green
                    
                    Start-Sleep 1

                    $Datastore = @($(Get-Datastore | Sort-Object -Property FreeSpaceGB -Descending | Where-Object {$_.name -match "vsan"}).name)
                    
                    $ESXIHost = @($(Get-VMHost | Where-Object {$_.name -match 'fx2esx' -and $_.name -notmatch 'esx06'} | Sort-Object -Property MemoryUsageGB | Sort-Object -Property MemoryTotalGB -Descending | Sort-Object -Property CpuUsageMhz | Sort-Object -Property CpuTotalMhz -Descending).name)
                
                    New-VM -Name $CUCM.Name -Template $CUCM.Template -Location $CUCM.Folder -ResourcePool $(Get-Random $ESXIHost) -Datastore $Datastore[0] -DiskStorageFormat Thin -ErrorAction Inquire -RunAsync | out-null
                    
                    }
        
                }

            if($VMType -eq 'HOST' -and $Create){
           
                foreach($ESXIVM in $ESXIVMs){

                    Write-Host "Creating $($ESXIVM.Name)..." -ForegroundColor Green
                    
                    Start-Sleep 1

                    $Datastore = @($(Get-Datastore | Sort-Object -Property FreeSpaceGB -Descending | Where-Object {$_.name -match "vsan"}).name)
                    
                    $ESXIHost = @($(Get-VMHost | Where-Object {$_.name -match 'fx2esx' -and $_.name -notmatch 'esx06'} | Sort-Object -Property MemoryUsageGB | Sort-Object -Property MemoryTotalGB -Descending | Sort-Object -Property CpuUsageMhz | Sort-Object -Property CpuTotalMhz -Descending).name)
                
                    New-VM -Name $ESXIVM.Name -Template $ESXIVM.Template -Location $ESXIVM.Folder -ResourcePool $(Get-Random $ESXIHost) -Datastore $Datastore[0] -DiskStorageFormat Thin -ErrorAction Inquire -RunAsync | out-null
                        
                    }
        
                }

            if($Create -and $Continue){

                do{
            
                    $Tasks = Get-Task | Where-Object {$_.Name -match 'clone' -and $_.State -match 'running' -and $_.UID -match $VCUser} 
                    
                    $Running = 0
                    
                    $Percent = 0

                    foreach($Task in $Tasks){

                        $Percent += $Task.PercentComplete
                        
                        if($Task.state -match "Running"){
                    
                            $Running++
                    
                            }
                
                        }

                    $Total = ($Percent/$Tasks.count)

                    Clear-Host
                    
                    Write-Host "VMs still deploying, $([math]::Round($($Total),2))`% complete..." -ForegroundColor Yellow
                    
                    Start-Sleep 1
            
                   }

                while($Running -ne 0)
        
                }
    
            }

    }

    End
    {

        if($NetworkMod -and $Continue){
        
            if($VMType -eq 'DC'){
        
                foreach($DC in $DCs){
                
                    Write-Host "Configuring $($DC.Name)'s network adapter..." -ForegroundColor Green

                    Get-VM $DC.name | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $DC.Network1 -Confirm:$false -ErrorAction SilentlyContinue -RunAsync | out-null
                
                    }
            
                }
        
            elseif($VMType -eq 'WIN10'){
            
                foreach($WIN10 in $WIN10s){
                
                    Write-Host "Configuring $($WIN10.Name)'s network adapter..." -ForegroundColor Green

                    Get-VM $WIN10.name | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $WIN10.Network1 -Confirm:$false -ErrorAction SilentlyContinue -RunAsync | out-null
                
                    }
            
                }

            elseif($VMType -eq 'CUCM'){
            
                foreach($CUCM in $CUCMs){
                
                    Write-Host "Configuring $($CUCM.Name)'s network adapter..." -ForegroundColor Green

                    Get-VM $CUCM.name | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $CUCM.Network1 -Confirm:$false -ErrorAction silentlycontinue -RunAsync | out-null
                
                    }
            
                }

            elseif($VMType -eq 'HOST'){
            
                foreach($ESXIVM in $ESXIVMs){
                
                    Write-Host "Configuring $($ESXIVM.Name)'s network adapters..." -ForegroundColor Green

                    Get-VM $ESXIVM.Name | Get-NetworkAdapter -Name 'Network Adapter 1' -ErrorAction SilentlyContinue | Set-NetworkAdapter -Portgroup $ESXIVM.Network1 -Confirm:$false -ErrorAction silentlycontinue -RunAsync | out-null

                    Get-VM $ESXIVM.Name | Get-NetworkAdapter -Name 'Network Adapter 2' -ErrorAction SilentlyContinue | Set-NetworkAdapter -Portgroup $ESXIVM.Network2 -Confirm:$false -ErrorAction silentlycontinue -RunAsync | out-null
                    
                    Get-VM $ESXIVM.Name | Get-NetworkAdapter -Name 'Network Adapter 3' -ErrorAction SilentlyContinue | Set-NetworkAdapter -Portgroup $ESXIVM.Network3 -Confirm:$false -ErrorAction silentlycontinue -RunAsync | out-null                    
                
                    }
            
                }

            }

        if($StartMachines -and $Continue){
        
            if($VMType -eq 'DC'){
        
                foreach($DC in $DCs){

                    Write-Host "Starting $($DC.Name)..." -ForegroundColor Green
                
                    Start-VM $($DC.Name) -RunAsync | Out-Null

                    }
                
                }
        
            elseif($VMType -eq 'WIN10'){
        
                foreach($WIN10 in $WIN10s){

                    Write-Host "Starting $($WIN10.Name)..." -ForegroundColor Green
                
                    Start-VM $($WIN10.Name) -RunAsync | Out-Null

                    }
        
                }

            elseif($VMType -eq 'ESXIVM'){
        
                foreach($ESXIVM in $ESXIVMs){

                    Write-Host "Starting $($ESXIVM.Name)..." -ForegroundColor Green
                
                    Start-VM $($ESXI.Name) -RunAsync | Out-Null

                    }
        
                }

            }

        if($DCSetup -and $Continue){

            $ScriptCheck = Invoke-VMScript -VM $DCs.name -GuestUser $DCs.AccountName -GuestPassword $DCs.AccountPassword -ScriptType Powershell -ScriptText 'Get-Item C:\Users\Administrator\Desktop\Prepare-Domain.ps1' -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null

            if($ScriptCheck -match 'cannot find path'){

                Write-Host "Copying script to DCs..." -ForegroundColor Green

                Copy-VMGuestFile -LocalToGuest -Source $ScriptLoc -VM $DCs.name -GuestUser $DCs.AccountName -GuestPassword $DCs.AccountPassword -Destination 'C:\Users\Administrator\Desktop\' -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null

                }

            Write-Host "Executing script on DCs..." -ForegroundColor Green

            Invoke-VMScript -VM $DCs.name -GuestUser $DCs.AccountName -GuestPassword $DCs.AccountPassword -ScriptType Powershell -ScriptText 'C:\Users\Administrator\Desktop\Prepare-Domain.ps1' -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -RunAsync | Out-Null

            Write-Host "First run: DCs should restart after enabling features`r`nSecond run: Check for creation of " -ForegroundColor Green

            }

        if($SnapshotName -and $Continue){

            if($VMType -eq 'DC'){
        
                foreach($DC in $DCs){

                    Write-Host "Stopping $($DC.name)...." -ForegroundColor Yellow

                    Stop-VM -VM $DC.name -Kill -Confirm:$false

                    if($SnapshotDesc){

                        Write-Host "Creating snapshot $SnapshotDesc for $($DC.name)...." -ForegroundColor Green

                        New-Snapshot -VM $DC.name -Name $SnapshotName -Description $SnapshotDesc -Confirm:$false

                        }

                    else{

                        Write-Host "Creating snapshot for $($DC.name)...." -ForegroundColor Green

                        New-Snapshot -VM $DC.name -Name $SnapshotName -Description "Created by $($VCUser) on $(Get-Date)" -Confirm:$false

                        }
                        
                    }

                }
        
            elseif($VMType -eq 'WIN10'){
        
                foreach($WIN10 in $WIN10s){

                    Write-Host "Stopping $($WIN10.name)...." -ForegroundColor Yellow

                    Stop-VM -VM $WIN10.name -Kill -Confirm:$false

                    if($SnapshotDesc){

                        Write-Host "Creating snapshot $SnapshotDesc for $($WIN10.name)...." -ForegroundColor Green

                        New-Snapshot -VM $WIN10.name -Name $SnapshotName -Description $SnapshotDesc -Confirm:$false

                        }

                    else{

                        Write-Host "Creating snapshot for $($WIN10.name)...." -ForegroundColor Green

                        New-Snapshot -VM $WIN10.name -Name $SnapshotName -Description "Created by $($VCUser) on $(Get-Date)" -Confirm:$false

                        }
                    
                    }        
        
                }

            elseif($VMType -eq 'CUCM'){
        
                foreach($CUCM in $CUCMs){

                    Write-Host "Stopping $($CUCM.name)...." -ForegroundColor Yellow
    
                    Stop-VM -VM $CUCM.name -Kill -Confirm:$false

                    if($SnapshotDesc){

                        Write-Host "Creating snapshot $SnapshotDesc for $($CUCM.name)...." -ForegroundColor Green

                        New-Snapshot -VM $CUCM.name -Name $SnapshotName -Description $SnapshotDesc -Confirm:$false

                        }
                        
                    else{

                        Write-Host "Creating snapshot for $($CUCM.name)...." -ForegroundColor Green

                        New-Snapshot -VM $CUCM.name -Name $SnapshotName -Description "Created by $($VCUser) on $(Get-Date)" -Confirm:$false

                        }
                       
                    }        
            
                }

            elseif($VMType -eq 'HOST'){
        
                foreach($ESXIVM in $ESXIVMs){

                    Write-Host "Stopping $($ESXIVM.name)...." -ForegroundColor Yellow
        
                    Stop-VM -VM $ESXIVM.name -Kill -Confirm:$false
    
                    if($SnapshotDesc){

                        Write-Host "Creating snapshot $SnapshotDesc for $($ESXIVM.name)...." -ForegroundColor Green
    
                        New-Snapshot -VM $ESXIVM.name -Name $SnapshotName -Description $SnapshotDesc -Confirm:$false
    
                        }
                            
                    else{

                        Write-Host "Creating snapshot for $($ESXIVM.name)...." -ForegroundColor Green
    
                        New-Snapshot -VM $ESXIVM.name -Name $SnapshotName -Description "Created by $($VCUser) on $(Get-Date)" -Confirm:$false
    
                        }
                           
                    }        
                
                }

            }

        }

}