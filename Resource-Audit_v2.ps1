#*****************************
#Original Author : Logan Harris
#Date: 09/12/18
#Title: Resource Audit Script V 2.0
#Summary: A script designed to pull all necessary information from vmware environment hosts as part of our Audit Process 
#*****************************

#Clear the Shell
Clear-Host

#Currently This only Pulls IP Addresses, Mem Stats, and CPU stats. Still need to probe OCUM for IOPS

#Commented becuase They need better graphs that have the inventory included
<# echo "First It will prompt for the intervals in Days for the graphs, then for the company Code, Then the vCenter Info"

#Lets create an Array for Getting ay intervals for Graphs
$Dayarray = @()
do {
 $i = (Read-Host "Please enter the graph interval in Days, one interval at a time (leave blank to end the list)")
 if ($i -ne '') {$Dayarray += $i}
}
until ($i -eq '') #>

#Now to prompt for Company Code and create a folder on the Desktop
$ComCode = Read-Host "What is the company code?"

New-Item -Path $home\Desktop\$ComCode -ItemType directory | Out-Null
#New-Item -Path $home\Desktop\$ComCode\ScreenShots -ItemType directory | Out-Null
$RAName = $ComCode + "ResourceAudit.csv"

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

echo "-------------------------------------------------------------------------------------------"
echo "These Numbers May be off by a few MB in vCenter due to translation between ESXi and vCenter"



#Consolidated as much as I could so now it should look a lot cleaner, Still cant get it to behave with Datastores
$Stats = @(Get-VMHost | Where {$_.PowerState -eq "PoweredOn"} | Select-Object Name,
 @{N="Management IP";E={(Get-VMHostNetworkAdapter -VMHost $_.Name | Where-Object {$_.Name -eq "vmk0"}).IP}},
 @{N="Memory (MB)";E={"" + [math]::round((Get-View $_).Hardware.MemorySize / 1MB, 0)}},
 #@{N="VMs";E={(Get-View $_).Vm.Count}},
 #@{N="Type";E={(Get-View $_).Hardware.SystemInfo.Model}},
 @{N="Mem.Usage";E={[Math]::Round((($_ | Get-Stat -Stat mem.consumed.average -Realtime -MaxSamples 20 | Measure-Object Value -Average).Average) /1024 , 2)}},
 @{N="Memory Usage %" ; E={[Math]::Round((($_ | Get-Stat -Stat mem.usage.average -Realtime -MaxSamples 20 | Measure-Object Value -Average).Average),2)}},
 @{N="CPU Max (MHZ)" ; E={[Math]::Round((($_ | Get-Stat -Stat CPU.totalcapacity.average -Realtime -MaxSamples 20 | Measure-Object Value -Average).Average),2)}},
 @{N="Cpu UsageMhz Average";E={[Math]::Round((($_ | Get-Stat -Stat cpu.usagemhz.average -Realtime -MaxSamples 20 | Measure-Object Value -Average).Average),2)}},
 @{N="CPU Usage (MHZ), %" ; E={[Math]::Round((($_ | Get-Stat -Stat CPU.usage.average -Realtime -MaxSamples 20 | Measure-Object Value -Average).Average),2)}} |
Sort-Object Name
Echo "`n"
)

#Now its time to find DataStore Freespace and Used Space
#Due to how Export-CSV works, this is going to misbehave. I set it to export to its own CSV for clarity too
echo "Gathering Datastore Info"
$Datastore = @(Get-VMHost | Where {$_.PowerState -eq "PoweredOn"} | Get-Datastore |Select Name,FreeSpaceGB,CapacityGB | Sort-Object Name )
echo "`n"

$Disc = "These Numbers May be off by a few MB in vCenter due to translation between ESXi and vCenter"

$DatastoreLabel = "---------------Datastores---------------"

#Export the Arrays of the Above to a CSV in the Folder of Customer Code On the Desktop

