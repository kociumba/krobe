# krobe

krobe is an app that aims to make collectiong data about open and active local connections easy.

Right now krobe supports tcp ipv4 connections only (it's the most commonly used type for local data exchange connections)

This data can also be exported to json for easy use in other applications, and for processing with tools `jq`

No builds ar ecurrently provided since krobe is in early developement,
to build krobe yoursefl, you need the following prerequisites on your system:

- vs build tools installed
- odin (version: dev-2025-04 and up)
- taskfile
- powershell (version 5.1 and up)

To run the build itself navigate to the repo root directory and run `task build`, if you meet all the prerequisited this will build all the components of krobe and produce a `krobe.exe` in the `/bin` directory

Other platforms aside from windows are not supported yet, but there are plans to work towards corssplatform support
