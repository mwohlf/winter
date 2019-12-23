#!/usr/bin/env bash
#
# this script must be located in the keycloak bin directory
# together with add-user-keycloak.sh and standalone.sh
#
#

BIN_DIR=`dirname "$0"`

if [ $KEYCLOAK_USER ] && [ $KEYCLOAK_PASSWORD ]; then
    ${BIN_DIR}/add-user-keycloak.sh -u $KEYCLOAK_USER -p $KEYCLOAK_PASSWORD >/dev/null
fi

exec ${BIN_DIR}/standalone.sh $@
exit $?