$Disc | Out-File -Append -NoClobber -FilePath $home\Desktop\$ComCode\$ComCode.csv
$Stats | Export-CSV -NoTypeInformation -Path $home\Desktop\$ComCode\$ComCode.csv
#$DataStore |  Out-File -Append -NoClobber -FilePath $home\Desktop\$ComCode\$ComCode.csv
$DataStore |  Export-CSV -NoTypeInformation -Path $home\Desktop\$ComCode\$ComCode-Datastore.csv

#Exporting the Same Data as above into a .txt in the same location incase the CSV is derpy
$Disc | Out-File -Append -NoClobber -FilePath $home\Desktop\$ComCode\$ComCode.txt
$HostLabel | Out-File -Append -NoClobber -FilePath $home\Desktop\$ComCode\$ComCode.txt
$Stats | Out-File -Append -NoClobber -FilePath $home\Desktop\$ComCode\$ComCode.txt
$DatastoreLabel | Out-File -Append -NoClobber -FilePath $home\Desktop\$ComCode\$ComCode.txt
$DataStore | Out-File -Append -NoClobber -FilePath $home\Desktop\$ComCode\$ComCode.txt
 
<# echo "`n"
echo "Generating Graphs. Ignore the Red. Will be saved to your Desktop"
#echo "Graphs of CPU Usage and Mhz over 30 Days"
echo "`n"

