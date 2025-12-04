# Cloudflare Tunnel Assistant

Interactive script to manage Cloudflare tunnels without memorizing commands.

## Features

- **Quick tunnel**: expose `localhost` with one command, auto-generated temporary URL
- **Named tunnels**: fixed URL on your domain, persists between runs
- **DNS routing**: bind subdomains to your tunnel
- **Multiple routes**: one tunnel serving multiple services on different subdomains
- **Full management**: create, list, start, stop, delete

## Requirements

- [cloudflared](https://github.com/cloudflare/cloudflared) installed
- Cloudflare account (only for named tunnels)
- Domain configured on Cloudflare (only for named tunnels)

## Installation

```bash
curl -O https://raw.githubusercontent.com/danie1net0/cloudflare-tunnel-assistant/master/tunnel-assistant.sh
chmod +x tunnel-assistant.sh
```

### Global access (optional)

```bash
sudo mv tunnel-assistant.sh /usr/local/bin/tunnel-assistant
```

Now you can run `tunnel-assistant` from anywhere.

## Usage

```bash
./tunnel-assistant.sh
```

## Menu

```
╔════════════════════════════════════════════════╗
║     Cloudflare Tunnel Assistant                ║
╚════════════════════════════════════════════════╝

 1) Quick Tunnel (no authentication)
 2) Login to Cloudflare
 3) List tunnels
 4) Create named tunnel
 5) Route DNS
 6) Create configuration file
 7) Run tunnel (foreground)
 8) Start tunnel (background)
 9) Stop tunnel
10) Tunnels status
11) Delete tunnel
 0) Exit
```

## Typical workflow

**Quick tunnel** (demo, webhook):

```
Option 1 → enter local URL → done
```

**Permanent tunnel** (recurring use):

```
Option 2 (login) → Option 4 (create) → Option 5 (DNS) → Option 8 (start)
```
