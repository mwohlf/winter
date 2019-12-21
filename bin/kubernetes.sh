#!/usr/bin/env bash

# script for setting up a k8s cluster in azure, minikube, ...
#  you need python-azure-cli on archlinux for the az commands
#
#
# syntax:
#  kubernetes.sk [setup|dispose] [azure|minikube]
#
# references:
#    https://docs.bitnami.com/kubernetes/how-to/secure-kubernetes-services-with-ingress-tls-letsencrypt/
#    https://akomljen.com/get-automatic-https-with-lets-encrypt-and-kubernetes-ingress/
#    https://akomljen.com/package-kubernetes-applications-with-helm/
#    https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html
#
#
# disable check for unused variables, because they are used in includes
#   shellcheck disable=SC2034
# disable checks for unresolvable includes
#   shellcheck disable=SC1090

# terminate as soon as any command fails
set -o errexit
# don't allow uninitialized variables
set -o nounset
# there seems to be a font issue on arch linux and minikube or chromium
export FONTCONFIG_PATH=/etc/fonts

# azure cloud properties
RESOURCE_GROUP_NAME="apolloResourceGroup"
AZURE_CLUSTER_NAME="apolloAKSCluster"
NODE_COUNT="2"
LOCATION="westeurope"

# use the full canonical path for the home dir of the script
SCRIPT_DIR="$(dirname "${0}")"
SCRIPT_DIR="$(readlink -f "${SCRIPT_DIR}")"

# chart dir must be relative to the script
HELM_CHART_DIR="$(readlink -f "${SCRIPT_DIR}/../etc/helm-charts")"
INCLUDE_DIR="${SCRIPT_DIR}/includes"
SCRIPT_NAME="$(basename "${0}")"
DATA_DIR="/tmp/${SCRIPT_NAME}_data"
LOCK_DIR="${DATA_DIR}/.lock.d"
PID_FILE="${LOCK_DIR}/pid"
CONFIG_DIR="${SCRIPT_DIR}/config"

# will be set up in one of the includes
declare KUBECTL_CONTEXT="" # only two possible names: minikube | azure
declare -A HELM_SETUPS

# includes for passwords
source "${INCLUDE_DIR}/secrets.sh"

# includes utility functions
source "${INCLUDE_DIR}/tools.sh"
source "${INCLUDE_DIR}/helm.sh"
source "${INCLUDE_DIR}/misc.sh"

# includes for different platforms
source "${INCLUDE_DIR}/azure.sh"
source "${INCLUDE_DIR}/minikube.sh"

# create storage for temp and debug data
mkdir -p "${DATA_DIR}"

#########
#
# setup resources, and configure kubectl to use them
#
function setup() {
    local ARG
    # if we have no parameters or just a single empty one
    # see: https://unix.stackexchange.com/questions/290146/multiple-logical-operators-a-b-c-and-syntax-error-near-unexpected-t
    if { [ ${#} -eq 0 ]; } || { [ ${#} -eq 1 ] && [ -z "${1}" ]; }; then
        ARGS+=("minikube")
        ARGS+=("helm")
        ARGS+=("postgres")
        ARGS+=("dashboard")
    else
        ARGS=("${@}")
    fi
    msg "running setup for ${ARGS[*]}"
    for ARG in "${ARGS[@]}"; do
        case ${ARG} in
        azure)
            login_azure
            setup_azure
            ;;
        minikube)
            setup_minikube
            ;;
        helm)
            setup_"${ARG}"
            ;;
        ingress | postgres)
            ${HELM_SETUPS["${ARG}"]}
            ;;
        dashboard)
            # dashboard is set up differently depending on the context
            find_kubectl_context
            "setup_${KUBECTL_CONTEXT}_${ARG}"
            ;;
        *)
            fail "unknown setup argument ${ARG}"
            ;;
        esac
    done
}

#########
#
# dispose resources, defaults to the current kubectl context plus the datadir
#
function dispose() {
    local ARGS
    # if we have no parameters or just a single empty one
    # see: https://unix.stackexchange.com/questions/290146/multiple-logical-operators-a-b-c-and-syntax-error-near-unexpected-t
    if { [ ${#} -eq 0 ]; } || { [ ${#} -eq 1 ] && [ -z "${1}" ]; }; then
        # assuming we want to dispose everything if we get no or a single empty parameter
        ARGS="$({ kubectl config current-context || true; } 2>&1)" # might return "error: current-context is not set"
        ARGS+=("datadir")
    else
        ARGS=("${@}")
    fi
    for ARG in "${ARGS[@]}"; do
        case ${ARG} in
        error:\ *)
            fail "no current context in kubectl found, please specify what you want to dispose {\"azure\",\"minikube\",\"datadir\"}"
            ;;
        azure | "${AZURE_CLUSTER_NAME}")
            login_azure
            dispose_azure
            ;;
        minikube)
            dispose_minikube
            ;;
        datadir)
            msg "removing ${DATA_DIR}"
            rm -rf "${DATA_DIR}"
            ;;
        *)
            fail "unknown dispose argument \"${ARG}\", use one of {\"azure\",\"minikube\",\"datadir\"}"
            ;;
        esac
    done
}

#### main ####
#
#  to get the whole config:
#   kubectl get deploy,po,svc -n development
#
#  to access a service
#   kubectl port-forward deployment/hello-world 7000:8080 -n development
#   kubectl port-forward service/hello-world 7000:8080 -n development
#

create_lock

# we need at least one argument [setup|dispose]
if [[ $# -eq 0 ]]; then
    usage
fi

case ${1} in
setup)
    shift
    setup "${@}"
    ;;
dispose)
    shift
    dispose "${1:-}"
    ;;
*)
    # unknown option
    echo "unknown option ${1}"
    usage
    exit 0
    ;;
esac
