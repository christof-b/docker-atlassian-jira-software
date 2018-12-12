FROM openjdk:8-alpine

# Configuration variables.
ENV JIRA_HOME     /var/atlassian/jira
ENV JIRA_INSTALL  /opt/atlassian/jira
ENV JIRA_VERSION  7.13.0

ENV TZ			  CET-2CEDT-2
	
# Set TimeZone, install Atlassian JIRA and helper tools and setup initial home
# directory structure.
RUN set -x \
	&& echo ${TZ} > /etc/TZ \
	&& apk update \
    && apk add --no-cache curl xmlstarlet bash ttf-dejavu libc6-compat apr-util apr-dev openssl openssl-dev gcc musl-dev make \
	&& mkdir -p                "${JIRA_HOME}" \
    && mkdir -p                "${JIRA_HOME}/caches/indexes" \
    && mkdir -p                "${JIRA_INSTALL}/conf/Catalina" \
    && curl -Ls                "https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-${JIRA_VERSION}.tar.gz" | tar -xz --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.45.tar.gz" | tar -xz --directory "${JIRA_INSTALL}/lib" --strip-components=1 --no-same-owner "mysql-connector-java-5.1.45/mysql-connector-java-5.1.45-bin.jar" \
    && rm -f                   "${JIRA_INSTALL}/lib/postgresql-9.1-903.jdbc4-atlassian-hosted.jar" \
    && curl -Ls                "https://jdbc.postgresql.org/download/postgresql-42.2.1.jar" -o "${JIRA_INSTALL}/lib/postgresql-42.2.1.jar" \
    && sed --in-place          "s/java version/openjdk version/g" "${JIRA_INSTALL}/bin/check-java.sh" \
    && sed --in-place          "s;jira.home =;jira.home = ${JIRA_HOME};g" "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties" \
    && touch -d "@0"           "${JIRA_INSTALL}/conf/server.xml" \
    && tar -xzvf ${JIRA_INSTALL}/bin/tomcat-native.tar.gz -C /tmp \
    && cd /tmp/tomcat-native-1.2.17-src/native && ./configure --with-apr=/usr/bin/apr-1-config --with-java-home=/usr/lib/jvm/java-1.8-openjdk --with-ssl=yes --prefix=/usr && make && make install \
    && rm -r -f /tmp/tomcat-native-1.2.17-src \
    && apk del apr-dev openssl-dev gcc musl-dev make

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
RUN set -x \
	&& adduser -D -G root -g "ROS User" rosuser \
    && chmod -R 770	          "${JIRA_HOME}" \
    && chown -R rosuser:root  "${JIRA_HOME}" \
    && chmod -R 770            "${JIRA_INSTALL}/conf" \
    && chmod -R 770            "${JIRA_INSTALL}/logs" \
    && chmod -R 770            "${JIRA_INSTALL}/temp" \
    && chmod -R 770            "${JIRA_INSTALL}/work" \
    && chown -R rosuser:root  "${JIRA_INSTALL}/conf" \
    && chown -R rosuser:root  "${JIRA_INSTALL}/logs" \
    && chown -R rosuser:root  "${JIRA_INSTALL}/temp" \
    && chown -R rosuser:root  "${JIRA_INSTALL}/work"

USER rosuser

# Expose default HTTP connector port.
EXPOSE 8080

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs. Index folder should be mounted manually, because of issues with NFS.
VOLUME ["/var/atlassian/jira", "/opt/atlassian/jira/logs"]

# Set the default working directory as the installation directory.
WORKDIR /var/atlassian/jira

COPY "docker-entrypoint.sh" "/"
ENTRYPOINT ["/docker-entrypoint.sh"]

# Run Atlassian JIRA as a foreground process by default.
CMD ["/opt/atlassian/jira/bin/start-jira.sh", "-fg"]
