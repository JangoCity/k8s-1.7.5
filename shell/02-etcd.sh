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

# check etcd diretcory
test ! -f /var/lib/etcd && mkdir -p /var/lib/etcd
test ! -f /etc/etcd && mkdir -p /etc/etcd

# copy etcd file
\cp  $etcd_pkg_dir/etcd* /usr/local/bin
chmod +x /usr/local/bin/etcd*
cat $etcd_config_dir/etcd.conf |sed 's#{NODE_NAME}#'"$NODE_NAME"'#g;s#{CURRENT_IP}#'"$CURRENT_IP"'#g;s#{ETCD_NODES}#'"$ETCD_NODES"'#g' > /etc/etcd/etcd.conf
\cp  $etcd_config_dir/etcd.service /usr/lib/systemd/system/etcd.service

# disable firewalld & start etcd
systemctl daemon-reload
systemctl disable firewalld
systemctl stop firewalld
systemctl enable etcd
systemctl restart etcd

# write Pod network info to etcd DB
etcdctl \
  --endpoints=${ETCD_ENDPOINTS} \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  set ${FLANNEL_ETCD_PREFIX}/config '{"Network":"'${CLUSTER_CIDR}'","Backend":{"Type":"vxlan"}}'

echo -e "\033[32m ################################# \033[0m"
echo -e "\033[32m ##    etcd install Success !   ## \033[0m"
echo -e "\033[32m ################################# \033[0m"