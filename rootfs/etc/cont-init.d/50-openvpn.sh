#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Check if OpenVPN is enabled
if ! is-bool-val-true "${OPENVPN_ENABLED:-0}"; then
    # OpenVPN is disabled, nothing to do
    exit 0
fi

log() {
    echo "[cont-init.d] 50-openvpn.sh: $@"
}

log_error() {
    echo "[cont-init.d] 50-openvpn.sh: ERROR: $@" >&2
}

log "OpenVPN is enabled, checking configuration..."

# Create OpenVPN config directory
mkdir -p /config/openvpn
mkdir -p /config/logs

# Verify that the config file exists
if [ ! -f "${OPENVPN_CONFIG_FILE}" ]; then
    log_error "OpenVPN configuration file not found: ${OPENVPN_CONFIG_FILE}"
    log_error "Please mount your OpenVPN configuration file to this location."
    log_error "Example: -v /path/to/config.ovpn:${OPENVPN_CONFIG_FILE}:ro"
    exit 1
fi

log "OpenVPN configuration file found: ${OPENVPN_CONFIG_FILE}"

# Check if TUN device is available
if [ ! -c /dev/net/tun ]; then
    log_error "/dev/net/tun device not found!"
    log_error "Container must be started with --device=/dev/net/tun"
    exit 1
fi

log "TUN device is available"

# Check for credentials file
if [ -f /config/openvpn/credentials.txt ]; then
    log "Credentials file found: /config/openvpn/credentials.txt"
    # Ensure credentials file has correct permissions
    chmod 600 /config/openvpn/credentials.txt
else
    log "No credentials file found. If your VPN requires username/password authentication,"
    log "please create /config/openvpn/credentials.txt with username on first line and password on second line."
fi

# Check for certificate files
for cert_file in ca.crt client.crt client.key; do
    if [ -f "/config/openvpn/${cert_file}" ]; then
        log "Certificate file found: /config/openvpn/${cert_file}"
        # Ensure proper permissions for key files
        if [ "${cert_file}" = "client.key" ]; then
            chmod 600 "/config/openvpn/${cert_file}"
        fi
    fi
done

log "OpenVPN initialization complete"

# vim:ft=sh:ts=4:sw=4:et:sts=4
