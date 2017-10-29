# docker 17.05+ is required for multistage build

FROM maven:alpine as build
RUN mkdir /build 
COPY /keycloak /build/keycloak/
COPY /keycloak-docker /build/keycloa-docker/
COPY /.m2 /build/.m2/
WORKDIR /build/keycloak
RUN mvn clean install -s /build/.m2/settings.xml -DskipTests -Pdistribution
RUN ls -la /build/keycloak/distribution/server-dist/target/keycloak-3.3.1.Final-SNAPSHOT.tar.gz


FROM jboss/base-jdk:8
LABEL maintainer "Benjamin Boortz <benjamin.boortz@secure.mailbox.org>"

ENV KEYCLOAK_VERSION 3.3.1.Final-SNAPSHOT
# Enables signals getting passed from startup script to JVM
# ensuring clean shutdown when container is stopped.
ENV LAUNCH_JBOSS_IN_BACKGROUND 1
ENV PROXY_ADDRESS_FORWARDING false
USER root

RUN yum install -y epel-release && yum install -y jq && yum clean all

USER jboss

COPY --from=build /build/keycloak/distribution/server-dist/target/keycloak-$KEYCLOAK_VERSION.tar.gz /opt/jboss
RUN cd /opt/jboss/ && ls -la && tar zxf keycloak-${KEYCLOAK_VERSION}.tar.gz && mv /opt/jboss/keycloak-${KEYCLOAK_VERSION} /opt/jboss/keycloak

ADD keycloak-docker/server/docker-entrypoint.sh /opt/jboss/

ADD keycloak-docker/server/cli /opt/jboss/keycloak/cli
RUN cd /opt/jboss/keycloak && bin/jboss-cli.sh --file=cli/standalone-configuration.cli && rm -rf /opt/jboss/keycloak/standalone/configuration/standalone_xml_history
RUN cd /opt/jboss/keycloak && bin/jboss-cli.sh --file=cli/standalone-ha-configuration.cli && rm -rf /opt/jboss/keycloak/standalone-ha/configuration/standalone_xml_history

ENV DB_VENDOR POSTGRES 
ENV JDBC_POSTGRES_VERSION 42.1.4

ADD keycloak-docker/server/databases/change-database.sh /opt/jboss/keycloak/bin/change-database.sh

RUN mkdir -p /opt/jboss/keycloak/modules/system/layers/base/org/postgresql/jdbc/main; cd /opt/jboss/keycloak/modules/system/layers/base/org/postgresql/jdbc/main; curl -L http://central.maven.org/maven2/org/postgresql/postgresql/${JDBC_POSTGRES_VERSION}/postgresql-${JDBC_POSTGRES_VERSION}.jar > postgres-jdbc.jar
ADD keycloak-docker/server/databases/postgres/module.xml /opt/jboss/keycloak/modules/system/layers/base/org/postgresql/jdbc/main

RUN rm -rf /opt/jboss/keycloak/standalone/configuration/standalone_xml_history
RUN rm -rf /opt/jboss/keycloak/standalone_ha/configuration/standalone_xml_history

ENV JBOSS_HOME /opt/jboss/keycloak

EXPOSE 8080

ENTRYPOINT [ "/opt/jboss/docker-entrypoint.sh" ]

CMD ["-b", "0.0.0.0", "--server-config", "standalone-ha.xml"]




