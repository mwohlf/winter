#!/usr/bin/env bash

# script for setting up a k8s cluster in azure
#  you need python-azure-cli on archlinux for the az commands
#
#
#  !!! this script contains usernames and passwords !!!
#
# references:
#    https://docs.bitnami.com/kubernetes/how-to/secure-kubernetes-services-with-ingress-tls-letsencrypt/
#    https://akomljen.com/get-automatic-https-with-lets-encrypt-and-kubernetes-ingress/
#    https://akomljen.com/package-kubernetes-applications-with-helm/
#    https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html
#
#
#

# cloud properties
RESOURCE_GROUP_NAME="apolloResourceGroup"
CLUSTER_NAME="apolloAKSCluster"
NODE_COUNT="2"
LOCATION="westeurope"

# script specific parameter
DATA_DIR="/tmp/azure_data"
LOCK_DIR="${DATA_DIR}/.lock.d"
PID_FILE="${LOCK_DIR}/pid"
SCRIPT_DIR="$(dirname "$0")"
CONFIG_DIR="${SCRIPT_DIR}/config"

# reading the logins and passwords
# shellcheck source=./secrets.sh
source "${SCRIPT_DIR}/secrets.sh"


# kubectl_create environment
mkdir -p ${DATA_DIR}



# for showing colored messages
function msg() {
  # terminal colors
  # red=$(tput setaf 1)
  green=$(tput setaf 2)
  reset=$(tput sgr0)
  echo "${green}${1}${reset}"
}

# to avoid concurrent runs of this script messing things up
function create_lock () {
  if ( mkdir ${LOCK_DIR} ) 2> /dev/null; then
    echo $$ > ${PID_FILE}
    # remove everything on normal exit
    trap 'rm -rf "${LOCK_DIR}"; exit $?' INT TERM EXIT
    msg "storing data in ${DATA_DIR}, added hook for removal on normal exit."
  else
    msg "lock exists: ${LOCK_DIR} owned by pid $(cat ${PID_FILE}), remove the lock if you want to run this script."
    exit 1
  fi
}

# login to azure and the docker registry
function login_azure {
  msg "performing azure login"
  az login \
     -u "${AZURE_USER}" \
     -p "${AZURE_PASS}" \
  1> "${DATA_DIR}/login.json"
}

function login_docker {
  msg "performing docker registry login at ${DOCKER_REGISTRY}"
  echo "${DOCKER_REGISTRY_PASS}" |
  docker login \
    -u "${DOCKER_REGISTRY_USER}" \
    --password-stdin \
    "${DOCKER_REGISTRY}"
}

