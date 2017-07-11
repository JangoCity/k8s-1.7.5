#!/bin/bash -x
# author: felix-zh
# e-mail: faer615@gmail.com

###################################
## set global env                ##
###################################

# Currently deployed machines IP
CURRENT_IP=$(ip add|sed -nr 's#.*inet (.*)/24.*global (.*$)#\1#gp'|head -n 1)
k8s_basedir=$HOME/install

# 建议用 未用的网段 来定义服务网段和 Pod 网段
# 服务网段 (Service CIDR），部署前路由不可达，部署后集群内使用 IP:Port 可达
SERVICE_CIDR="10.254.0.0/16"

# POD 网段 (Cluster CIDR），部署前路由不可达，**部署后**路由可达 (flanneld 保证)
CLUSTER_CIDR="172.30.0.0/16"

# 服务端口范围 (NodePort Range)
NODE_PORT_RANGE="10000-35000"

# flanneld 网络配置前缀
FLANNEL_ETCD_PREFIX="/kubernetes/network"

# 集群 DNS 服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_DNS_SVC_IP="10.254.0.2"

# 集群 DNS 域名
CLUSTER_DNS_DOMAIN="cluster.local."


###################################
## etcd 配置                     ##
###################################
NODE_NAME=$(hostname|awk -F"." '{print $1}') # 当前部署的机器名称(随便定义，只要能区分不同机器即可)
NODE_IPS="192.168.61.71 192.168.61.72 192.168.61.73" # etcd 集群所有机器 IP
## etcd 集群各机器名称和对应的IP、端口
ETCD_NODES=node71=https://192.168.61.71:2380,node72=https://192.168.61.72:2380,node73=https://192.168.61.73:2380

## etcd 集群服务地址列表
ETCD_ENDPOINTS="https://192.168.61.71:2379,https://192.168.61.72:2379,https://192.168.61.73:2379"

###################################
# etcd 环境
###################################
etcd_pkg_dir=$k8s_basedir/pkg/etcd
etcd_config_dir=$k8s_basedir/config/etcd

###################################
## ssl 环境                      ##
###################################
k8s_ssl_pkg=$k8s_basedir/pkg/cfssl
k8s_ssl_config=$k8s_basedir/config/cfssl
k8s_ssl_workdir=$k8s_basedir/ssl_work

###################################
## kubernetes 环境               ##
###################################
public_config=$k8s_basedir/config/kubernetes/
KUBE_APISERVER=https://192.168.61.71:6443 # kubelet 访问的 kube-apiserver 的地址
kube_pkg_dir=$k8s_basedir/pkg/kubernetes
kube_tar_file=$kube_pkg_dir/kubernetes-server-linux-amd64.tar.gz
kube_serive=$public_config/server
kube_client=$public_config/client

###################################
## flanneld 环境                 ##
###################################
flanneld_pkg_dir=$k8s_basedir/pkg/flanneld
flanneld_rpm_file=$flanneld_pkg_dir/flannel-0.7.1-1.el7.x86_64.rpm
flanneld_config_dir=$k8s_basedir/config/flanneld
NET_INTERFACE_NAME=eno16777984