# OpenVPN Configuration Guide

This guide provides detailed instructions on how to configure and use OpenVPN with JDownloader 2.

## Prerequisites

Before you begin, ensure you have:

1. A VPN service that provides OpenVPN configuration files
2. Docker installed on your system
3. Basic knowledge of Docker and command-line operations

## Required Files

From your VPN provider, you will need:

- **config.ovpn**: Your OpenVPN configuration file
- **ca.crt**: Certificate Authority certificate (if required by your config)
- **client.crt**: Client certificate (if using certificate-based auth)
- **client.key**: Client private key (if using certificate-based auth)

## Setup Instructions

### Step 1: Prepare Your Configuration Files

1. Create a directory structure for your VPN files:

```bash
mkdir -p ~/jdownloader-vpn/{config,downloads,vpn}
```

2. Copy your VPN configuration files to the `vpn` directory:

```bash
cp /path/to/your/config.ovpn ~/jdownloader-vpn/vpn/
cp /path/to/your/ca.crt ~/jdownloader-vpn/vpn/
# Add other certificate files if needed
```

### Step 2: Create Credentials File (if needed)

If your VPN requires username and password authentication, create a credentials file (you can name it `credentials.txt`, `auth.txt`, or any name):

```bash
cat > ~/jdownloader-vpn/vpn/credentials.txt << EOF
your-username
your-password
EOF
```

**Note about file permissions:** 
- If you mount files as read-write (`:rw`), the container will attempt to set secure permissions (600)
- If you mount files as read-only (`:ro`), permission changes will be skipped automatically
- Both approaches are secure - read-only mounts prevent any modifications to your VPN files

### Step 3: Adjust OpenVPN Configuration (if needed)

Some VPN configurations may need adjustments. Edit your `config.ovpn` file if necessary:

1. Ensure certificate paths point to `/config/openvpn/` or use relative paths:
   ```
   # Examples of valid paths:
   ca /config/openvpn/ca.crt
   ca ca.crt
   ```

2. For authentication credentials, you have two options:
   - **Option A:** Specify the credential file directly in your `.ovpn` config:
     ```
     auth-user-pass /config/openvpn/auth.txt
     ```
   - **Option B:** Create a `credentials.txt` file and omit the `auth-user-pass` line from the config (the container will add it automatically)

Example modifications:

```
# Before
ca /absolute/path/to/ca.crt
cert /absolute/path/to/client.crt
key /absolute/path/to/client.key

# After
ca /config/openvpn/ca.crt
cert /config/openvpn/client.crt
key /config/openvpn/client.key
```

### Step 4: Run with Docker

Using Docker command:

```bash
docker run -d \
    --name=jdownloader-2 \
    --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    -p 5800:5800 \
    -e OPENVPN_ENABLED=1 \
    -e TZ=Europe/Paris \
    -v ~/jdownloader-vpn/config:/config:rw \
    -v ~/jdownloader-vpn/downloads:/output:rw \
    -v ~/jdownloader-vpn/vpn/config.ovpn:/config/openvpn/config.ovpn:ro \
    -v ~/jdownloader-vpn/vpn/ca.crt:/config/openvpn/ca.crt:ro \
    -v ~/jdownloader-vpn/vpn/credentials.txt:/config/openvpn/credentials.txt:ro \
    ghcr.io/remiserriere/jdownloader-2:latest
```

### Step 5: Run with Docker Compose

1. Copy the example docker-compose file:

```bash
cp docker-compose-openvpn.yml ~/jdownloader-vpn/docker-compose.yml
```

2. Edit the `docker-compose.yml` file to match your paths:

```bash
cd ~/jdownloader-vpn
nano docker-compose.yml
```

3. Start the container:

```bash
docker-compose up -d
```

## Verification

### Check if OpenVPN is running

```bash
# View container logs
docker logs jdownloader-2

# Check OpenVPN logs specifically
docker exec jdownloader-2 tail -f /config/logs/openvpn.log
```

You should see messages indicating successful VPN connection.

### Verify VPN Connection

1. Access the JDownloader GUI at `http://localhost:5800`

2. Check your IP address through JDownloader:
   - Add a download link that shows your IP address
   - Or use a site like https://ifconfig.me

3. Verify it matches your VPN provider's IP, not your real IP

### Check Connection from Container

```bash
# Check the IP as seen from inside the container
docker exec jdownloader-2 sh -c "apk add --no-cache curl && curl ifconfig.me"
```

## Troubleshooting

### VPN Not Connecting

1. **Check logs**:
   ```bash
   docker exec jdownloader-2 cat /config/logs/openvpn.log
   ```

2. **Verify required capabilities**:
   - Ensure `--cap-add=NET_ADMIN` is set
   - Ensure `--device=/dev/net/tun` is set

3. **Check configuration file**:
   ```bash
   docker exec jdownloader-2 cat /config/openvpn/config.ovpn
   ```

### Authentication Failures

1. **Check credentials file format**:
   ```bash
   docker exec jdownloader-2 cat /config/openvpn/credentials.txt
   ```
   
   Should have exactly two lines: username and password

2. **Verify certificate files are mounted**:
   ```bash
   docker exec jdownloader-2 ls -la /config/openvpn/
   ```

### Connection Drops

The OpenVPN service in this container is configured with auto-restart. If the connection drops, OpenVPN will automatically attempt to reconnect.

To monitor reconnection attempts:
```bash
docker exec jdownloader-2 tail -f /config/logs/openvpn.log
```

### DNS Issues

If you experience DNS resolution problems:

1. Add custom DNS servers to your docker-compose.yml:
   ```yaml
   dns:
     - 8.8.8.8
     - 1.1.1.1
   ```

2. Or in docker run command:
   ```bash
   --dns=8.8.8.8 --dns=1.1.1.1
   ```

## Advanced Configuration

### Custom OpenVPN Options

You can modify the OpenVPN service script at `/etc/services.d/openvpn/run` for advanced customization.

### Multiple VPN Configurations

To switch between different VPN configurations:

1. Mount different config files
2. Change the `OPENVPN_CONFIG_FILE` environment variable:
   ```bash
   -e OPENVPN_CONFIG_FILE=/config/openvpn/alternative-config.ovpn
   ```

### Kill Switch

The container routes all traffic through the VPN by default. If the VPN connection drops, traffic will not leak (the connection will simply fail until VPN reconnects).

## Security Recommendations

1. **Protect your credentials**:
   ```bash
   chmod 600 ~/jdownloader-vpn/vpn/credentials.txt
   chmod 600 ~/jdownloader-vpn/vpn/*.key
   ```

2. **Use read-only mounts** for VPN configuration files (`:ro` flag)

3. **Regular updates**: Keep your container image up to date:
   ```bash
   docker pull ghcr.io/remiserriere/jdownloader-2:latest
   docker-compose down
   docker-compose up -d
   ```

## Support

If you encounter issues:

1. Check the [main README](README.md) for general container usage
2. Review your VPN provider's OpenVPN documentation
3. Open an issue on [GitHub](https://github.com/remiserriere/docker-jdownloader-2/issues)

## Example VPN Providers

This configuration should work with most VPN providers that offer OpenVPN support:

- NordVPN
- ExpressVPN
- ProtonVPN
- Mullvad
- Private Internet Access (PIA)
- And many others

Refer to your VPN provider's documentation for obtaining the OpenVPN configuration files.
