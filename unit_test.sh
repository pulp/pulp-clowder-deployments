#!/bin/bash

# Dummy script for now until we get closer to production

# Upstream Pulp and plugins have their own tests, so does pulp-operator.git

export ACG_CONFIG="$(pwd)/cdappconfig.json"

cat /etc/redhat-release

sudo dnf -y install jq

/bin/true

if [ $? != 0 ]; then
    exit 1
fi
