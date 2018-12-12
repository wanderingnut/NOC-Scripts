#*****************************
#Original Author : Logan Harris
#Date: 12/2/2018
#Title: vCenterPatchAudit.PS1
#Summary: A script designed to pull patch numbers for the vCenters to help with compliance
#*****************************

#Clear the Shell
Clear-Host


#Now to establish Variables
$ComCode = Read-Host "What is the company code?"
$Date = Get-Date -Format FileDate

#Create a folder named by Company Code and Date for the Backup (and dont throw an error if it exists)
if(!(Test-Path $home\desktop\Audits\$ComCode\$Date\$ComCode\$Date -PathType Container)) { 
    New-Item -Path $home\desktop\Audits\$ComCode\$Date -ItemType Directory -Force | Out-Null
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


#Make sure the array is empty
$hostarray = @()

#Get all hosts in an environment, in proper order
$hostarray = (Get-VMHost | Sort-Object Name)

#List the name, pull all patches and shniz
foreach ($i in $hostarray) {
	echo $i | Out-File -Append -NoClobber -FilePath $home\desktop\Audits\$ComCode\$Date\Audit.txt
	$escxli = Get-EsxCli -VMHost $i -V2 
	$escxli.software.vib.list.invoke() | Out-File -Append -NoClobber -FilePath $home\desktop\Audits\$ComCode\$Date\Audit.txt
	echo "----------------------" | Out-File -Append -NoClobber -FilePath $home\desktop\Audits\$ComCode\$Date\Audit.txt
}

<#  #Pull backups of Each host from the Array or All
 Foreach ($i in $HostArray){
	If ($i -eq "all") { 
		(Get-EsxCli -vmhost esx*).software.vib.list() | Out-File -Append -NoClobber -FilePath $home\desktop\Audits\$ComCode\$Date\Audit.txt
	} Else {
		echo $i 
		(Get-EsxCli -vmhost *$i*).software.vib.list() | Out-File -Append -NoClobber -FilePath $home\desktop\Audits\$ComCode\$Date\Audit.txt
	}
	} #>