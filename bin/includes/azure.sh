################################ azure related stuff ######################

# login to azure and the docker registry
function login_azure() {
    msg "performing azure login as \"${AZURE_USER}\""
    az login \
        -u "${AZURE_USER}" \
        -p "${AZURE_PASS}" \
        1>"${DATA_DIR}/login.json"
}

#
# creates cluster and resource group in azure
#  this function uses az commands and should be the only place in this script to use it
#  because this is the only spot that is related directly to azure
#
function setup_azure() {
    msg "running ${FUNCNAME[0]} (this may take a while) ..."
    # az aks show --name apolloAKSCluster --resource-group apolloResourceGroup

    msg "  trying to find clientId in resourse group \"${RESOURCE_GROUP_NAME}\" and cluster \"${AZURE_CLUSTER_NAME}\""
    CLIENT_ID=$(az aks show --name "${AZURE_CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" 2>/dev/null |
        grep 'clientId' |
        sed '/.*\"\(.*\)\".*/s//\1/g')

    if [[ ${#CLIENT_ID} -gt 0 ]]; then
        msg "  cluster \"${AZURE_CLUSTER_NAME}\" in resource group \"${RESOURCE_GROUP_NAME}\" already exists, skipping creation, clientId is \"${CLIENT_ID}\""
        return
    fi

    msg "  clientId no found, creating resource group \"${RESOURCE_GROUP_NAME}\", location: \"${LOCATION}\""
    az group create \
        --name "${RESOURCE_GROUP_NAME}" \
        --location "${LOCATION}" \
        1>"${DATA_DIR}/resource_group.json"

    msg "  creating cluster \"${AZURE_CLUSTER_NAME}\", node count: \"${NODE_COUNT}\""
    az aks create \
        --resource-group "${RESOURCE_GROUP_NAME}" \
        --name "${AZURE_CLUSTER_NAME}" \
        --node-count "${NODE_COUNT}" \
        --generate-ssh-keys \
        1>"${DATA_DIR}/cluster.json"

    #   --enable-addons http_application_routing \
    #   --enable-addons monitoring \

    # connect kubectl to the cluster
    msg "  fetching credentials for \"${RESOURCE_GROUP_NAME}\", cluster: \"${AZURE_CLUSTER_NAME}\""
    az aks get-credentials \
        --resource-group "${RESOURCE_GROUP_NAME}" \
        --name "${AZURE_CLUSTER_NAME}" \
        --overwrite-existing \
        1>"${DATA_DIR}/credentials.json"

    # create a public ip prefix
    #az network public-ip create \
    #   --name apolloPublicIp \
    #   --resource-group ${RESOURCE_GROUP_NAME} \
    #   --location ${LOCATION} \
    #   --allocation-method dynamic

    CLIENT_ID=$(az aks show --name ${AZURE_CLUSTER_NAME} --resource-group ${RESOURCE_GROUP_NAME} 2>/dev/null |
        grep 'clientId' |
        sed '/.*\"\(.*\)\".*/s//\1/g')

    if [[ ${#CLIENT_ID} -eq 0 ]]; then
        fail "  clientId no found at the end of resource creation, something went wrong "
    fi

    msg "...done ${FUNCNAME[0]}, clientId is \"${CLIENT_ID}\""
}

# start the dashboard and open the browser to view
function setup_azure_dashboard() {
    msg "running ${FUNCNAME[0]}"
    # add clusterrolebinding for viewing dashboard
    local CLUSTERROLEBINDING_DASHBOARD
    CLUSTERROLEBINDING_DASHBOARD="$({ kubectl -n kube-system get clusterrolebinding | grep '^kubernetes-dashboard '; } || true)"
    if [[ ${#CLUSTERROLEBINDING_DASHBOARD} -eq 0 ]]; then
        kubectl create clusterrolebinding kubernetes-dashboard \
            --clusterrole=cluster-admin \
            --serviceaccount=kube-system:kubernetes-dashboard
    fi

    # show the dashboard in browser
    az aks browse \
        --resource-group "${RESOURCE_GROUP_NAME}" \
        --name "${AZURE_CLUSTER_NAME}" &
}

# this includes disposal of the cluster
function dispose_azure() {
    msg "running ${FUNCNAME[0]} ..."

    msg "  deleting resource group \"${RESOURCE_GROUP_NAME}\""
    az group delete \
        --name "${RESOURCE_GROUP_NAME}" \
        --yes || true
    # also unset the context in kubectl
    kubectl config unset current-context
    msg "...done running ${FUNCNAME[0]}"
}
