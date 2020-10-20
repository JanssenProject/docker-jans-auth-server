#!/bin/sh
set -e

# =========
# FUNCTIONS
# =========

get_debug_opt() {
    debug_opt=""
    if [ -n "${CLOUD_NATIVE_DEBUG_PORT}" ]; then
        debug_opt="
            -agentlib:jdwp=transport=dt_socket,address=${CLOUD_NATIVE_DEBUG_PORT},server=y,suspend=n
        "
    fi
    echo "${debug_opt}"
}

move_builtin_jars() {
    # move twilio lib
    if [ ! -f /opt/jans/jetty/auth-server/custom/libs/twilio.jar ]; then
        mkdir -p /opt/jans/jetty/auth-server/custom/libs
        mv /usr/share/java/twilio.jar /opt/jans/jetty/auth-server/custom/libs/twilio.jar
    fi

    # move jsmpp lib
    if [ ! -f /opt/jans/jetty/auth-server/custom/libs/jsmpp.jar ]; then
        mkdir -p /opt/jans/jetty/auth-server/custom/libs
        mv /usr/share/java/jsmpp.jar /opt/jans/jetty/auth-server/custom/libs/jsmpp.jar
    fi
}

# ==========
# ENTRYPOINT
# ==========

move_builtin_jars
python3 /app/scripts/wait.py

if [ ! -f /deploy/touched ]; then
    python3 /app/scripts/entrypoint.py
    touch /deploy/touched
fi

python3 /app/scripts/jks_sync.py &
python3 /app/scripts/jca_sync.py &
python3 /app/scripts/mod_context.py

# run oxAuth server
cd /opt/jans/jetty/auth-server
mkdir -p /opt/jetty/temp
exec java \
    -server \
    -XX:+DisableExplicitGC \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=$CLOUD_NATIVE_MAX_RAM_PERCENTAGE \
    -Djans.base=/etc/jans \
    -Dserver.base=/opt/jans/jetty/auth-server \
    -Dlog.base=/opt/jans/jetty/auth-server \
    -Dpython.home=/opt/jython \
    -Djava.io.tmpdir=/opt/jetty/temp \
    $(get_debug_opt) \
    ${CLOUD_NATIVE_JAVA_OPTIONS} \
    -jar /opt/jetty/start.jar
