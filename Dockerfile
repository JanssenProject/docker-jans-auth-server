FROM adoptopenjdk/openjdk11:jre-11.0.8_10-alpine

# symlink JVM
RUN mkdir -p /usr/lib/jvm/default-jvm /usr/java/latest \
    && ln -sf /opt/java/openjdk /usr/lib/jvm/default-jvm/jre \
    && ln -sf /usr/lib/jvm/default-jvm/jre /usr/java/latest/jre

# ===============
# Alpine packages
# ===============

RUN apk update \
    && apk add --no-cache openssl py3-pip tini curl bash \
    && apk add --no-cache --virtual build-deps wget git

# ======
# rclone
# ======

ARG RCLONE_VERSION=v1.51.0
RUN wget -q https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip -O /tmp/rclone.zip \
    && unzip -qq /tmp/rclone.zip -d /tmp \
    && mv /tmp/rclone-${RCLONE_VERSION}-linux-amd64/rclone /usr/bin/ \
    && rm -rf /tmp/rclone-${RCLONE_VERSION}-linux-amd64 /tmp/rclone.zip

# =====
# Jetty
# =====

ARG JETTY_VERSION=9.4.26.v20200117
ARG JETTY_HOME=/opt/jetty
ARG JETTY_BASE=/opt/jans/jetty
ARG JETTY_USER_HOME_LIB=/home/jetty/lib

# Install jetty
RUN wget -q https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/${JETTY_VERSION}/jetty-distribution-${JETTY_VERSION}.tar.gz -O /tmp/jetty.tar.gz \
    && mkdir -p /opt \
    && tar -xzf /tmp/jetty.tar.gz -C /opt \
    && mv /opt/jetty-distribution-${JETTY_VERSION} ${JETTY_HOME} \
    && rm -rf /tmp/jetty.tar.gz

# Ports required by jetty
EXPOSE 8080

# ======
# Jython
# ======

