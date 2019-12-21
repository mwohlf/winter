
# used in the caller to execute the helm command from the map for the setup values in the keys
# shellcheck disable=SC2034
HELM_SETUPS=( \
  ["ingress"]="helm install ingress stable/nginx-ingress"\
  ["postgres"]="helm install postgres stable/postgresql"\
)

#  setup helm
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
