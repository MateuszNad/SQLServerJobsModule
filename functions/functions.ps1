function Get-SQLServerJobs
{
<#
.Synopsis
   The script allows you to return object with Jobs with MSSQL Server.
.DESCRIPTION
    The script allows you to generate a job report from several servers. Allows you to specify a time window for the report. Allows you get details about connections in packages IS.
.EXAMPLE
    Allows get all Jobs on two server.

    PS C:\>Get-SQLServerJobs -InstanceServer serwer-sql

    JobName                   : ARIS_BOR_PPM
    JobStep                   : ARIS_BOR_PPM
    Type                      : SSIS
    Description               : No description available.
    Command                   : /ISSERVER "\"\SSISDB\ETL\ETL\ETLM.dtsx\"" /SERVER "\".\"" /X86 /Par "\"$ServerO
                               ption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALL
                               ERINFO SQLAGENT /REPORTING E
    NextRun                   : 27.05.2017 00:05:00
    VersionSSIS               : 40
    LocationSSIS              : ISSERVER
    NameSSIS                  : ETL
    Connection                : {e8, serwer-sql}
    AvgDurationMin            : 71
    SchedulerName             : Daily at 05:00 without weekend
    SchedulerType             : Weekly
    SchedulerInterval         : {Tuesday, Wednesday, Thursday, Friday...}
    SchedulerRelativeInterval :
    Server                    : serwer-sql
.EXAMPLE
    Allows get all Jobs on two servers.

    PS C:\> "serwer-sql","serwer-rs" | Get-SQLServerJobs | Select JobName,NextRun
    
    JobName                                       NextRun
    -------                                       -------
    KLM_BKR_PPM                                   27.05.2017 00:05:00
    AABB ETL                                      27.05.2017 00:02:00
    1D5CBEA7-4655-4160-94D5-52D3C3EE99E5          02.06.2017 10:58:00
.LINK
   Author: Mateusz Nadobnik 
   Link: 
   Date: 
   Version: 1.0.0.0
    
   Keywords: Raport, Job, Jobs, SSIS, Scheduler
   Notes: 06.04.2017 - first version
#> 
    [CmdletBinding()]
    Param
    (
        #A character string or SMO server object specifying the name of an instance of the Database Engine. For default instances, only specify the computer name: "MyComputer". For named instances, use the format "ComputerName\InstanceName".
        [Parameter(Mandatory=$true,ValueFromPipeline = $true, Position=0)]
        $InstanceServer
    )

    Begin
    {
        $ErrorActionPreference = "Stop"
        
        #Start variables
        $GetJobsSQL = @()
        [regex]$LocationSSIS = '^(\/)(.*?)(\s)'
        $provider =  New-Object cultureinfo ('en-GB')
            
        #Query - Getting all information about jobs on SQL Server
        $AllJobsQuery = "WITH jobduratiON AS
                        ( 
                            SELECT max(jb.instance_id) as instance_id, job_id, max(jb.run_duratiON) as run_duratiON FROM (
                            SELECT max(cast(job_id as varchar(max))) as job_id, instance_id, avg(sjh.run_duratiON) as run_duratiON
                            FROM msdb.dbo.sysjobhistory sjh
                            GROUP BY sjh.instance_id) as jb
                            GROUP BY jb.job_id
                        )
                        SELECT 
	                        j.name AS 'JobName', 
	                        jst.step_name AS 'JobStep', 
	                        j.descriptiON AS 'DescriptiON', 
	                        jst.command AS 'Command', 
	                        jst.subsystem AS 'Type',  
	                        sch.name 'SchedulerName',
	                            ((jd.run_duratiON / 10000 * 3600) + ((jd.run_duratiON % 10000) / 100 * 60) + (jd.run_duratiON % 10000) % 100)/60 AS AvgDuratiONMin,
	                        CASE WHEN sch.enabled = 0 THEN 'Disable' 
	                        WHEN jsch.next_run_date = 0 THEN
		                        SUBSTRING(CONVERT(CHAR(8),sch.active_start_date),7,2) + '-'+ 
		                        SUBSTRING(CONVERT(CHAR(8),sch.active_start_date),5,2) + '-' + 
		                        SUBSTRING(CONVERT(CHAR(8),sch.active_start_date),1,4)+ ' ' + 
		                        SUBSTRING(RIGHT('000000' + CONVERT(VARCHAR(6),sch.active_start_time),6),1,2) + ':'+
		                        SUBSTRING(RIGHT('000000' + CONVERT(VARCHAR(6),sch.active_start_time),6),3,2) + ':' +
		                        SUBSTRING(RIGHT('000000' + CONVERT(VARCHAR(6),sch.active_start_time),6),5,2)
	                        ELSE
		                        SUBSTRING(CONVERT(CHAR(8),jsch.next_run_date),7,2) + '-'+ 
		                        SUBSTRING(CONVERT(CHAR(8),jsch.next_run_date),5,2) + '-' + 
		                        SUBSTRING(CONVERT(CHAR(8),jsch.next_run_date),1,4)+ ' ' + 
		                        SUBSTRING(RIGHT('000000' + CONVERT(VARCHAR(6),jsch.next_run_time),6),1,2) + ':'+
		                        SUBSTRING(RIGHT('000000' + CONVERT(VARCHAR(6),jsch.next_run_time),6),3,2) + ':' +
		                        SUBSTRING(RIGHT('000000' + CONVERT(VARCHAR(6),jsch.next_run_time),6),5,2)
	                        END AS NextRun,
	                        sch.freq_type, 
	                        sch.freq_interval, 
	                        sch.freq_subday_type, 
	                        sch.freq_subday_interval, 
	                        sch.freq_relative_interval, 
	                        sch.freq_recurrence_factor,
	                        @@SERVERNAME AS Server
                        FROM msdb.dbo.sysjobschedules jsch
                        JOIN msdb.dbo.sysjobsteps jst
                        ON jsch.job_id = jst.job_id
                        JOIN msdb.dbo.sysjobs j 
                        ON jsch.job_id = j.job_id
                        JOIN msdb.dbo.sysschedules sch
                        ON jsch.schedule_id = sch.schedule_id
                        JOIN jobduratiON jd
                        ON j.job_id = jd.job_id"

            #Query - Getting information about SSIS while exists on SQL Server
            $SSISJobsQuery = "WITH SSIS AS 
                            (
	                            SELECT 
                                    DENSE_RANK() OVER(PARTITION BY project_id ORDER BY project_id, project_version_lsn DESC) AS rnk, * 
	                            FROM [SSISDB].internal.object_parameters
                            )
                            SELECT 
	                            p.Name AS NameSSIS,
	                            --deployed_by_name,
	                                --last_deployed_time, 
	                                object_version_lsn AS VersionSSIS,
	                                --object_name AS ParameterName, 
	                                parameter_name AS ParameterName,
	                                design_default_value AS ParameterValue
                            FROM [SSISDB].[internal].[projects] P
                            JOIN SSIS
                            ON P.project_id = SSIS.project_id
                            WHERE SSIS.rnk = 1 and SSIS.parameter_name like '%ServerName'"
    }
    Process
    {
        try 
        {
            #Invoke query $AllJobsQuery
            $AllJobs = Invoke-Sqlcmd -ServerInstance $InstanceServer -Database msdb -Query $AllJobsQuery
        } 
        catch
        {
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }

        #Checking if there are any SSIS package
        if(($AllJobs | Where Type -eq 'SSIS'))
        {
            #Checking if there are any SSIS package type ISSERVER
            $processingAllJobs = $AllJobs | Select JobName, JobStep, Type, Description, Command, AvgDurationMin, SchedulerName, freq_type, freq_interval, `
                                                        freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, `
                                                        @{L='LocationSSIS';E={($LocationSSIS.Match($_.Command).Captures[0].Value)}}, `
                                                        @{L='PathSSIS';E={[array]($_.Command -split '"')[2]}}, NextRun, Server
        
            #Checking if there are any SSIS package type ISSERVER
            if($processingAllJobs.LocationSSIS  -match 'ISSERVER ') 
            {
                try
                {
                    $SSISJobs = Invoke-Sqlcmd -ServerInstance ($AllJobs | select Server -Unique).Server -Database msdb -Query $SSISJobsQuery
                }
                catch  [System.Exception]
                {
                    Write-Host $_.Exception.Message -ForegroundColor Yellow
                }
            }

            #Invoke-Sqlcmd has changed location therefore we must back to systemdrive location.
            try 
            {
                Set-Location $env:systemdrive
            }
            catch
            {
                Write-Host $_.Exception.Message -ForegroundColor Yellow
            }

            Foreach($job in $processingAllJobs)
            {
          
                $Obj = $job | Select JobName, JobStep, LocationSSIS, Type, NextRun, Description, `
                                    Command, AvgDurationMin, SchedulerName, freq_type, freq_interval, `
                                    freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, 
                                    @{L='NameSSIS';E={Split-Path (Split-Path $_.PathSSIS) -Leaf}}, 
                                    @{L='VersionSSIS';E={ $SSISJobs | foreach{ if($_.NameSSIS -match (Split-Path (Split-Path $job.PathSSIS) -Leaf)) {$_ | Select VersionSSIS}}}}, 
                                    @{L='Connection';E={ $SSISJobs | foreach{ if($_.NameSSIS -match (Split-Path (Split-Path $job.PathSSIS) -Leaf)) {$_ | Select ParameterValue}}}}, Server
        
                $Objects = @{} | Select JobName, JobStep, Type, Description, Command, NextRun, VersionSSIS, LocationSSIS, NameSSIS, `
                                        Connection, AvgDurationMin, SchedulerName, SchedulerType, SchedulerInterval,SchedulerRelativeInterval, Server

                $Objects.JobName = $Obj.JobName
                $Objects.JobStep = $Obj.JobStep
                $Objects.Type = $Obj.Type
                $Objects.NameSSIS = [string]($obj.NameSSIS -replace[Environment]::NewLine,"")
                $Objects.NextRun =  if($obj.NextRun -eq 'Disable'){$obj.NextRun}else{[datetime]::ParseExact($obj.NextRun,"dd-MM-yyyy HH:mm:ss",$provider)}
                $Objects.Command = [string]($obj.Command -replace[Environment]::NewLine,"")
                $Objects.Description = $obj.Description
                #$Objects.Priority = 
                $Objects.LocationSSIS = if($obj.LocationSSIS){($obj.LocationSSIS).Replace('/','')}

                $Objects.AvgDurationMin = $obj.AvgDurationMin
                $Objects.VersionSSIS = ($Obj.VersionSSIS).VersionSSIS | Select -Unique
                $Objects.Connection = (($Obj.Connection).ParameterValue | Select -Unique)
                $Scheduler = (Get-SQLServerSheduler $job.freq_type $job.freq_interval $job.freq_relative_interval)
                $Objects.SchedulerName = $obj.SchedulerName
                $Objects.SchedulerType = $Scheduler.Type
                $Objects.SchedulerInterval = $Scheduler.Interval
                $Objects.SchedulerRelativeInterval = $Scheduler.RelativeInterval
                $Objects.Server = $obj.Server

                #Adding to object which function will return
                $GetJobsSQL += $Objects
            }

            #Grouping objects before it will return
            return $GetJobsSQL | Group-Object JobName | select @{L='JobName';E={$_.Name}},  @{L='JobStep'; E={ $_.Group.JobStep}}, @{L='Type'; E={ $_.Group[0].Type}},  `
            @{L='Description'; E={ $_.Group[0].Description}}, @{L='Command'; E={ $_.Group.Command}}, @{L='NextRun'; E={$_.Group[0].NextRun}}, @{L='VersionSSIS'; E={ $_.Group[0].VersionSSIS}}, `
            @{L='LocationSSIS'; E={ $_.Group[0].LocationSSIS}}, @{L='NameSSIS'; E={ $_.Group[0].NameSSIS}}, @{L='Connection'; E={ $_.Group[0].Connection}}, @{L='AvgDurationMin'; E={ $_.Group[0].AvgDurationMin}}, `
            @{L='SchedulerName'; E={ $_.Group[0].SchedulerName}}, @{L='SchedulerType'; E={ $_.Group[0].SchedulerType}}, @{L='SchedulerInterval'; E={ $_.Group[0].SchedulerInterval}}, @{L='SchedulerRelativeInterval'; E={ $_.Group[0].SchedulerRelativeInterval}}, `
            @{L='Server'; E={ $_.Group[0].Server}}

        }
    }
    End
    {
        #Clear variables
        $GetJobsSQL = @()
        $Objects = @()
    }
}

