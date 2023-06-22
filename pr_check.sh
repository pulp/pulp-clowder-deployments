#!/bin/bash

# --------------------------------------------
# Options that must be configured by app owner
# --------------------------------------------
APP_NAME="content-sources"  # name of app-sre "application" folder this component lives in
COMPONENT_NAME="content-sources-pulp"  # name of app-sre "resourceTemplate" in deploy.yaml for this component
IMAGE="quay.io/cloudservices/pulp-rpm-ubi"

IQE_PLUGINS="content-sources"
IQE_MARKER_EXPRESSION="api"
IQE_FILTER_EXPRESSION=""
IQE_CJI_TIMEOUT="30m"

EXTRA_DEPLOY_ARGS="advisor"

# Install bonfire repo/initialize
CICD_URL=https://raw.githubusercontent.com/RedHatInsights/bonfire/master/cicd
curl -s $CICD_URL/bootstrap.sh > .cicd_bootstrap.sh && source .cicd_bootstrap.sh

source $CICD_ROOT/build.sh
source $APP_ROOT/unit_test.sh
source $CICD_ROOT/deploy_ephemeral_env.sh
echo "Stopping so you can SSH."
read foo
source $CICD_ROOT/cji_smoke_test.sh
source $CICD_ROOT/post_test_results.sh
