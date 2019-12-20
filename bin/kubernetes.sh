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
#

# terminate as soon as any command fails
set -o errexit
# don't allow uninitialized variables
set -o nounset

# azure cloud properties
RESOURCE_GROUP_NAME="apolloResourceGroup"
AZURE_CLUSTER_NAME="apolloAKSCluster"
NODE_COUNT="2"
LOCATION="westeurope"

# script specific parameter
SCRIPT_DIR="$(dirname "${0}")"
# use the full canonical path
SCRIPT_DIR="$(readlink -f "${SCRIPT_DIR}")"
INCLUDE_DIR="${SCRIPT_DIR}/includes"
SCRIPT_NAME="$(basename "${0}")"
DATA_DIR="/tmp/${SCRIPT_NAME}_data"
LOCK_DIR="${DATA_DIR}/.lock.d"
PID_FILE="${LOCK_DIR}/pid"
CONFIG_DIR="${SCRIPT_DIR}/config"

# includes for passwords
source "${INCLUDE_DIR}/secrets.sh"
# includes for different platforms
source "${INCLUDE_DIR}/azure.sh"
source "${INCLUDE_DIR}/minikube.sh"

# will be set up later
KUBECTL_CONTEXT=""  # only two possible names: minikube | azure

# create storage for temp and debug data
mkdir -p "${DATA_DIR}"

################################ some helper functions to make things easier ######################

# for showing colored messages
function msg() {
    green=$(tput setaf 2)
    reset=$(tput sgr0)
    echo "${green}${1}${reset}"
}

# print error and exit
function fail() {
    red=$(tput setaf 1)
    reset=$(tput sgr0)
    echo "${red}${1}${reset}"
    exit "${2:-1}" # default to 'exit 1'
}

# to avoid concurrent runs of this script messing things up
function create_lock() {
    if (mkdir "${LOCK_DIR}") 2>/dev/null; then
        echo $$ >"${PID_FILE}"
        # remove everything on normal exit
        trap 'rm -rf "${LOCK_DIR}"; exit $?' INT TERM EXIT
        # msg "storing data in ${DATA_DIR}, added hook for directory removal on normal exit."
    else
        fail "lock exists: ${LOCK_DIR} owned by pid $(cat "${PID_FILE}"), remove the lock if you want to run this script."
    fi
}

# print usage and exit
function print_usage() {
    fail "usage: ${SCRIPT_NAME} [dispose | setup [minikube|azure|dashboard]]}"
}

# set KUBECTL_CONTEXT variable
function find_kubectl_context() {
    KUBECTL_CONTEXT="$({ kubectl config current-context || true; } 2>&1)"
    case ${KUBECTL_CONTEXT} in
    minikube)
        KUBECTL_CONTEXT="minikube"
        ;;
    "${AZURE_CLUSTER_NAME}")
        KUBECTL_CONTEXT="azure"
        ;;
    *)
        fail "unknown kubectl context found: \"${KUBECTL_CONTEXT}\" "
        ;;
    esac
}

################################ logins to services and repos ######################


function login_docker() {
    msg "performing docker registry login at \"${DOCKER_REGISTRY}\""
    echo "${DOCKER_REGISTRY_PASS}" |
        docker login \
            -u "${DOCKER_REGISTRY_USER}" \
            --password-stdin \
            "${DOCKER_REGISTRY}"
}



################################ k8s, helm stuff ######################

#
#  setup helm
#
function setup_helm() {
    msg "running ${FUNCNAME[0]}"
    # not sure this is needed
    rm -rf ~/.helm
    helm init
    # Add the Jetstack Helm repository for cert manager
    helm repo add jetstack https://charts.jetstack.io
    helm repo add stable https://kubernetes-charts.storage.googleapis.com/
    # helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
    # Update local Helm chart repository cache
    helm repo update
}


function setup_ingress() {
    msg "  setup ingress with helm..."
    helm install ingress stable/nginx-ingress
    msg "  ...setup ingress done."
}

function setup_certmanager() {
    msg "  setup cert manager with helm..."
    # see: https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html
    #      https://docs.cert-manager.io/en/latest/
    #      https://cert-manager.readthedocs.io/en/latest/reference/issuers.html
    #      https://cert-manager.readthedocs.io/en/latest/reference/ingress-shim.html
    # - the namespace cert-manager should already be created
    # - the helm chart repo https://charts.jetstack.io shuld be added to helm
    #   like this: kubectl create namespace cert-manager

    # Install the cert-manager Helm chart
    helm install \
        --name cert-manager \
        --namespace cert-manager \
        --set webhook.enabled=false \
        stable/cert-manager

    msg "  ...setup cert manager done."

}

#
# building a docker image
#
function build() {
    msg "...running build for ${1}"
    pushd "${CONFIG_DIR}/${1}" || return
    npm i
    # in gitlab see: Packages > Container Registry
    IMAGE_PATH="${DOCKER_REGISTRY}/${DOCKER_REGISTRY_USER}/apollo/${1}"
    docker build -t "${IMAGE_PATH}:latest" .
    docker push "${IMAGE_PATH}"
    popd || exit 1
}

#
# running a kubernetes create
#  see: https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/
#       about how to access
#  e.g. kubectl port-forward deployment/hello-world 7000:8080
#
function kubectl_create() {
    SETUP_FILE="${DATA_DIR}/${1}.kubectl_create"
    if [[ -f "${SETUP_FILE}" ]]; then
        msg "  ${SETUP_FILE} exist, skipping kubectl_create of ${1}, kubectl_create file exists at ${SETUP_FILE}"
        return
    fi
    kubectl create -f "${CONFIG_DIR}/${1}.yml"
    touch "${SETUP_FILE}"
}

################################ main ############################

#########
#
# setup resources, and configure kubectl to use them
#
function setup() {
    if [ ${#} -ne 1 ]; then
        fail "empty setup argument ${1}"
    fi
    case ${1} in
    azure)
        login_azure
        setup_azure
        ;;
    minikube)
        setup_minikube
        ;;
    helm | ingress)
        setup_"${1}"
        ;;
    dashboard)
        # dashboard is set up differently depending on the context
        find_kubectl_context
        "setup_${KUBECTL_CONTEXT}_${1}"
        ;;
    *)
        fail "unknown setup argument ${1}"
        ;;
    esac
}

#########
#
# dispose resources, defaults to the current kubectl context plus the datadir
#
function dispose() {
    local ARGS
    if [ ${#} -eq 0 ] || [ ${#} -eq 1 ] && [ -z "${1}" ]; then
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

# we need at least one argument
if [[ $# -eq 0 ]]; then
    usage
fi

while [ ${#} -ge 1 ]; do
    case ${1} in
    setup)
        shift
        setup "${1}"
        shift
        ;;
    dispose)
        shift
        dispose "${1:-}"
        shift
        ;;
    *)
        # unknown option
        echo "unknown option ${1}"
        usage
        exit 0
        ;;
    esac
done