#Import the new modules for graphing

	[Void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [Void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

 Import-Module VMware.VimAutomation.Core

 #Based on the number first prompted for, make graphs of CPU usage %, CPU Usage MHz, and Memory usage % #>
<# foreach ($i in $Dayarray) {
	$MaxSamples = 1000 # The maximum number of samples to extract, more samples makes for a more detailed graph, but takes more time.
	$TimeSpan = $i # in days, so this graph goes back 30 days. You could change AddDays on lines 26 and 27 to AddMonths or AddYears
	$VirtualMachines = Get-VMHost
 
	#Graph the CPU Averages
	ForEach ($vm in $VirtualMachines) {
		$vmStat= "" | select VMName, CPUMax, CPUAvg, CPUMin
		$vmStat.VMName=$vm.Name
		$StatCPU = Get-Stat -Entity ($vm) -Start (Get-Date).AddDays(-$TimeSpan) -Finish (Get-Date) -MaxSamples $MaxSamples -Stat cpu.usage.average
		$cpu = $StatCPU | Measure-Object -Property value -Average -Maximum -Minimum 
		$vmStat.CPUMax = $cpu.Maximum
		$vmStat.CPUAvg = $cpu.Average
		$vmStat.CPUMin = $cpu.Minimum
     
		$Chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
		$ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
		$ChartArea.Name = "ChartArea1"
		$ChartArea.AxisX.Title = "Date"
		$ChartArea.AxisX.LabelStyle.Angle = 30
		$ChartArea.AxisY.Title = "PErcent Utilization"
		#This one causes errors and it still works without it so its commented out
		#$ChartArea.AxisX.LabelStyle.Format.ToDateTime([datetime])
		$Chart.ChartAreas.Add($ChartArea)
		$Chart.Width = 1500
		$Chart.Height = 600
		$Chart.Left = 40
		$Chart.Top = 30
		$Chart.Name = $vm
     
		$Legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend
		$Legend.Name = "Legend1"
     
		$Chart.Legends.Add($Legend)
		$Chart.Series.Add("CPUAvg")
		$Chart.Series["CPUAvg"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
		$Chart.Series["CPUAvg"].IsVisibleInLegend = $true
		$Chart.Series["CPUAvg"].ChartArea = "ChartArea1"
		$Chart.Series["CPUAvg"].Legend = "Legend1"
		$Chart.Series["CPUAvg"].Color = "#FF0000"
		$Chart.Series["CPUAvg"].xValueType = [System.Windows.Forms.DataVisualization.Charting.ChartValueType]::DateTime
    
     
		$CpuPoints = $StatCPU
 
		Foreach ($CpuPoint in $CpuPoints) {
			$DataPoint = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint($CpuPoint.Timestamp.ToOADate(),$CpuPoint.Value)
			$Chart.Series["CPUAvg"].Points.Add($DataPoint)
		}
		$BeginDate=((Get-Date).AddDays(-$TimeSpan))
		$StartYear = $BeginDate.Year.ToString()
		$StartMonth = $BeginDate.Month.ToString()
		$StartDay = $BeginDate.Day.ToString()
 
		If ($StartDay -lt 2) {
			[String]$StartDay = "0" + $StartDay
		}
		[String]$StartDate = $StartYear + $StartMonth + $StartDay
		[String]$EndDate = (Get-Date -Format yyyyMMdd)
     
		#This part saves the graphs a PNG files
		[String]$DirectoryName = $home + "\Desktop\" + $ComCode
		[String]$FileName = $DirectoryName + "\graphs\" + $vm + "_CpuAvg_" + $ComCode +"_" + $i+ "Days" + ".png"
		$Chart.SaveImage($FileName,"PNG")
		} 
	 
	
	# Graph the Mhz 
	ForEach ($vm in $VirtualMachines) {
		$vmStat= "" | select VMName, CPUMax, CPUAvg, CPUMin
		$vmStat.VMName=$vm.Name
		$StatMhz = Get-Stat -Entity ($vm) -Start (Get-Date).AddDays(-$TimeSpan) -Finish (Get-Date) -MaxSamples $MaxSamples -Stat cpu.usagemhz.average
		$mhz = $StatMhz | Measure-Object -Property value -Average -Maximum -Minimum
		$vmStat.CPUMax = $mhz.Maximum
		$vmStat.CpuAvg = $mhz.Average
		$vmStat.CPUMin = $mhz.Minimum
		$Chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
		$ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
		$ChartArea.Name = "ChartArea1"
		$ChartArea.AxisX.Title = "Date"
		$ChartArea.AxisX.LabelStyle.Angle = 30
		$ChartArea.AxisY.Title = "Average MHz Used"
		#This one causes errors and it still works without it so its commented out
		#$ChartArea.AxisX.LabelStyle.Format.ToDateTime([datetime])
		$Chart.ChartAreas.Add($ChartArea)
		$Chart.Width = 1500
		$Chart.Height = 600
		$Chart.Left = 40
		$Chart.Top = 30
		$Chart.Name = $vm
		$Legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend
		$Legend.Name = "Legend1"
		$Chart.Legends.Add($Legend)
		$Chart.Series.Add("mhzAvg")
		$Chart.Series["mhzAvg"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
		$Chart.Series["mhzAvg"].IsVisibleInLegend = $true
		$Chart.Series["mhzAvg"].ChartArea = "ChartArea1"
		$Chart.Series["mhzAvg"].Legend = "Legend1"
		$Chart.Series["mhzAvg"].Color = "#0000FF"
		$Chart.Series["mhzAvg"].xValueType = [System.Windows.Forms.DataVisualization.Charting.ChartValueType]::DateTime
     
		$mhzPoints = $Statmhz
 
    
		Foreach ($mhzPoint in $mhzPoints) {
			$DataPoint = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint($mhzPoint.Timestamp.ToOADate(),$mhzPoint.Value)
			$Chart.Series["mhzAvg"].Points.Add($DataPoint)
		}
		$BeginDate=((Get-Date).AddDays(-$TimeSpan))
		$StartYear = $BeginDate.Year.ToString()
		$StartMonth = $BeginDate.Month.ToString()
		$StartDay = $BeginDate.Day.ToString()
 
		If ($StartDay -lt 2) {
			[String]$StartDay = "0" + $StartDay
		}
		[String]$StartDate = $StartYear + $StartMonth + $StartDay
		[String]$EndDate = (Get-Date -Format yyyyMMdd)
     
		#This part saves the graphs a PNG files
		[String]$DirectoryName = $home + "\Desktop\" + $ComCode
		[String]$FileName = $DirectoryName + "\graphs\" + $vm + "_CpuAvgMhz_" + $ComCode +"_" + $i+ "Days" + ".png"
		$Chart.SaveImage($FileName,"PNG")
	
 
		#This part shows the graph in a new window.
		#$Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Left
		#$Form = New-Object Windows.Forms.Form
		#$Form.Text = "$vm - CPU & Memory Usage"
		#$Form.Width = 1600
		#$Form.Height = 700
		#$Form.Controls.Add($Chart)
		#$Form.Add_Shown({$Form.Activate()})
		#$Form.ShowDialog()
	} 
	
	
		# Graph the Memory
	ForEach ($vm in $VirtualMachines) {
		$vmStat= "" | select VMName, MemMax, MemAvg, MemMin
		$vmStat.VMName=$vm.Name
		$StatMem = Get-Stat -Entity ($vm) -Start (Get-Date).AddDays(-$TimeSpan) -Finish (Get-Date) -MaxSamples $MaxSamples -Stat mem.usage.average
		$Mem = $StatMem | Measure-Object -Property value -Average -Maximum -Minimum
		$vmStat.MemMax = $Mem.Maximum
		$vmStat.MemAvg = $Mem.Average
		$vmStat.MemMin = $Mem.Minimum
		$Chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
		$ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
		$ChartArea.Name = "ChartArea1"
		$ChartArea.AxisX.Title = "Date"
		$ChartArea.AxisX.LabelStyle.Angle = 30
		$ChartArea.AxisY.Title = "Percent Utilization"
		#This one causes errors and it still works without it so its commented out
		#$ChartArea.AxisX.LabelStyle.Format.ToDateTime([datetime])
		$Chart.ChartAreas.Add($ChartArea)
		$Chart.Width = 1500
		$Chart.Height = 600
		$Chart.Left = 40
		$Chart.Top = 30
		$Chart.Name = $vm
		$Legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend
		$Legend.Name = "Legend1"
		$Chart.Legends.Add($Legend)
		$Chart.Series.Add("MemAvg")
		$Chart.Series["MemAvg"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
		$Chart.Series["MemAvg"].IsVisibleInLegend = $true
		$Chart.Series["MemAvg"].ChartArea = "ChartArea1"
		$Chart.Series["MemAvg"].Legend = "Legend1"
		$Chart.Series["MemAvg"].Color = "#0000FF"
		$Chart.Series["MemAvg"].xValueType = [System.Windows.Forms.DataVisualization.Charting.ChartValueType]::DateTime
     
		$MemPoints = $StatMem
 
    
		Foreach ($MemPoint in $MemPoints) {
			$DataPoint = New-Object System.Windows.Forms.DataVisualization.Charting.DataPoint($MemPoint.Timestamp.ToOADate(),$MemPoint.Value)
			$Chart.Series["MemAvg"].Points.Add($DataPoint)
		}
		$BeginDate=((Get-Date).AddDays(-$TimeSpan))
		$StartYear = $BeginDate.Year.ToString()
		$StartMonth = $BeginDate.Month.ToString()
		$StartDay = $BeginDate.Day.ToString()
 
		If ($StartDay -lt 2) {
			[String]$StartDay = "0" + $StartDay
		}
		[String]$StartDate = $StartYear + $StartMonth + $StartDay
		[String]$EndDate = (Get-Date -Format yyyyMMdd)
     
		#This part saves the graphs a PNG files
		[String]$DirectoryName = $home + "\Desktop\" + $ComCode
		[String]$FileName = $DirectoryName + "\graphs\" + $vm + "_Memory_" + $ComCode +"_" + $i+ "Days" + ".png"
		$Chart.SaveImage($FileName,"PNG")
	
 
		#This part shows the graph in a new window.
		#$Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Left
		#$Form = New-Object Windows.Forms.Form
		#$Form.Text = "$vm - CPU & Memory Usage"
		#$Form.Width = 1600
		#$Form.Height = 700
		#$Form.Controls.Add($Chart)
		#$Form.Add_Shown({$Form.Activate()})
		#$Form.ShowDialog()
	} 
} #>

#Now it pulls the data from the vCenter, Next to see what I can do about probing Netapp for IOPS
