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
exit 1
fi

# deploy kube-master
if test ! -f $kube_tar_file;then
echo -e "\033[40;31m ################################### \033[5m"
echo -e "\033[40;31m ##   $kube_tar_file not found!   ## \033[0m"
echo -e "\033[40;31m ################################### \033[0m"
exit 0
else
cd $kube_pkg_dir && tar -xvf $kube_tar_file >/dev/null 2>&1
\cp $kube_pkg_dir/kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubectl} /usr/local/bin
fi

# create service file and config file
if test ! -f $public_config/config;then
echo -e "\033[40;31m ###################################### \033[5m"
echo -e "\033[40;31m ##   kubernetes/config not found !  ## \033[0m"
echo -e "\033[40;31m ###################################### \033[0m"
exit 1
else
mkdir -p /etc/kubernetes/ && \cp $public_config/config /etc/kubernetes/config
sed 's#{KUBE_APISERVER}#http://'"$CURRENT_IP"':8080#g' /etc/kubernetes/config
fi

for i in apiserver scheduler controller-manager;do
  test ! -f $kube_serive/config/kube-$i.service 
echo -e "\033[40;31m ################################### \033[5m"
echo -e "\033[40;31m ##   kube-$i.server not found!   ## \033[0m"
echo -e "\033[40;31m ################################### \033[0m"
&& exit 1 

# create services & replace var
sed 's#{CURRENT_IP}#'"$CURRENT_IP"'#g;s#{SERVICE_CIDR}#'"$SERVICE_CIDR"'#g;s#{NODE_PORT_RANGE}#'"$NODE_PORT_RANGE"'#g;s#{CLUSTER_CIDR}#'"$CLUSTER_CIDR"'#g;s#{ETCD_ENDPOINTS}#'"$ETCD_ENDPOINTS"'#g' $kube_serive/service/kube-$i.service > /usr/lib/systemd/system/kube-$i.service

# create config files
sed 's#{CURRENT_IP}#'"$CURRENT_IP"'#g;s#{SERVICE_CIDR}#'"$SERVICE_CIDR"'#g;s#{NODE_PORT_RANGE}#'"$NODE_PORT_RANGE"'#g;s#{CLUSTER_CIDR}#'"$CLUSTER_CIDR"'#g;s#{ETCD_ENDPOINTS}#'"$ETCD_ENDPOINTS"'#g' $kube_serive/config/$i > /etc/kubernetes/$i

# systemctl start
systemctl daemon-reload
systemctl enable kube-$i
systemctl restart kube-$i
systemctl status -l kube-$i
done

echo -e "\033[32m ######################################### \033[0m"
echo -e "\033[32m ##        kube-$i install Success !    ## \033[0m"
echo -e "\033[32m ######################################### \033[0m"

# create config file
cd $k8s_basedir/shell && ./kube-config.sh kubectl

echo -e "\033[32m ######################################### \033[0m"
echo -e "\033[32m ##   kubectl-config create  Success!   ## \033[0m"
echo -e "\033[32m ######################################### \033[0m"