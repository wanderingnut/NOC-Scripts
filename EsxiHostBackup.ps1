#*****************************
#Original Author : Logan Harris
#Date: 11/8/2018
#Title: Esxi_Host_Backup.ps1
#Summary: A script designed to pull a backup of a host
#*****************************

#Clear the Shell
Clear-Host

#Lets create an Array for Getting Names of Hosts for backups
$Hostarray = @()
do {
 $i = (Read-Host "Please enter the Name of the Host to Backup, or 'all' for all of them (leave blank to end the list)")
 if ($i -ne '') {$Hostarray += $i}
}
until ($i -eq '')

#Now to establish Variables
$ComCode = Read-Host "What is the company code?"
$Date = Get-Date -Format FileDate

#Create a folder named by Company Code and Date for the Backup (and dont throw an error if it exists)
if(!(Test-Path $home\desktop\HostBackups\$ComCode\$Date\$ComCode\$Date -PathType Container)) { 
    New-Item -Path $home\desktop\HostBackups\$ComCode\$Date -ItemType Directory -Force | Out-Null
} 

#New-Item -Path C:\HostBackups\$ComCode\$Date -ItemType Directory -Force | Out-Null

#Lets try to log in using Kaylee Nevin's Method
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

 #Pull backups of Each host from the Array or All
 Foreach ($i in $HostArray){
	If ($i -eq "all") { 
		Get-VMHost | Get-VMHostFirmware -BackupConfiguration -DestinationPath $home\desktop\HostBackups\$ComCode\$Date
	} Else { 
		Get-VMHost -Name *$i* | Get-VMHostFirmware -BackupConfiguration -DestinationPath $home\desktop\HostBackups\$ComCode\$Date
	}
	}