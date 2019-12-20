################################ minikube related stuff ######################

# see: https://www.howtoforge.com/learning-kubernetes-locally-via-minikube-on-linux-manjaro-archlinux/
function setup_minikube() {
    msg "running ${FUNCNAME[0]} (this may take a while) ..."
    minikube start --vm-driver kvm2
    msg "...done running ${FUNCNAME[0]}"
}

# start dashboard and open browser
function setup_minikube_dashboard() {
    msg "running ${FUNCNAME[0]}"
    minikube dashboard &
}

# this includes disposal of the docker images and complete reset
function dispose_minikube() {
    msg "running ${FUNCNAME[0]} ..."
    minikube stop
    minikube delete
    rm -rf ~/.minikube
    sudo systemctl restart libvirtd.service
    sudo systemctl restart virtlogd.service
    msg "...done running ${FUNCNAME[0]}"
}
