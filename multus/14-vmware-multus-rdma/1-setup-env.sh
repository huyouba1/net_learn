#!/bin/bash
date
set -v

# 1.prep noCNI env
alias addk3s
addk3s
# alias addk3s='rm -rf /usr/local/bin/k3s/ ; wget http://192.168.2.100/http/k3s -P /usr/local/bin/ && chmod +x /usr/local/bin/k3s && INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC='\''--docker --flannel-backend=none --disable=traefik --disable=servicelb'\'' /root/wcni-kind/LabasCode/k8senv/vmenv/k3senv/k3s-install.sh && export KUBECONFIG=/etc/rancher/k3s/k3s.yaml'

# 2.remove taints
controller_node_ip=`kubectl get node -o wide --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/control-plane:NoSchedule-
kubectl get nodes -o wide


# for i in $(docker ps --format '{{.Names}}'| grep cni-multus- | grep -v clab);do docker exec -it $i bash -c "sysctl kernel.unprivileged_bpf_disabled=0";done

# 3. install CNI[Calico v3.23.2] and afxdp-plugin
kubectl apply -f ./k8snetworkplumbingwg

# 4. wait all pods ready
kubectl wait --timeout=100s --for=condition=Ready=true pods --all -A

