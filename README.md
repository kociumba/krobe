# krobe

krobe is a CLI app that aims to make collecting data about open and active connections easy. 

It is a small, native executable that works on Windows (Linux in early support) without any dependencies, using raw platform APIs.
As a result, the executable size is kept tiny, around ~727kb on Windows and ~407kb on Linux.

Currently, krobe supports TCP/UDP IPv4 connections only (it's the most commonly used type for any data exchange)

To build krobe yoursefl, you need the following prerequisites on your system:

- Windows specific dependencies:
  - Visual Studio Build Tools
  - PowerShell (5.1 or higher)

- Linux specific dependencies:
  - c/c++ build tools(gcc, g++, ar)
  - any bash compatible shell

- Odin (dev-2025-04 or later)
- Taskfile

To build the project, navigate to the repository root and run:

```shell
task build
```

This task is configured to automatically build for your host platform.

If all prerequisites are met, this will compile Krobe and output `krobe[exe ext]` in the `bin/` directory.

> [!IMPORTANT]
> There is currently very early Linux support, krobe compiles on Linux and technically works, but I do not have access to any real linux desktop to test it, so full functionality is not guaranteed

## Features

By default, krobe prints all the connections and data it finds about them to the terminal, alongside some errors that are bound to happen every time you run krobe. These are most likely `Access is denied.` errors on windows. To minimise how many of these happen, you can run krobe as admin, which will allow it to query information with higher privelages.

You can modify the behaviour of krobe with flags:
- `-udp` - gets info about udp connections instead of the default tcp
- `-json` - prints the data as json, and disables any logging outside of the json output, this is meant to allow krobe to work with tools like `jq`
- `-full` - prints the full absolute paths instead of only the executable names
- `-watch:<string>` - allows you to provide a duration string like 20s, 5m, 100ms; krobe will then run on a timer of that duration and print new data every time
- `-search:<string>` - allows you to provide a regex string to match against found executable paths, for example `-search:[Ss]potify` would only output processes related to spotify

You can also get info on these flags using `-h` or `-help`, which prints a help card with this info
