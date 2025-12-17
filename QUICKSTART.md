# Quick Start Guide

## Standard Usage (Without VPN)

```bash
docker run -d \
    --name=jdownloader-2 \
    -p 5800:5800 \
    -v ./config:/config:rw \
    -v ./downloads:/output:rw \
    ghcr.io/remiserriere/jdownloader-2:latest
```

Access at: http://localhost:5800

## With OpenVPN

### 1. Prepare Your Files

Create directory structure:
```bash
mkdir -p ./config ./downloads ./vpn
```

Copy your VPN files to `./vpn/`:
- `config.ovpn` (required)
- `ca.crt` (if needed)
- `credentials.txt` (if using password auth)

Format of `credentials.txt`:
```
your-username
your-password
```

### 2. Run Container

```bash
docker run -d \
    --name=jdownloader-2 \
    --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    -p 5800:5800 \
    -e OPENVPN_ENABLED=1 \
    -v ./config:/config:rw \
    -v ./downloads:/output:rw \
    -v ./vpn/config.ovpn:/config/openvpn/config.ovpn:ro \
    -v ./vpn/ca.crt:/config/openvpn/ca.crt:ro \
    -v ./vpn/credentials.txt:/config/openvpn/credentials.txt:ro \
    ghcr.io/remiserriere/jdownloader-2:latest
```

### 3. Verify VPN Connection

Check logs:
```bash
docker logs jdownloader-2
docker exec jdownloader-2 tail -f /config/logs/openvpn.log
```

Check your IP:
```bash
docker exec jdownloader-2 sh -c "apk add --no-cache curl && curl ifconfig.me"
```

## Using Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  jdownloader-2:
    image: ghcr.io/remiserriere/jdownloader-2:latest
    container_name: jdownloader-2
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    ports:
      - "5800:5800"
    environment:
      - OPENVPN_ENABLED=1
      - TZ=Europe/Paris
    volumes:
      - ./config:/config:rw
      - ./downloads:/output:rw
      - ./vpn/config.ovpn:/config/openvpn/config.ovpn:ro
      - ./vpn/ca.crt:/config/openvpn/ca.crt:ro
      - ./vpn/credentials.txt:/config/openvpn/credentials.txt:ro
    restart: unless-stopped
```

Start:
```bash
docker-compose up -d
```

Stop:
```bash
docker-compose down
```

## Common Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENVPN_ENABLED` | `0` | Enable OpenVPN (`1` to enable) |
| `USER_ID` | `1000` | User ID for file ownership |
| `GROUP_ID` | `1000` | Group ID for file ownership |
| `TZ` | `Etc/UTC` | Timezone (e.g., `Europe/Paris`) |
| `JDOWNLOADER_HEADLESS` | `0` | Run without GUI |

## Troubleshooting

### VPN Not Connecting
1. Check if TUN device is available:
   ```bash
   docker exec jdownloader-2 ls -la /dev/net/tun
   ```
2. View logs:
   ```bash
   docker exec jdownloader-2 cat /config/logs/openvpn.log
   ```

### Can't Access Web Interface
- Ensure port 5800 is not already in use
- Check container is running: `docker ps`
- View container logs: `docker logs jdownloader-2`

### Downloads Not Working
- Check volume permissions
- Verify `/output` directory is writable
- Check JDownloader logs in web interface

## More Information

- **Full Documentation**: [README.md](README.md)
- **OpenVPN Guide**: [OPENVPN.md](OPENVPN.md)
- **Changes from Original**: [CHANGES.md](CHANGES.md)
- **Issues**: [GitHub Issues](https://github.com/remiserriere/docker-jdownloader-2/issues)
