#!/bin/sh

set -u # Treat unset variables as an error.

trap "terminate" TERM QUIT INT

# JDownloader logs all environment variables.  Make sure the MyJDownloader
# credentials don't leak.
unset MYJDOWNLOADER_EMAIL
unset MYJDOWNLOADER_PASSWORD

log() {
    echo "[startapp] $@"
}

log_debug() {
    if is-bool-val-true "${CONTAINER_DEBUG:-0}"; then
        echo "$@"
    fi
}

log_error() {
    echo "[startapp] ERROR: $@" >&2
}

is_jd_running() {
    pgrep java >/dev/null
}

is_openvpn_running() {
    if [ -f /config/openvpn/openvpn.pid ]; then
        PID=$(cat /config/openvpn/openvpn.pid 2>/dev/null)
        if [ -n "${PID}" ] && kill -0 "${PID}" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

cleanup_openvpn_tail() {
    if [ -f /config/openvpn/openvpn-tail.pid ]; then
        TAIL_PID=$(cat /config/openvpn/openvpn-tail.pid 2>/dev/null)
        if [ -n "${TAIL_PID}" ] && [ "${TAIL_PID}" -eq "${TAIL_PID}" ] 2>/dev/null; then
            kill "${TAIL_PID}" 2>/dev/null || true
        fi
        rm -f /config/openvpn/openvpn-tail.pid
    fi
}

start_openvpn() {
    # Check if OpenVPN is enabled
    if ! is-bool-val-true "${OPENVPN_ENABLED:-0}"; then
        return 0
    fi

    log "OpenVPN is enabled, starting..."

    # Check if already running
    if is_openvpn_running; then
        log "OpenVPN is already running"
        return 0
    fi

    # Check for required capabilities and devices
    if [ ! -c /dev/net/tun ]; then
        log_error "/dev/net/tun device not found!"
        log_error "Container must be started with --device=/dev/net/tun"
        return 1
    fi

    # Check if config file exists
    if [ ! -f "${OPENVPN_CONFIG_FILE}" ]; then
        log_error "OpenVPN configuration file not found: ${OPENVPN_CONFIG_FILE}"
        log_error "Please mount your OpenVPN configuration file to ${OPENVPN_CONFIG_FILE}"
        return 1
    fi

    # Create OpenVPN config directory and logs directory
    mkdir -p /config/openvpn
    mkdir -p /config/logs

    # Prepare OpenVPN arguments
    OPENVPN_OPTS="--config ${OPENVPN_CONFIG_FILE}"

    # Check if auth-user-pass is already specified in the config file
    # If not, and credentials.txt exists, add it as a command-line option
    if ! grep -q "^[[:space:]]*auth-user-pass\([[:space:]]\|$\)" "${OPENVPN_CONFIG_FILE}"; then
        if [ -f /config/openvpn/credentials.txt ]; then
            OPENVPN_OPTS="${OPENVPN_OPTS} --auth-user-pass /config/openvpn/credentials.txt"
            log "Using credentials from /config/openvpn/credentials.txt"
        fi
    else
        log "auth-user-pass directive found in config file"
    fi

    # Add other common options
    OPENVPN_OPTS="${OPENVPN_OPTS} --cd /config/openvpn"
    OPENVPN_OPTS="${OPENVPN_OPTS} --script-security 2"
    OPENVPN_OPTS="${OPENVPN_OPTS} --auth-nocache"
    OPENVPN_OPTS="${OPENVPN_OPTS} --writepid /config/openvpn/openvpn.pid"
    OPENVPN_OPTS="${OPENVPN_OPTS} --daemon"

    log "Starting OpenVPN..."
    log "Configuration file: ${OPENVPN_CONFIG_FILE}"

    # Ensure log file exists
    touch /config/logs/openvpn.log

    # Start OpenVPN with logging to file
    OPENVPN_OPTS="${OPENVPN_OPTS} --log-append /config/logs/openvpn.log"
    /usr/sbin/openvpn ${OPENVPN_OPTS}

    # Wait a moment and verify it started
    sleep 2
    if is_openvpn_running; then
        OPENVPN_PID=$(cat /config/openvpn/openvpn.pid 2>/dev/null)
        if [ -n "${OPENVPN_PID}" ]; then
            log "OpenVPN started successfully (PID: ${OPENVPN_PID})"
        else
            log "OpenVPN started successfully"
        fi
        
        # Start a background process to tail OpenVPN logs to stdout
        # This allows logs to appear in docker logs while also being saved to file
        if [ ! -f /config/openvpn/openvpn-tail.pid ]; then
            tail -F /config/logs/openvpn.log 2>/dev/null | sed 's/^/[openvpn] /' &
            TAIL_PID=$!
            echo "$TAIL_PID" > /config/openvpn/openvpn-tail.pid
        fi
        
        return 0
    else
        log_error "OpenVPN failed to start"
        return 1
    fi
}

stop_openvpn() {
    if ! is_openvpn_running; then
        cleanup_openvpn_tail
        return 0
    fi

    log "Stopping OpenVPN..."
    PID=$(cat /config/openvpn/openvpn.pid 2>/dev/null)
    if [ -n "${PID}" ] && [ "${PID}" -eq "${PID}" ] 2>/dev/null; then
        kill "${PID}" 2>/dev/null || true
        # Wait up to 5 seconds for OpenVPN to stop
        RETRY_COUNT=0
        MAX_RETRIES=10
        while [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ] && is_openvpn_running; do
            sleep 0.5
            RETRY_COUNT=$((RETRY_COUNT + 1))
        done
        
        # Force kill if still running
        if is_openvpn_running; then
            kill -9 "${PID}" 2>/dev/null || true
        fi
        
        rm -f /config/openvpn/openvpn.pid
        log "OpenVPN stopped"
    fi

    cleanup_openvpn_tail
}

start_jd() {
    ARGS="/tmp/.jd_args"

    # Handle max memory from environment variable.
    if [ -n "${JDOWNLOADER_MAX_MEM:-}" ]; then
        # NOTE: It is assumed that the max memory value has already been
        # validated.
        echo "-Xmx$JDOWNLOADER_MAX_MEM" >> "$ARGS"
    fi

    # Support for JDownloader2.vmoptions.
    # https://support.jdownloader.org/Knowledgebase/Article/View/vmoptions-file
    if [ -f /config/JDownloader2.vmoptions ]; then
        cat /config/JDownloader2.vmoptions >> "$ARGS"
    fi

    if is-bool-val-true "${JDOWNLOADER_HEADLESS:-0}"; then
        echo "-XX:-UsePerfData" >> "$ARGS"
        echo "-Djava.awt.headless=true" >> "$ARGS"
    else
        echo "-XX:-UsePerfData" >> "$ARGS"
        echo "-Dawt.useSystemAAFontSettings=gasp" >> "$ARGS"
        echo "-Djava.awt.headless=false" >> "$ARGS"
    fi

    echo "-jar" >> "$ARGS"
    echo "/config/JDownloader.jar" >> "$ARGS"

    cat "$ARGS" | grep -v "^\s*#" | tr '\n' '\0' | xargs -0 \
        /usr/bin/java >/config/logs/output.log 2>&1 &
}

kill_jd() {
    # Kill JDownloader.
    killall java 2>/dev/null

    # Wait for JDownloader to terminate.
    while is_jd_running; do
        sleep 0.25
    done
}

terminate() {
    log_debug "terminating JDownloader2..."
    kill_jd
    log_debug "JDownloader2 terminated."
    
    # Stop OpenVPN if it was started
    if is-bool-val-true "${OPENVPN_ENABLED:-0}"; then
        stop_openvpn
    fi
    
    exit 0
}

# Start OpenVPN if enabled
start_openvpn

# Start JDownloader.
#
# NOTE: Because JDownloader can restart itself (e.g. during an update), we have
#       to launch JDownloader in background and monitor its status. This is
#       needed to make sure the container doesn't terminate itself during a
#       restart of JDownloader.
log_debug "starting JDownloader2..."
start_jd

# Wait until it dies.
wait $!

# Now monitor its state. At this point, we cannot "wait" on the process since
# it has not been launched by us.
while true
do
    if ! is_jd_running; then
        log_debug "JDownloader2 not running, exiting..."
        break
    fi
    sleep 1
done

# vim:ft=sh:ts=4:sw=4:et:sts=4
