FROM ubuntu:22.04
MAINTAINER Dan Boitnott <boitnott@sigcorp.com>

ENV ROCKET_FILE_ROOT=/swaf/data/file_root \
    ROCKET_POLICY_STORE_ROOT=/swaf/data/policy \
    ROCKET_HOOK_ROOT=/swaf/data/hooks \
    ROCKET_ADDRESS="0.0.0.0" \
    ROCKET_LIMITS={file="100MiB"} \
    ROCKET_LOG_LEVEL="debug" \
    ROCKET_HOOK_SHELL="bash"

COPY docker/default_policy/ ${ROCKET_POLICY_STORE_ROOT}/
COPY target/release/swaf /swaf/swaf
COPY spa/public/ /swaf/spa/public/
COPY docker/run.sh /run.sh

EXPOSE 8000

WORKDIR /swaf
CMD /bin/bash /run.sh
