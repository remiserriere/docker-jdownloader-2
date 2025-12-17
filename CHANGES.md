# Changes from Original Repository

This is a modified fork of [jlesage/docker-jdownloader-2](https://github.com/jlesage/docker-jdownloader-2).

## Major Modifications

### 1. OpenVPN Integration

Added full OpenVPN support to route all JDownloader traffic through a VPN connection.

**New Features:**
- Automatic OpenVPN process management with auto-restart
- Support for username/password authentication via credentials file
- Support for certificate-based authentication
- Dedicated logging for OpenVPN operations
- Proper error handling and validation
- Secure defaults (OpenVPN disabled by default)

**New Files:**
- `rootfs/etc/services.d/openvpn/run` - OpenVPN service script
- `rootfs/etc/cont-init.d/50-openvpn.sh` - OpenVPN initialization script
- `OPENVPN.md` - Comprehensive OpenVPN configuration guide
- `docker-compose-openvpn.yml` - Example docker-compose file with OpenVPN

**New Environment Variables:**
- `OPENVPN_ENABLED` - Enable/disable OpenVPN (default: 0)
- `OPENVPN_CONFIG_FILE` - Path to OpenVPN config file (default: /config/openvpn/config.ovpn)

**Required Docker Flags (when OpenVPN enabled):**
- `--cap-add=NET_ADMIN` - Required for VPN operations
- `--device=/dev/net/tun` - Required for TUN/TAP interface

### 2. Build and Distribution Changes

**GitHub Container Registry:**
- Changed from DockerHub to GitHub Container Registry (GHCR)
- Images available at: `ghcr.io/remiserriere/jdownloader-2`
- Automated builds on all branch pushes
- Removed DockerHub publishing workflow

**Workflow Modifications:**
- Simplified build workflow
- Removed notification steps
- Added automatic repository checkout
- Updated to push to GHCR for all commits (not just releases)

### 3. Documentation Updates

**Updated README:**
- Clear indication that this is a modified fork
- OpenVPN usage documentation
- Updated all image references to GHCR
- Added OpenVPN environment variables section

**New Documentation:**
- `OPENVPN.md` - Complete OpenVPN setup and troubleshooting guide
- `CHANGES.md` - This file, documenting all modifications

**Docker Compose Examples:**
- Standard example updated to use GHCR
- New OpenVPN-enabled example

### 4. Additional Files

- `.gitignore` - Added to prevent committing local config and build artifacts

## Compatibility

All changes are backward compatible:
- OpenVPN is disabled by default
- All original JDownloader functionality remains unchanged
- Existing configurations continue to work without modification
- No breaking changes to the base image

## Image Differences

**Added Packages:**
- `openvpn` - OpenVPN client
- `iptables` - Network management
- `ip6tables` - IPv6 network management

**Size Impact:**
The addition of OpenVPN and network utilities adds approximately 5-10MB to the image size.

## Usage Differences

### Without OpenVPN (Original Behavior)
```bash
docker run -d \
    --name=jdownloader-2 \
    -p 5800:5800 \
    -v /config:/config:rw \
    -v /downloads:/output:rw \
    ghcr.io/remiserriere/jdownloader-2
```

### With OpenVPN (New Feature)
```bash
docker run -d \
    --name=jdownloader-2 \
    --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    -p 5800:5800 \
    -e OPENVPN_ENABLED=1 \
    -v /config:/config:rw \
    -v /downloads:/output:rw \
    -v /vpn/config.ovpn:/config/openvpn/config.ovpn:ro \
    -v /vpn/credentials.txt:/config/openvpn/credentials.txt:ro \
    ghcr.io/remiserriere/jdownloader-2
```

## Security Considerations

1. **No Vulnerabilities**: All changes passed CodeQL security scanning
2. **Principle of Least Privilege**: OpenVPN disabled by default
3. **Secure Credentials**: Credentials file should use mode 600
4. **Read-only Mounts**: VPN configuration files mounted as read-only
5. **No Secrets in Environment**: Credentials via file, not environment variables

## Maintenance

This fork will be maintained to:
1. Keep up with OpenVPN security updates
2. Maintain compatibility with the upstream repository
3. Fix bugs related to OpenVPN integration
4. Accept community contributions for OpenVPN features

## Credits

- **Original Image**: [jlesage/docker-jdownloader-2](https://github.com/jlesage/docker-jdownloader-2)
- **Base Image**: [jlesage/baseimage-gui](https://github.com/jlesage/docker-baseimage-gui)
- **OpenVPN Integration**: remiserriere

## License

This project maintains the same license as the original repository. See [LICENSE](LICENSE) file for details.
