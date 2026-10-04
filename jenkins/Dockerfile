FROM jenkins/jenkins:lts-jdk21

COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:cli /usr/local/libexec/docker/cli-plugins \
     /usr/local/libexec/docker/cli-plugins

USER root