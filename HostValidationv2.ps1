
#*****************************
#Author : Kaylee Nevin
#Date: 12/17/17
#Title: Validation Script Version 2.0
#Summary: A script designed to pull all necessary information from vmware environment hosts to verify that they have been configured correctly. 
#*****************************

do {
	try {	#Grab vCenter to connect to from user
			$connectToVCenter = Read-Host 'Enter vCenter'
			$userName = Read-Host 'Enter User'
			$securePassWord = Read-Host 'Enter Password' -AsSecureString
			$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassWord)
			$plainPassWord = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
				
			Connect-VIServer $connectToVCenter -User $userName -Password $plainPassWord -ErrorAction Stop
			$checkConnect = $global:DefaultVIServers[0].name
	} 
	catch { #In the event of failure
			Write-Host "`n"
			Write-Host "Check input and try again." | Out-Null
			Write-Host "`n"
	}				
} until ($checkConnect -eq $connectToVCenter)

#Grab Host Name
Write-Host "`n"
Write-Host "`n"
#Store hosts in an array
$hostArray = ""
#Need a counter for array control 
$hostCount = 0
do {
	try { 	#test for host existence
			$hostName = Read-Host 'Please enter hostname'
			Get-VMHost -Name $hostName -ErrorAction Stop | Out-Null
			$hostCount += 1
			if ($hostCount -gt 1) {
				#add yer host names to the array
				$hostArray = $hostArray + " " + $hostName
			} else { 
				#For those, THERE CAN ONLY BE ONE!!, moments. 
				$hostArray = $hostName
			}
	}
	catch { #Error Message
			Write-Host 'That host does not exist. Check input.'
			$hostname = " "
	}
	$answer = Read-Host 'Would you like to enter another host? (Y/N)'
} until ($answer -eq 'N') 	