ARG JYTHON_VERSION=2.7.2
RUN wget -q https://repo1.maven.org/maven2/org/python/jython-installer/${JYTHON_VERSION}/jython-installer-${JYTHON_VERSION}.jar -O /tmp/jython-installer.jar \
    && mkdir -p /opt/jython \
    && java -jar /tmp/jython-installer.jar -v -s -d /opt/jython \
    && rm -f /tmp/jython-installer.jar /tmp/*.properties

# ===========
# Auth server
# ===========

ENV JANS_VERSION=5.0.0-SNAPSHOT
ENV JANS_BUILD_DATE="2020-10-17 19:42"
ENV JANS_SOURCE_URL=https://maven.jans.io/maven/io/jans/jans-auth-server/${JANS_VERSION}/jans-auth-server-${JANS_VERSION}.war

# Install oxAuth
RUN wget -q ${JANS_SOURCE_URL} -O /tmp/auth-server.war \
    && mkdir -p ${JETTY_BASE}/auth-server/webapps/auth-server \
    && unzip -qq /tmp/auth-server.war -d ${JETTY_BASE}/auth-server/webapps/auth-server \
    && java -jar ${JETTY_HOME}/start.jar jetty.home=${JETTY_HOME} jetty.base=${JETTY_BASE}/auth-server --add-to-start=server,deploy,annotations,resources,http,http-forwarded,threadpool,jsp,websocket \
    && rm -f /tmp/auth-server.war

# ===========
# Custom libs
# ===========

RUN mkdir -p /usr/share/java

ARG TWILIO_VERSION=7.17.0
RUN wget -q https://repo1.maven.org/maven2/com/twilio/sdk/twilio/${TWILIO_VERSION}/twilio-${TWILIO_VERSION}.jar -O /usr/share/java/twilio.jar
ARG JSMPP_VERSION=2.3.7
RUN wget -q https://repo1.maven.org/maven2/org/jsmpp/jsmpp/${JSMPP_VERSION}/jsmpp-${JSMPP_VERSION}.jar -O /usr/share/java/jsmpp.jar

# ======
# Python
# ======

RUN apk add --no-cache py3-cryptography
COPY requirements.txt /app/requirements.txt
RUN pip3 install -U pip \
    && pip3 install --no-cache-dir -r /app/requirements.txt \
    && rm -rf /src/jans-pycloudlib/.git

# =======
# Cleanup
# =======

RUN apk del build-deps \
    && rm -rf /var/cache/apk/*

# =======
# License
# =======

RUN mkdir -p /licenses
COPY LICENSE /licenses/

# ==========
# Config ENV
# ==========

ENV JANS_CONFIG_ADAPTER=consul \
    JANS_CONFIG_CONSUL_HOST=localhost \
    JANS_CONFIG_CONSUL_PORT=8500 \
    JANS_CONFIG_CONSUL_CONSISTENCY=stale \
    JANS_CONFIG_CONSUL_SCHEME=http \
    JANS_CONFIG_CONSUL_VERIFY=false \
    JANS_CONFIG_CONSUL_CACERT_FILE=/etc/certs/consul_ca.crt \
    JANS_CONFIG_CONSUL_CERT_FILE=/etc/certs/consul_client.crt \
    JANS_CONFIG_CONSUL_KEY_FILE=/etc/certs/consul_client.key \
    JANS_CONFIG_CONSUL_TOKEN_FILE=/etc/certs/consul_token \
    JANS_CONFIG_CONSUL_NAMESPACE=jans \
    JANS_CONFIG_KUBERNETES_NAMESPACE=default \
    JANS_CONFIG_KUBERNETES_CONFIGMAP=jans \
    JANS_CONFIG_KUBERNETES_USE_KUBE_CONFIG=false

# ==========
# Secret ENV
# ==========

ENV JANS_SECRET_ADAPTER=vault \
    JANS_SECRET_VAULT_SCHEME=http \
    JANS_SECRET_VAULT_HOST=localhost \
    JANS_SECRET_VAULT_PORT=8200 \
    JANS_SECRET_VAULT_VERIFY=false \
    JANS_SECRET_VAULT_ROLE_ID_FILE=/etc/certs/vault_role_id \
    JANS_SECRET_VAULT_SECRET_ID_FILE=/etc/certs/vault_secret_id \
    JANS_SECRET_VAULT_CERT_FILE=/etc/certs/vault_client.crt \
    JANS_SECRET_VAULT_KEY_FILE=/etc/certs/vault_client.key \
    JANS_SECRET_VAULT_CACERT_FILE=/etc/certs/vault_ca.crt \
    JANS_SECRET_VAULT_NAMESPACE=jans \
    JANS_SECRET_KUBERNETES_NAMESPACE=default \
    JANS_SECRET_KUBERNETES_SECRET=jans \
    JANS_SECRET_KUBERNETES_USE_KUBE_CONFIG=false

# ===============
# Persistence ENV
# ===============

ENV JANS_PERSISTENCE_TYPE=ldap \
    JANS_PERSISTENCE_LDAP_MAPPING=default \
    JANS_LDAP_URL=localhost:1636 \
    JANS_COUCHBASE_URL=localhost \
    JANS_COUCHBASE_USER=admin \
    JANS_COUCHBASE_CERT_FILE=/etc/certs/couchbase.crt \
    JANS_COUCHBASE_PASSWORD_FILE=/etc/jans/conf/couchbase_password \
    JANS_COUCHBASE_CONN_TIMEOUT=10000 \
    JANS_COUCHBASE_CONN_MAX_WAIT=20000 \
    JANS_COUCHBASE_SCAN_CONSISTENCY=not_bounded

# ===========
# Generic ENV
# ===========

ENV JANS_MAX_RAM_PERCENTAGE=75.0 \
    JANS_WAIT_MAX_TIME=300 \
    JANS_WAIT_SLEEP_DURATION=10 \
    PYTHON_HOME=/opt/jython \
    JANS_DOCUMENT_STORE_TYPE=LOCAL \
    JANS_JACKRABBIT_URL=http://localhost:8080 \
    JANS_JACKRABBIT_ADMIN_ID=admin \
    JANS_JACKRABBIT_ADMIN_PASSWORD_FILE=/etc/jans/conf/jackrabbit_admin_password \
    JANS_JAVA_OPTIONS="" \
    JANS_SSL_CERT_FROM_SECRETS=false \
    JANS_SYNC_JKS_ENABLED=false \
    JANS_SYNC_JKS_INTERVAL=30 \
    JANS_NAMESPACE=jans

# ==========
# misc stuff
# ==========

LABEL name="Janssen Authorization Server" \
    maintainer="Janssen Project <support@jans.io>" \
    vendor="Janssen Project" \
    version="5.0.0" \
    release="dev" \
    summary="Janssen Authorization Server" \
    description="OAuth 2.0 server and client; OpenID Connect Provider (OP) & UMA Authorization Server (AS)"

RUN mkdir -p /etc/certs /deploy \
    /opt/jans/python/libs \
    ${JETTY_BASE}/auth-server/custom/pages ${JETTY_BASE}/auth-server/custom/static \
    ${JETTY_BASE}/auth-server/custom/i18n \
    /etc/jans/conf \
    /app/templates

COPY libs /opt/jans/python/libs
COPY certs /etc/certs
COPY jetty/auth-server_web_resources.xml ${JETTY_BASE}/auth-server/webapps/
COPY jetty/auth-server.xml ${JETTY_BASE}/auth-server/webapps/
COPY conf/*.tmpl /app/templates/
COPY scripts /app/scripts
RUN chmod +x /app/scripts/entrypoint.sh

ENTRYPOINT ["tini", "-e", "143", "-g", "--"]
CMD ["sh", "/app/scripts/entrypoint.sh"]
