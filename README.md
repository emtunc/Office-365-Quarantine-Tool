# Office-365-Quarantine-Tool

A simple Office 365 quarantine viewer. I find the web interface to be super slow and buggy and as I use it several times a week I thought I'd put some time in to creating a PowerShell implementation. Also this tool will allow you to wildcard search the Subject and Sender fields; the web interface doesn't give you that flexibility.
Unfortunately Microsoft doesn't make it easy to filter by recipient without first specifying the -Identity. Maybe I'll get round to doing that later.

You will be prompted for your Office 365 credentials as soon as you double click the .exe. The appropriate modules will load if the credentials and permissions are correct.

### Prerequisities

I need to confirm these but I believe you need:

- .NET 3.5 or above
- PowerShell v3 or above
- Set-ExecutionPolicy Unrestricted

### Installing

No install necessary, just double click .exe. 

### Screenshots

![Get-Credential](/Screenshots/Get-Credential.png?raw=true "Get-Credentials diaglog box")
![Main Window](/Screenshots/Main.png?raw=true "Main window")
![An example search](/Screenshots/Search.png?raw=true "An example search")

## Built With

- PowerShell Studio

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
