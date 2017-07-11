#!/bin/bash -x
# author: felix-zh
# e-mail: faer615@gmail.com

# import global env
ENVFILE=./00-globalenv.sh
if [ -f $ENVFILE ];then
  . $ENVFILE
else
echo -e "\033[40;31m ############################# \033[5m"
echo -e "\033[40;31m ##   $ENVFILE not found!   ## \033[0m"
echo -e "\033[40;31m ############################# \033[0m"
exit 
fi

# deploy
if test ! -f $kube_tar_file;then
echo -e "\033[40;31m ################################### \033[5m"
echo -e "\033[40;31m ##   $kube_tar_file not found!   ## \033[0m"
echo -e "\033[40;31m ################################### \033[0m"
else
cd $kube_pkg_dir && tar -xvf $kube_tar_file
cp $kube_pkg_dir/kubernetes/server/bin/{kubectl,kube-proxy,kubelet} /usr/local/bin
fi

# create bootstrapper role
kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap

# mkdir work dir for kubelet & kube-proxy
test ! -d /var/lib/kube-proxy && mkdir -p /var/lib/kube-proxy
test ! -d /var/lib/kubelet && mkdir -p /var/lib/kubelet

# create service file and config file
if test ! -f $public_config/config;then
echo -e "\033[40;31m ###################################### \033[5m"
echo -e "\033[40;31m ##   kubernetes/config not found !  ## \033[0m"
echo -e "\033[40;31m ###################################### \033[0m"
exit 1
else
mkdir -p /etc/kubernetes/ && \cp $public_config/config /etc/kubernetes/config
sed 's#{KUBE_APISERVER}#'"$KUBE_APISERVER"'#g' /etc/kubernetes/config
fi

################ kubelet
if test ! -f  $kube_client/service/kubelet.service;then
echo -e "\033[40;31m #################################### \033[5m"
echo -e "\033[40;31m ##   kubelet.server not found !   ## \033[0m"
echo -e "\033[40;31m #################################### \033[0m"
else
# replace var
\cp $kube_client/config/kubelet /etc/kubernetes/kubelet
sed 's#{CURRENT_IP}#'"$CURRENT_IP"'#g;s#{CLUSTER_DNS_SVC_IP}#'"$CLUSTER_DNS_SVC_IP"'#g;s#{CLUSTER_DNS_DOMAIN}#'"$CLUSTER_DNS_DOMAIN"'#g;s#{SERVICE_CIDR}#'"$SERVICE_CIDR"'#g;s#{KUBE_APISERVER}#'"$KUBE_APISERVER"'#g;' /etc/kubernetes/kubelet
cp $kube_client/service/kubelet.service /usr/lib/systemd/system/kubelet.service

# config
cd $k8s_basedir/shell && ./kube-config.sh kubelet

# systemctl start
systemctl daemon-reload && systemctl enable kubelet
systemctl restart kubelet
systemctl status -l kubelet >

############### kube-proxy
if test ! -f $kube_client/service/kube-proxy.service;then
echo -e "\033[40;31m ###################################### \033[5m"
echo -e "\033[40;31m ##   kube-proxy.server not found !  ## \033[0m"
echo -e "\033[40;31m ###################################### \033[0m"
else
# replace var
\cp $kube_client/config/proxy /etc/kubernetes/proxy
sed 's#{CURRENT_IP}#'"$CURRENT_IP"'#g;s#{CLUSTER_DNS_SVC_IP}#'"$CLUSTER_DNS_SVC_IP"'#g;s#{CLUSTER_DNS_DOMAIN}#'"$CLUSTER_DNS_DOMAIN"'#g;s#{SERVICE_CIDR}#'"$SERVICE_CIDR"'#g;' /etc/kubernetes/proxy 
cp $kube_client/service/kube-proxy.service /usr/lib/systemd/system/kube-proxy.service

# config
cd $k8s_basedir/shell && ./kube-config.sh kube-proxy

# systemctl start
systemctl daemon-reload
systemctl enable kube-proxy
systemctl start kube-proxy
systemctl status -l kube-proxy

# Approce csr
cd $k8s_basedir/shell && ./kube-config.sh kubectl
kubectl get csr |awk '/Pending/{print $1}' |while read csr_name;do
  kubectl certificate approve $csr_name
done
