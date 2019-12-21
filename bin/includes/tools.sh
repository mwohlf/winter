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
    fail "usage: ${SCRIPT_NAME} [dispose|setup|refresh] [minikube|azure|dashboard|postgres]]}"
}

# set KUBECTL_CONTEXT variable initialized in the main script
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
