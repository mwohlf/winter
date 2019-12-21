

function docker_login() {
    msg "performing docker registry login at \"${DOCKER_REGISTRY}\""
    echo "${DOCKER_REGISTRY_PASS}" |
        docker login \
            -u "${DOCKER_REGISTRY_USER}" \
            --password-stdin \
            "${DOCKER_REGISTRY}"
}

#
# building a docker image
#
function docker_build() {
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
