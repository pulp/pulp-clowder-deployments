#!/bin/bash

export ACG_CONFIG="$(pwd)/cdappconfig.json"

set -ex

if [ -n "$NAMESPACE" ]; then
  oc project $NAMESPACE
else
  export NAMESPACE=$(oc project | grep -oE 'ephemeral-......')
fi
echo "NAMESPACE is $NAMESPACE"

PASSWORD=$(oc extract secret/cs-pulp-admin-password --to=-)

POD=$(oc get pod | grep -oE "content-sources-pulp-api\S*")
echo $POD
oc get pod $POD -o yaml | grep memory:

oc get clowdenvironment env-$(oc project | grep -oE 'ephemeral-......') -o yaml

oc get clowdapp content-sources-pulp -o yaml

### Adapted from ./.github/workflows/scripts/utils.sh
# Run a command
cmd_prefix() {
  oc exec "$POD" -- "$@"
}

# Run a command, and pass STDIN
cmd_stdin_prefix() {
  oc exec -i "$POD" -- "$@"
}
### END Adapted from ./.github/workflows/scripts/utils.sh

cmd_prefix bash -c "HOME=/tmp/home pip3 install pulp-rpm-client pulp-file-client pytest"

cmd_prefix mkdir -p /tmp/home/.config/pulp_smash
sed "s/password/${PASSWORD}/g" pulp-smash.json > pulp-smash.customized.json
sed -i "s/cs-pulp-content-svc/env-${NAMESPACE}.apps.c-rh-c-eph.8p0c.p1.openshiftapps.com/g" pulp-smash.customized.json

ORIG_DIR=$PWD
if [[ ! -e ../pulp_rpm ]]; then
  git clone --depth=1 https://github.com/pulp/pulp_rpm.git ../pulp_rpm
fi
cd ../pulp_rpm

### Adapted from ./.github/workflows/scripts/script.sh
cat unittest_requirements.txt | cmd_stdin_prefix bash -c "cat > /tmp/unittest_requirements.txt"
cat functest_requirements.txt | cmd_stdin_prefix bash -c "cat > /tmp/functest_requirements.txt"
cd $ORIG_DIR
cat pulp-smash.customized.json | cmd_stdin_prefix bash -c "cat > /tmp/home/.config/pulp_smash/settings.json"
cmd_prefix bash -c "HOME=/tmp/home pip3 install -r /tmp/unittest_requirements.txt -r /tmp/functest_requirements.txt"
# Because we pass the path to pytest -o cache_dir=/tmp/home/.cache/pytest_cache, pulpcore-manager must be in the same dir
cmd_prefix bash -c "ln -s /usr/local/bin/pulpcore-manager /tmp/home/.local/bin/pulpcore-manager || /bin/true"
# Only testing test_download_content because it is a very thorough test that tests that all the components of pulp can work
cmd_prefix bash -c "HOME=/tmp/home PYTHONPATH=/tmp/home/.local/lib/python3.8/site-packages/ XDG_CONFIG_HOME=/tmp/home/.config API_PROTOCOL=http API_HOST=cs-pulp-api-svc API_PORT=24817 ADMIN_USERNAME=admin ADMIN_PASSWORD=$PASSWORD /tmp/home/.local/bin/pytest -o cache_dir=/tmp/home/.cache/pytest_cache -v -r sx --color=yes --suppress-no-test-exit-code --pyargs pulp_rpm.tests.functional -m parallel -n 1 -k 'test_download_content'"
# Never test test_package_manager_consume because they require sudo
# Do not test test_domain_create because it requires more than 2GB of RAM
# Only testing test_download_policies because they are very thorough tests that test that all the components of pulp can work
cmd_prefix bash -c "HOME=/tmp/home PYTHONPATH=/tmp/home/.local/lib/python3.8/site-packages/ XDG_CONFIG_HOME=/tmp/home/.config API_PROTOCOL=http API_HOST=cs-pulp-api-svc API_PORT=24817 ADMIN_USERNAME=admin ADMIN_PASSWORD=$PASSWORD /tmp/home/.local/bin/pytest -o cache_dir=/tmp/home/.cache/pytest_cache -v -r sx --color=yes --pyargs pulp_rpm.tests.functional -m 'not parallel' -k 'test_download_policies'"
### END Adapted from ./.github/workflows/scripts/script.sh