function Show-SQLServerJobsReport
{
<#
.Synopsis
   The script allows you to generate a Jobs report with MSSQL Server.
.DESCRIPTION
    The script allows you to generate a job report from several servers. Allows you to specify a time window for the report. Allows you get details about connections in packages IS.
.EXAMPLE
    Allows get all Jobs on two servers.

    PS C:\>Show-SQLServerJobsReport -InstanceServer serwer-db2, serwer-db1 -Path D:\temp
.EXAMPLE
    Allows get all Jobs on the two servers which it will starts at specific time

    PS C:\>Show-SQLServerJobsReport -InstanceServer serwer-bpm, serwer-sql -Path D:\temp -StartTime
    Enter start date in format 'dd-MM-yyyy HH:mm': 26-05-2017 21:30
    Report saved to file - D:\temp\Report_Jobs_SQL_260520170205.html
.EXAMPLE
    Allows get all Jobs on the two servers which it will starts at a specific time and it will ends at a specific time

    PS C:\>Show-SQLServerJobsReport -InstanceServer serwer-bpm, serwer-sql -Path D:\temp -StartTime -EndTime
    Enter start date in format 'dd-MM-yyyy HH:mm': 26-05-2017 21:30
    Enter end date in format 'dd-MM-yyyy HH:mm': 26-05-2017 23:30
    Report saved to file - D:\temp\Report_Jobs_SQL_260520170206.html
.LINK
   Author: Mateusz Nadobnik 
   Link: 
   Date: 
   Version: 1.0.0.0
    
   Keywords: Raport, Job, Jobs, SSIS, Scheduler
   Notes: 06.04.2017 - first version
#>
    [CmdletBinding()]
    [Alias()]
    Param
    (
        #Nazwa instancji serwera z którego mają zostać pobrane istniejące Joby
        [Parameter(Mandatory=$true,
                    ValueFromPipeline = $true,
                    Position=0)]
        $InstanceServer,
        #Enter start date in format 'dd-MM-yyyy HH:mm'
        [switch]$StartTime,
        #Enter end date in format 'dd-MM-yyyy HH:mm'
        [switch]$EndTime,
        #Path where it will save report
        [Parameter(Mandatory=$true)]
        $Path
    )

    $ErrorActionPreference = "Stop"

    try 
    {
        $provider =  New-Object cultureinfo ('en-GB')
        $Pattern = '\d{2}-\d{2}-\d{4} \d{2}:\d{2}'

        if($StartTime)
        {
            [string]$StartTime = Read-Host -Prompt "Enter start date in format 'dd-MM-yyyy HH:mm'"
            if($StartTime -match $Pattern)
            {
                $StartTime = [datetime]::ParseExact($StartTime,"dd-M-yyyy HH:mm",$provider)
            }
            else
            {
                Write-Host "Datetime format is incorrect" -ForegroundColor Yellow
                return
            }                
        }

        if($EndTime)
        {
            #Parse date
            [string]$EndTime = Read-Host -Prompt "Enter end date in format 'dd-MM-yyyy HH:mm'"
            if($EndTime -match $Pattern)
            {
                $EndTime = [datetime]::ParseExact($EndTime,"dd-MM-yyyy HH:mm",$provider)
            }
            else
            {
                Write-Host "Datetime format is incorrect" -ForegroundColor Yellow
                return
            }   
        }

        #
        if($StartTime -and $EndTime)
        {
            $GetJobsSQL =  $InstanceServer | Get-SQLServerJobs | where {[datetime]$_.NextRun -ge $StartTime -and [datetime]$_.NextRun -le $EndTime} | Sort-Object NextRun
        }
        elseif($StartTime -and (-not $EndTime))
        {
            $GetJobsSQL = $InstanceServer | Get-SQLServerJobs | where {[datetime]$_.NextRun -ge $StartTime} | Sort-Object NextRun
        }
        elseif((-not $StartTime) -and $EndTime)
        {
            $GetJobsSQL = $InstanceServer | Get-SQLServerJobs | where {[datetime]$_.NextRun -le $EndTime} | Sort-Object NextRun
        }
        else
        {
            $GetJobsSQL = $InstanceServer | Get-SQLServerJobs | Sort-Object NextRun
        }
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }

    try 
    {
        #CSS for html raport
        $Style = "<style>   body {font-family:Calibri;font-size:12pt;} 
                            th {padding: 0 0.5em;text-align:center;border-bottom: 1px solid #f3f3f3;background:#42A961;color:#ffffff;}
                            td {border-bottom: 1px solid #848484;padding: 0 0.5em;text-align:left;padding: 10px 8px 10px 8px;}
                            td+td {border-left: 0px solid #848484;text-align:left;}
                            h1 {color:#848484;size:10px;padding:0;}
                            h2 {color:#848484;size:10px;padding:0;display:inline;background-color:#FBD95B;color:#9C6500}
                            h3 {color:#ffffff;font-size:12px;background:#42A961}
                            table.fixed { table-layout:fixed; font-size:10pt;text-align:left;color:#848484;}
                            table.fixed td { overflow: hidden; }
                            tr:nth-child(odd) { background-color:#fcfcfc; }
                            tr:nth-child(even) { background-color:#fff; }
                            td.avgduration {color:#9C6500;font-size:12pt;}
                            td.command {font-size:10pt;color:#848484}
                            td.description {font-size:10pt;color:#9C6500}
                    </style>"

        #Body html raport                  
        $Body = "<html>
        <head>
        <title>Report -  MSSQL Jobs</title>
        </head><body>
        <h1>Report -  MSSQL Jobs ($(($GetJobsSQL.Server | select -Unique) -join ', '))</h1>
        <table class='fixed' width='100%'>
        <colgroup>
            <col style='width: 300px'/> <!-- JobName -->
            <col style='width: 150px'/> <!-- Description -->
            <col style='width: 200px'/> <!-- Command -->
            <col style='width: 120px'/> <!-- NextRun -->
            <col style='width: 80px'/>  <!-- Avg Duration -->
            <col style='width: 150px'/> <!-- Connection -->
            <col style='width: 135px'/> <!-- Scheduled -->
            <col style='width: 100px'/> <!-- ScheduleType -->
            <col style='width: 80px'/>  <!-- ScheduleInterval -->
            <col style='width: 150px'/> <!-- Server -->

        </colgroup>
        <tr>
            <th>Job Name</th>
            <!--<th>JobStep</th>-->
            <th>Description</th>
            <th>Command</th>
            <th>Next Run</th>
            <!--<th>VersionSSIS</th>
            <th>LocationSSIS</th>-->
            <!--<th>NameSSIS</th>-->
            <th>Avg Duration (min)</th>
            <th>Connection</th>
            <th>Scheduler Name</th>
            <th>Scheduler Type</th>
            <th>Day</th>
            <th>Server</th>
        </tr>
        <tr>
        $($GetJobsSQL | Foreach {
            "<td class='name'>
                    <abbr title='JobStep: $($_.JobStep)'><h2>$($_.JobName)</h2></abbr></br>
                    <i>JobStep: $($_.JobStep -join ', ')</i></br>
                    <i>$(if($_.NameSSIS)
                    {
                    "<i>SSIS Name: $(if(($_.NameSSIS).Length -gt 100){($_.NameSSIS).Substring(0,100)}else{$_.NameSSIS})</br>
                    SSIS Version: $($_.VersionSSIS)</br>
                    Type: $($_.Type):$($_.LocationSSIS)"
                    }
                    else 
                    {"Type: $($_.Type)"})
                    </i>
            </td> 

            <td class='description'>$($_.Description)</td> <!-- Description -->
            <td class='command'>$(if(($_.Command).Length -gt 100){($_.Command).Substring(0,100)}else{$_.Command})</td> <!-- Command -->
        
            <td><h3>$(Get-Date $_.NextRun -Format 'dd-MM-yyyy HH:mm:ss')<h3></td>
            <!-- <td>$($_.VersionSSIS)</td>
            <td>$($_.LocationSSIS)</td> -->
            <!-- <td>
                <abbr title='Version: $($_.VersionSSIS); Location: $($_.LocationSSIS) '>
                    $(if(($_.NameSSIS).Length -gt 60){($_.NameSSIS).Substring(0,60)}else{$_.NameSSIS})</abbr></td> -->
            <td class='avgduration'>$($_.AvgDurationMin)</td>
            <td>$(($_.Connection -join '</br>'))</td>
            <td>$($_.SchedulerName)</td>
            <td>$($_.SchedulerType)</td>
            <td>$($_.SchedulerRelativeInterval + " " +($_.SchedulerInterval  -join '</br>'))</td>
            <td>$($_.Server)</td>
        </tr>"
        })
        </table>
        </body></html>"
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }

    try
    {
        if(Test-Path $Path)
        {
            $FullPath = Join-Path $Path -ChildPath "Report_Jobs_SQL_$(Get-Date -Format "ddMMyyyyhhmm").html"
            Write-Host "Report saved to file - $FullPath"
            $Style + $Body | Out-File -FilePath $FullPath
        }
        else
        {
            Write-Host "Cannot find path '$Path' because it does not exist." -ForegroundColor Yellow
        }
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }

    try
    {
        Invoke-Item $FullPath
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}

#Easy function for encoding scheduler for jobs
function Get-SQLServerSheduler ($freq_type, $freq_interval, $freq_relative_interval)
{
    Process 
    {
        #Create object
        $Scheduler = @{} | Select Type, Interval, RelativeInterval
        switch ($freq_type)
        {
            1 { $Scheduler.Type = 'Once'
                $Scheduler.Interval = 0}

            4 { $Scheduler.Type = 'Daily'
                $Scheduler.Interval = 'Every day'}

            8 { $Scheduler.Type = 'Weekly'            
                    if($freq_interval -band 1) {[array]$Scheduler.Interval += 'Sunday'}
                    if($freq_interval -band 2) {[array]$Scheduler.Interval += 'Monday'}
                    if($freq_interval -band 4) {[array]$Scheduler.Interval += 'Tuesday'}
                    if($freq_interval -band 8) {[array]$Scheduler.Interval += 'Wednesday'}
                    if($freq_interval -band 16) {[array]$Scheduler.Interval += 'Thursday'}
                    if($freq_interval -band 32) {[array]$Scheduler.Interval += 'Friday'}
                    if($freq_interval -band 64) {[array]$Scheduler.Interval += 'Saturday'} }

            16 { $Scheduler.Type = 'Monthly'
                    if($freq_interval -eq 1) {[array]$Scheduler.Interval += 'First'}
                    if($freq_interval -eq 2) {[array]$Scheduler.Interval += 'Second'}
                    if($freq_interval -eq 4) {[array]$Scheduler.Interval += 'Third'}
                    if($freq_interval -eq 8) {[array]$Scheduler.Interval += 'Fourth'}
                    if($freq_interval -eq 16) {[array]$Scheduler.Interval += 'Last'}
                }
        
            32 { $Scheduler.Type = 'Monthly (relative)'
                    if($freq_relative_interval -eq 1) {[array]$Scheduler.RelativeInterval = 'First'}
                    if($freq_relative_interval -eq 2) {[array]$Scheduler.RelativeInterval = 'Second'}
                    if($freq_relative_interval -eq 4) {[array]$Scheduler.RelativeInterval = 'Third'}
                    if($freq_relative_interval -eq 8) {[array]$Scheduler.RelativeInterval = 'Fourth'}
                    if($freq_relative_interval -eq 16) {[array]$Scheduler.RelativeInterval = 'Last'}

                    if($freq_interval -eq 1) {[array]$Scheduler.Interval = 'Sunday'}
                    if($freq_interval -eq 2) {[array]$Scheduler.Interval = 'Monday'}
                    if($freq_interval -eq 3) {[array]$Scheduler.Interval = 'Tuesday'}
                    if($freq_interval -eq 4) {[array]$Scheduler.Interval = 'Wednesday'}
                    if($freq_interval -eq 5) {[array]$Scheduler.Interval = 'Thursday'}
                    if($freq_interval -eq 6) {[array]$Scheduler.Interval = 'Friday'}
                    if($freq_interval -eq 7) {[array]$Scheduler.Interval = 'Saturday'}
                    if($freq_interval -eq 8) {[array]$Scheduler.Interval = 'Day'}
                    if($freq_interval -eq 9) {[array]$Scheduler.Interval = 'Weekday'}
                    if($freq_interval -eq 10) {[array]$Scheduler.Interval = 'Weekend day'} }

                64 { $Scheduler.Type = 'starts when SQL Server Agent service starts'
                    $Scheduler.Interval = 0 }

                128 { $Scheduler.Type = 'runs when computer is idle'
                    $Scheduler.Interval = 0 }
        }
    }
    End 
    {
        return $Scheduler
    }
}