# creates cluster and resource group
function setup_resource_group_and_cluster {
  msg "running setup_resource_group (this may take a while) ..."
  # az aks show --name apolloAKSCluster --resource-group apolloResourceGroup

  msg "  trying to find clientId in resourse group ${RESOURCE_GROUP_NAME} and cluster ${CLUSTER_NAME}"
  CLIENT_ID=$(az aks show --name ${CLUSTER_NAME} --resource-group ${RESOURCE_GROUP_NAME} 2> /dev/null |
      grep 'clientId' |
      sed '/.*\"\(.*\)\".*/s//\1/g')

  if [[ ${#CLIENT_ID} -gt 0 ]]; then
      msg "  cluster ${CLUSTER_NAME} in resource group ${RESOURCE_GROUP_NAME} already exists, skipping creation, clientId is '${CLIENT_ID}'"
      return
  fi

  msg "  creating resource group ${RESOURCE_GROUP_NAME}, location: ${LOCATION}"
  az group create \
     --name ${RESOURCE_GROUP_NAME} \
     --location ${LOCATION} \
  1> "${DATA_DIR}/resource_group.json"

  msg "  creating cluster ${CLUSTER_NAME}, node count: ${NODE_COUNT}"
  az aks create \
     --resource-group ${RESOURCE_GROUP_NAME} \
     --name ${CLUSTER_NAME} \
     --node-count ${NODE_COUNT} \
     --generate-ssh-keys \
  1> "${DATA_DIR}/cluster.json"

  #   --enable-addons http_application_routing \
  #   --enable-addons monitoring \

  # connect kubectl to the cluster
  msg "  fetching credentials for ${RESOURCE_GROUP_NAME}, cluster: ${CLUSTER_NAME}"
  az aks get-credentials \
     --resource-group ${RESOURCE_GROUP_NAME} \
     --name ${CLUSTER_NAME} \
     --overwrite-existing \
  1> "${DATA_DIR}/credentials.json"

  # create a public ip prefix
  #az network public-ip create \
  #   --name apolloPublicIp \
  #   --resource-group ${RESOURCE_GROUP_NAME} \
  #   --location ${LOCATION} \
  #   --allocation-method dynamic

  msg "...done setup_resource_group"
}

function setup_tiller_and_helm {
  msg "  checking for tiller serviceaccounts"
  TILLER_ACCOUNT=$(kubectl -n kube-system get serviceaccounts | grep '^tiller ')
  if [[ ${#TILLER_ACCOUNT} -gt 0 ]]; then
      msg "  tiller account found, helm should be initialized already"
      return
  fi
  msg "  no tiller account found, setup tiller and helm"

  kubectl -n kube-system create serviceaccount tiller

  kubectl create clusterrolebinding tiller \
     --clusterrole=cluster-admin \
     --serviceaccount=kube-system:tiller

  # this also deploys a tiller image to the cluster
  helm init --service-account tiller

  # Add the Jetstack Helm repository for cert manager
  helm repo add jetstack https://charts.jetstack.io

  # Update your local Helm chart repository cache
  helm repo update

  # Wait for tiller pod to get ready
  kubectl -n kube-system wait --for=condition=Ready pod -l name=tiller --timeout=300s
  msg "  finished tiller and helm setup"
}


function setup_ingress {
  msg "  setup ingress with helm..."
  helm install --name ingress stable/nginx-ingress
  msg "  ...setup ingress done."
}

function setup_certmanager {
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


function access_dashboard {
  msg "...accessing dashboard"
  # add clusterrolebinding for viewing dashboard

  CLUSTERROLEBINDING_DASHBOARD=$(kubectl -n kube-system get clusterrolebinding | grep '^kubernetes-dashboard ')
  if [[ ${#CLUSTERROLEBINDING_DASHBOARD} -eq 0 ]]; then
    kubectl create clusterrolebinding kubernetes-dashboard \
        --clusterrole=cluster-admin \
        --serviceaccount=kube-system:kubernetes-dashboard
  fi

  # show the dashboard in browser
  az aks browse \
     --resource-group ${RESOURCE_GROUP_NAME} \
     --name ${CLUSTER_NAME} &
}

function teardown_resource_group {
  msg "running teardown_resource_group..."

  msg "  deleting resource group ${RESOURCE_GROUP_NAME}"
  az group delete \
     --name ${RESOURCE_GROUP_NAME} \
     --yes
  msg "...done teardown_resource_group"
}

#
# building a docker image
#
function build {
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
function kubectl_create {
  SETUP_FILE="${DATA_DIR}/${1}.kubectl_create"
  if [[ -f "${SETUP_FILE}" ]]; then
    msg "  ${SETUP_FILE} exist, skipping kubectl_create of ${1}, kubectl_create file exists at ${SETUP_FILE}"
    return
  fi
  kubectl create -f "${CONFIG_DIR}/${1}.yml"
  touch "${SETUP_FILE}"
}

function usage {
  msg "usage: $0 [setup [env]|teardown]"
  exit 1
}

if [[ $# -eq 0 ]];
    then usage
fi



function setup {
  case ${1} in
    env)
      setup_resource_group_and_cluster
      ;;
    *)
      echo "unknown setup parameter ${1}"
      usage
      ;;
  esac
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


while true; do
case ${1} in
  setup)
    login_azure
    setup "${2}"
    exit 0
    ;;
  teardown)
    login_azure
    teardown_resource_group
    rm -rf "${DATA_DIR}"
    exit 0
    ;;
  *)
    # unknown option
    echo "unknown option ${1}"
    usage
    exit 0
    ;;
esac
done

