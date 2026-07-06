# Configuration Variables
$ServerName   = "localhost\MSSQLSERVER01"
$DatabaseName = "msdb"  
$JobName      = "Schedule refresh for hospital_db"

# 🔥 CRITICAL PATH: Define the exact location where SQL Agent saves the file 
# Make sure this matches the path you configured in SSMS Job Step Advanced Options!
$LogFilePath  = "C:\Massachussets_General_Hospital_Project\Refreshing the data warehouse\agent_output"
$StartJobQuery = "EXEC dbo.sp_start_job @job_name = '$JobName';"

# T-SQL query that checks if the job finished
$CheckStatusQuery = @"
SELECT TOP 1 h.run_status
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
WHERE j.name = '$JobName' AND h.step_id = 1
ORDER BY h.instance_id DESC;
"@

Write-Host "Connecting to $ServerName..." -ForegroundColor Cyan
Write-Host "Triggering SQL Agent Job: [$JobName]..." -ForegroundColor Yellow

# 🔥 Pre-execution cleanup: Clear old log data if the file already exists
if (Test-Path $LogFilePath) { Clear-Content $LogFilePath -ErrorAction SilentlyContinue }

try {
    $ConnString = "Server=$ServerName;Database=$DatabaseName;Integrated Security=True;TrustServerCertificate=True;"
    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnString)
    $Connection.Open()

    # 1. Start the Agent Job
    $StartCommand = New-Object System.Data.SqlClient.SqlCommand($StartJobQuery, $Connection)
    $Null = $StartCommand.ExecuteNonQuery()
    Write-Host "Job started on server. Monitoring background progress..." -ForegroundColor Gray
    
    # Wait a few seconds for the execution history record to initialize
    Start-Sleep -Seconds 6

    # 2. Monitor Loop
    $IsRunning = $true
    while ($IsRunning) {
        $HistoryCommand = New-Object System.Data.SqlClient.SqlCommand($CheckStatusQuery, $Connection)
        $Reader = $HistoryCommand.ExecuteReader()
        
        if ($Reader.Read()) {
            $RunStatus = $Reader["run_status"]
            $Reader.Close()

            # SQL Status Codes: 1 = Succeeded, 0 = Failed, 4 = In Progress
            if ($RunStatus -eq 1 -or $RunStatus -eq 0) {
                
                if ($RunStatus -eq 1) {
                    Write-Host "`n✅ DATA REFRESH COMPLETE!`n" -ForegroundColor Green
                    Write-Host "--- SERVER MESSAGES ---" -ForegroundColor Gray
                    
                    # 🔥 Read directly from the physical file to bypass SQL's truncation limit
                    if (Test-Path $LogFilePath) {
                        $RawContent = Get-Content -Path $LogFilePath -Raw
                        $RawLines = $RawContent -split '\[SQLSTATE \d+\] \(Message \d+\)|\r?\n'
                        
                        foreach ($Line in $RawLines) {
                            $CleanLine = $Line.Trim()
                            
                            # Skip empty spaces or standard SQL Agent wrappers
                            if ([string]::IsNullOrWhiteSpace($CleanLine)) { continue }
                            if ($CleanLine -like "Executed as user:*") { continue }
                            if ($CleanLine -like "The step succeeded.*") { continue }
                            
                            # Clean out any trailing or leading line dots/junk left behind by the wrapper
                            $CleanLine = $CleanLine -replace "^\s*\.\.\.\s*", ""
                            $CleanLine = $CleanLine -replace "\s*\.\.\.\s*$", ""
                            $CleanLine = $CleanLine.Trim()
                            if ([string]::IsNullOrWhiteSpace($CleanLine)) { continue }

                            # Handle data row affected counts (Print in White)
                            if ($CleanLine -like "(*row*affected*)") {
                                Write-Host "   $CleanLine" -ForegroundColor White
                            } 
                            # Handle your pure Data Warehouse pipeline prints (Print in Yellow)
                            else {
                                Write-Host "   [SQL]: $CleanLine" -ForegroundColor Yellow
                            }
                        }
                    } else {
                        Write-Host "⚠️ Log file not found at $LogFilePath." -ForegroundColor DarkYellow
                        Write-Host "Ensure 'Include step output in history' and 'Output file' are set in SSMS." -ForegroundColor Gray
                    }
                }

                else {
                    Write-Host "`n❌ JOB FAILED ON SERVER!`n" -ForegroundColor Red
                    Write-Host "--- SERVER ERROR LOGS ---" -ForegroundColor LightRed
                    
                    if (Test-Path $LogFilePath) {
                        $RawContent = Get-Content -Path $LogFilePath -Raw
                        $LogLines = $RawContent -split '\r?\n'
                        foreach ($Line in $LogLines) {
                            if (-not [string]::IsNullOrWhiteSpace($Line)) {
                                Write-Host "   $($Line.Trim())" -ForegroundColor White
                            }
                        }
                    } else {
                        Write-Host "⚠️ Log file not found at $LogFilePath." -ForegroundColor DarkYellow
                    }
                }
                
                $IsRunning = $false
            }
            else {
                # Print trailing dots while the server processes the data
                Write-Host "." -NoNewline
                Start-Sleep -Seconds 5
            }
        } else {
            $Reader.Close()
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 5
        }
    }
    $Connection.Close()
}
catch {
    Write-Host "❌ Error: Failed to monitor the SQL Server job." -ForegroundColor Red
    Write-Error $_.Exception.Message
    if ($Connection.State -eq "Open") { $Connection.Close() }
}

# Keep window open for 20 seconds to read the text output
Start-Sleep -Seconds 20


