
# Powershell : FileSystemWatcher Manager

A script to manage multiple file and folder monitoring.


## How it works

For each Watcher configured in the JSON input, the script creates a Watcher object stored in the Runspace pool. The use of a runpace pool makes it possible to manage several monitoring processes simultaneously without blocking the main powershell thread while managing several outputs.
## How to use

### Generate your own action code for detected events
You can modify the Action code block to add your own actions to perform upon detection of an event detected by your file monitors.

By default a text file is generated for each configurated monitoring. Output file path is configured in JSON input.

***BlockCode to modify (l.65)***
```
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
```

### Configure your Watchers

Use a JSON to configure several watchers. You can use Json object through a pipeline, a Json string or Json Document.

#### Examples
```
[
    {
        "WatcherName": "MyWatcher1",
        "Path": "D:\\Test1",
        "Filter":"*",
        "NotifyFilters": ["Attributes","CreationTime","DirectoryName","FileName","LastAccess","LastWrite","Security","Size"],
        "EventHandler": ["Changed","Created","Deleted","Renamed"],
        "IncludeSubdirectories": true,
        "OutputDir":".\\outputs"
    }
]

```

This configuration called "MyWatcher1" check events from "D:\Test1" directory.
The NotifyFilter check the different attributes to get Event and report them from EventHandler. You can turn off Subdirectories Event when you monitor a directory.

You can add filter for file or monitore all file in the directory.
OutputDir : The path for watcher outputfiles.

You can create several Watchers simultaneously

__Other Exemples__
```
[
    {
        "WatcherName": "MyWatcher2",
        "Path": "D:\\MyFile.txt",
        "Filter":"*",
        "NotifyFilters": ["Attributes","CreationTime","DirectoryName","FileName","LastAccess","LastWrite","Security","Size"],
        "EventHandler": ["Changed","Created","Deleted","Renamed"],
        "IncludeSubdirectories": false,
        "OutputDir":".\\outputs"
    },
    {
        "WatcherName": "MyWatcher3",
        "Path": "c:\\",
        "Filter":"*.txt",
        "NotifyFilters": ["Attributes","CreationTime","DirectoryName","FileName","LastAccess","LastWrite","Security","Size"],
        "EventHandler": ["Changed","Created","Deleted","Renamed"],
        "IncludeSubdirectories": true,
        "OutputDir":".\\outputs"
    }
]

```
## Links
https://github.com/Letalys/Powershell-FileSystemWatcher


## Autor
- [@Letalys (GitHUb)](https://www.github.com/Letalys)
