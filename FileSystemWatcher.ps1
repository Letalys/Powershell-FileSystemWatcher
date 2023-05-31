<#
.SYNOPSIS
	Creating FileWatcher to monitor files and directory
.INPUTS
	InputJson : JSON file to configure watchers, or JSON string, or JSON Object
.OUTPUTS
    Loging file configured by JSON
.NOTES
  Version:        1.0
  Author:         Letalys
  Creation Date:  31/05/2023
  Purpose/Change: Initial script development
.LINK
    Author : Letalys (https://github.com/Letalys)
#>

#requires -version 4
param (
    [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
    [ValidateScript({
        if ((Get-Item -Path $_).Extension.ToLower() -eq ".json" -and (Get-Content -Raw -Path (Get-Item -Path $_).FullName -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue)) {
            $true
        } elseif ($_ -is [String]) {
            $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
        } elseif ($_ -is [System.Management.Automation.PSObject]) {
            $_ | ConvertTo-Json -Depth 1 -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        } else {
            $false
        }
    })]
    $InputJson
)

Clear-Host

Write-host -ForegroundColor Yellow -BackgroundColor Blue "-------- Create Watchers from JSON "
if ((Get-Item -Path $InputJson).Extension.ToLower() -eq ".json" -and (Get-Content -Raw -Path (Get-Item -Path $InputJson).FullName -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue)) {
    $WatcherConfigurations = Get-Content -Raw -Path $InputJson  | ConvertFrom-Json 
} elseif ($InputJson -is [String]) {
    $WatcherConfigurations= $InputJson | ConvertFrom-Json -ErrorAction SilentlyContinue
} elseif ($InputJson -is [System.Management.Automation.PSObject]) {
    $WatcherConfigurations= $InputJson | ConvertTo-Json -Depth 1 -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
}else{
    return -1
}

$WatcherConfigurations | Format-Table

$ScriptBlock ={
    Param($Configuration)

    Try{
        $FWatcher = $null
        #Creating Watcher logs files
        $OutputFile = New-Item -Path "$($Configuration.OutputDir)\$($Configuration.WatcherName).log" -ItemType File -Force

        #Creation de l'objet Watcher
        $FWatcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
            Path = $Configuration.Path
            Filter = $Configuration.Filter
            IncludeSubdirectories = $Configuration.IncludeSubdirectories
            NotifyFilter = $Configuration.NotifyFilters | ForEach-Object { [System.IO.NotifyFilters]::$_ }
        }

        $Action ={
            switch ($event.SourceEventArgs.ChangeType){
                #You can define your own actions here according to the detected events
                'Changed'  { 
                    $OutputFile | Add-Content -Value "$(Get-Date) : Changed > $($event.SourceEventArgs.Name)" 
                }
                'Created'  { 
                    $OutputFile | Add-Content -Value "$(Get-Date) : Created > $($event.SourceEventArgs.Name)"
                }
                'Deleted'  { 
                    $OutputFile | Add-Content -Value "$(Get-Date) : Deleted > $($event.SourceEventArgs.Name)"
                }
                'Renamed'  { 
                    $OutputFile | Add-Content -Value "$(Get-Date) : Renamed"
                    $OutputFile | Add-Content -Value "$(Get-Date) : OldName > $($event.SourceEventArgs.OldName)"
                    $OutputFile | Add-Content -Value "$(Get-Date) : NewName > $($event.SourceEventArgs.Name)"

                }
                #For unmanaged detection types
                default   {  
                    $OutputFile | Add-Content -Value "$(Get-Date) : Unmanaged Event" }
            }  
        }

        $Events = $Configuration.EventHandler | ForEach-Object {
            $EventName = $_
            Register-ObjectEvent -InputObject $FWatcher -EventName $EventName -Action $Action
        }

        $FWatcher.EnableRaisingEvents = $true

        do {
            #Wait-Event for 1 second, allows not to block detections unlike a start-sleep which would ignore incoming events.
            Wait-Event -Timeout 1
        } while ($true)

    }Catch{
        Write-Error $_
    }Finally{
        #Stop monitoring
        $FWatcher.EnableRaisingEvents = $false
                    
        #Deleting event subscriptions
        $Events | ForEach-Object {
            #Unsub Events
            Unregister-Event -SourceIdentifier $_.Name
            #Deletion of underlying Jobs associated with events
            $_ | Remove-Job
        }
        #Dispose Watcher
        $FWatcher.Dispose()
    }
}

Try{
    Write-host -ForegroundColor Yellow -BackgroundColor Blue "-------- Create RunspacePool "

    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $WatcherConfigurations.count)

    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    $RunspacePool.Open()
    $Jobs = @()

    $WatcherConfigurations | Foreach-Object {
        $PowerShell = [powershell]::Create()
        $PowerShell.RunspacePool = $RunspacePool
        $PowerShell.AddScript($ScriptBlock).AddArgument($_)
        $Jobs += $PowerShell.BeginInvoke()
    }
    Write-host -ForegroundColor Yellow -BackgroundColor Blue "-------- Waiting Events "
    $Percent =0
    while ($Jobs.IsCompleted -contains $false) {
        Start-Sleep 1
        Write-Progress -PercentComplete $Percent -Activity "Wait for events" -CurrentOperation "Use CTRL+C To stop all Watchers."
        if($Percent -eq 100){$Percent =0}
        $Percent++
    }

}Catch{
    Write-Error $_
}Finally{
    $RunspacePool.Close()
    Write-Progress -Activity "Wait for events" -CurrentOperation "Use CTRL+C To stop all Watchers." -Completed
    Write-host -ForegroundColor Yellow -BackgroundColor Blue "`n-------- End monitoring"
    Write-Host -ForegroundColor Yellow "See the log files defined in the configuration file or JSON"
}
