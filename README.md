# Firefox ESR in Docker

Isolated Firefox ESR browser running in a Docker container with persistent profile and separate downloads directory. Uses X11 for native GUI integration.
Automatically rebuilds image if finds newer version at local APT cache.

## Requirements

- Debian host system (Trixie recommended)
- Docker with permission for the current user
- Docker compose plugin
- X11
- PipeWire (for audio)

## Quick Start

```bash
./run.sh
```

## FAQ

### Why?

I just wanted browser with profile, isolated from main system. Just in case, y'know.
And uploaded it just to distribute between my devices.

### Why Debian/X11/Pipewire/whatever..

Feel free to rewrite it to your needs yourself.
