FROM ubuntu:22.04
MAINTAINER Dan Boitnott <boitnott@sigcorp.com>

ENV ROCKET_FILE_ROOT=/opt/swaf/repo/file_root \
    ROCKET_POLICY_STORE_ROOT=/opt/swaf/repo/policy \
    ROCKET_ADDRESS="0.0.0.0" \
    ROCKET_LIMITS={file="100MiB"} \
    ROCKET_LOG_LEVEL="debug"

COPY docker/default_policy/ ${ROCKET_POLICY_STORE_ROOT}/
COPY target/release/swaf /opt/swaf/swaf
COPY spa/public/ /opt/swaf/spa/public/
COPY docker/run.sh /run.sh

EXPOSE 8000

WORKDIR /opt/swaf
CMD /bin/bash /run.sh
