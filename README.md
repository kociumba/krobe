# krobe

krobe is an app that aims to make collecting data about open and active local connections easy.

Right now krobe supports TCP IPv4 connections only (it's the most commonly used type for local data exchange)

This data can also be exported to JSON for easy use in other applications, and for processing with tools `jq`

No builds are currently provided since krobe is in early developement,
to build krobe yoursefl, you need the following prerequisites on your system:

- Visual Studio Build Tools
- Odin (dev-2025-04 or later)
- Taskfile
- PowerShell (5.1 or higher)

To build the project, navigate to the repository root and run:

```shell
task build
```

Alternatively if you want to avoid using Taskfile, you will have to in order execute:

```shell
mkdir bin
```

```pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "./win_vs_build.ps1" -Target all -WorkingDir "[repo root directory]"
```

```pwsh
odin build . -out:bin/krobe.exe -o:speed -resource:krobe.rc
```

If all prerequisites are met, this will compile Krobe and output `krobe.exe` in the `bin/` directory.

Other platforms aside from windows are not supported yet, but there are plans to work towards corss-platform support
