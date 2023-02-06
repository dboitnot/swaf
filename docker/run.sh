#!/usr/bin/env sh

if [ -z "$ROCKET_SECRET_KEY" ]; then
    cat <<'EOF'
-- WARNING ---------------------------------------------------------------------
ROCKET_SECRET_KEY is not set. Generating a random value.

THIS WILL NOT WORK FOR MULTI-INSTANCE DEPLOYMENTS

Use the following command to generate an appropriate value:

$ openssl rand -base64 32
--------------------------------------------------------------------------------
EOF
    export ROCKET_SECRET_KEY="$(dd if=/dev/random bs=1024 count=1 2>/dev/null |sha256sum |cut -c -64)"
fi

mkdir -p "$ROCKET_FILE_ROOT"

cd /swaf
./swaf