#Set Host Variable values by host input
Write-Host "********************Host Validations********************"
#In order for each hostname to be treated as a separate array object, gotta split them up. Inserting a comma as part of the string will not do. 
#The StringSplitOptions--RemoveEmptyEntries removes any additional spaces that may be hanging out in there. 
$hostArray = $hostArray.Split(" ",[StringSplitOptions]'RemoveEmptyEntries')
#remove duplicates
$hostArray = $hostArray | Select -unique
Write-Host "`n"
#Grab Host hardware specs
Write-Host "********************Host Type, RAM********************"
foreach ($device in $hostArray) { 
	Get-VMHost -Name $device | Select Name, Manufacturer, Model, MemoryTotalGB, MemoryUsageGB | ft
}
#Grab Host datastore specs
Write-Host "********************Datastores********************"
foreach ($device in $hostArray) {
	Write-Host $device
	Get-VMHost -Name $device | Get-Datastore | Select Name, FreeSpaceGB, CapacityGB | ft
}
#Grab Host physical connected ports
Write-Host "********************Physical/LAG********************"
foreach ($device in $hostArray) { 
	Write-Host $device
	Get-VDSwitch -VMHost $device | Get-VDPort -ConnectedOnly | where {$_.ProxyHost -like $device -and ($_.Name -match "lag*")} | Select Name, ConnectedEntity, Portgroup, IsLinkUp | ft
}
#Grab Host software specs
Write-Host "********************Host Build********************"
foreach ($device in $hostArray) { 
	Get-VMHost -Name $device | Select Name, Version, Build | ft
}
#Grab vaai plugin
Write-Host "********************NetAppNas Plugin VIB********************"
foreach ($device in $hostArray){
	$esxcli = Get-Esxcli -VMHost $device -V2
	$esxcli.software.vib.list.Invoke() | Where-Object {$_.Name -eq "NetAppNasPlugin"} | Select -property @{N='VMHost';E={$esxcli.VMHost.Name}},
		@{N='Accepted';E={$_.AcceptanceLevel}},
		@{N='VibName';E={$_.Name}},
		@{N='Vendor' ;E={$_.Vendor}},
		@{N='InstallDate' ;E={$_.InstallDate}},
		@{N='Version';E={$_.Version}} | ft 
}
#Grab Host license                            
Write-Host "********************Host Licensing********************"
foreach ($device in $hostArray) { 
	Get-VMHost -Name $device | Select Name, LicenseKey | ft
}
#Grab Host NTP server
Write-Host "********************NTP Server********************"
Write-Host "`n"
foreach ($device in $hostArray) { 
	Write-Host $device
	Get-VMHost -Name $device | Get-VMHostNtpServer | ft
}
Write-Host "`n"
#Grab Host system time
Write-Host "********************Current System Time********************"
Write-Host "`n"
foreach ($device in $hostArray ){
	Write-Host $device "Current Time:"
	Write-Host "`n"
	$esxcli = Get-Esxcli -VMHost $device -V2
	$esxcli.system.time.get.Invoke() | ft 
	Get-VMHost -Name $device | Select Timezone | ft
}
#Grab Host vmkernel specs
Write-Host "********************VMKernels********************"
foreach ($device in $hostArray ){
	Get-VMHost -Name $device | Get-VMHostNetworkAdapter -VMKernel | Select VMHost, Name, VMotionEnabled, ManagementTrafficEnabled | ft
}
#Grab cluster drs/ha
Write-Host "********************DRS/HA********************"
foreach ($device in $hostArray ){
	Get-Cluster -VMHost $device | Select Name, DrsEnabled, HAEnabled | ft
}
#Grab Host Advanced Settings
Write-Host "********************Advanced Settings********************"
foreach ($device in $hostArray ){
	Get-VMHost -Name $device | Get-AdvancedSetting -Name Disk.QFullSampleSize, NFS.HeartbeatFrequency, NFS.HeartbeatMaxFailures, NFS.MaxVolumes, NFS.MaxQueueDepth, Net.TcpipHeapSize, Net.TcpipHeapMax | Select Entity, Name, Value | ft
}
#Grab Host Scratch Config location
Write-Host "********************Advanced Settings : ScratchConfig********************"
foreach ($device in $hostArray ){
	Get-VMHost -Name $device | Get-AdvancedSetting -Name ScratchConfig.CurrentScratchLocation | Select Entity, Name, Value | ft
}
#Grab Host VLANS/PortGroups and their Teaming and Failover Policies
Write-Host "********************Host VLANS and Portgroups********************"
Write-Host "********************Teaming and Failover Policies********************"
Write-Host "********************LoadBalanceIP = Route Based on IP Hash ********************"
foreach ($device in $hostArray ){
	Write-Host $device
	$vdSwitchValid = Get-VDSwitch -VMHost $hostValid
	$portGroupList = Get-VDPortGroup -VDSwitch $vdSwitchValid
	$portGroupList | Get-VDUplinkTeamingPolicy | Select VDPortgroup, LoadBalancingPolicy, FailoverDetectionPolicy, ActiveUplinkPort | ft
}
#Grab Host Power Management Policy
Write-Host "********************Power Management Policy********************"
Write-Host "********************Static = High Performance********************"
foreach ($device in $hostArray ){
	Get-AdvancedSetting -Entity $device -Name Power.cpupolicy | Select Entity, Name, Value | ft
}
#Grab Host EVC Mode
Write-Host "********************Host EVC Mode********************"
foreach ($device in $hostArray ){
	Get-VMHost -Name $device | Select Name, MaxEVCMode | ft
}
#Grab Cluster EVC Mode
Write-Host "********************Cluster EVC********************"
foreach ($device in $hostArray ){
	Write-Host $device "Cluster:"
	Get-Cluster -VMHost $device | Select Name, EVCMode | ft
}
#Grab Host Routes
Write-Host "********************Host Routes********************"
foreach ($device in $hostArray ){
	Write-Host $device
	Get-VMHostRoute -VMHost $device | Select VMHost, Destination, Gateway | ft
}
#Grab Host VMKernel MTUS
Write-Host "********************VM Kernel MTUS********************"
foreach ($device in $hostArray ){
	Get-VMHost -Name $device | Get-VMHostNetworkAdapter -VMKernel | Select VMHost, Name, IP, Mtu | ft
}

Disconnect-VIServer $connectToVCenter


