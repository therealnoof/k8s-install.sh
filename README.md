This script will install k8s as a single node cluster on a Ubuntu box.
Git clone the script and then make sure to chmod +x k8s-install.sh to make the script executable.

When installing on a Ubuntu hypervisor you may be prompted for kernel upgrades during the install process. 
Just hit enter to continue and the install will continue.

You may need to run this command if you cannot interact with the kube API

export KUBECONFIG=/etc/kubernetes/admin.conf

Need to clone this repo in the k8s-nginx-install dir on the box: https://github.com/nginx/kubernetes-ingress.git
