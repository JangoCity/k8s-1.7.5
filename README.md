# 00 Kubernetes 1.7 版本环境（持续完善中）
## 系统版本及软件版本
+ CentOS Linux release 7.3.1611 (Core)
+ linux kernel 3.10.0-514.16.1.el7.x86_64
+ kubernetes 1.7.0
+ docker version 1.12.6, build 3a094bd/1.12.6
+ etcd 3.2.0
+ Flanneld 0.7.1 vxlan 网络
+ TLS 认证通信相关组件，(如etcd、kubernetes master 和 node)
+ RBAC 授权
+ kubelet TLS BootStrapping、kubedns、dashboard、heapster(influxdb、grafana)、EFK (elasticsearch、fluentd、kibana) 插件
+ 私有 docker registry，使用 ceph rgw 后端存储，TLS + HTTP Basic 认证
## 软件包自行下载
```
[root@node71 ~/install/pkg]# tree /root/install/pkg/
/root/install/pkg/
├── cfssl
│   ├── cfssl
│   ├── cfssl-certinfo
│   └── cfssljson
├── etcd
│   ├── etcd
│   └── etcdctl
├── flanneld
│   ├── flannel-0.7.1-1.el7.x86_64.rpm
│   └── flannel-v0.8.0-rc1-linux-amd64.tar.gz
└── kubernetes
    └── kubernetes-server-linux-amd64.tar.gz
```
4 directories, 8 files
## 集群机器
+ 192.168.61.71
+ 192.168.61.72
+ 192.168.61.73
+ 192.168.61.74
+ 192.168.61.75
+ 192.168.61.76

## 集群环境变量
```
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
```

# 1. 创建 TLS 证书和秘钥
kubernetes 系统各组件需要使用 TLS 证书对通信进行加密，本文档使用 CloudFlare 的 PKI 工具集 cfssl 来生成 Certificate Authority (CA) 和其它证书。

生成的 CA 证书和秘钥文件如下：
+ ca-key.pem
+ ca.pem
+ kubernetes-key.pem
+ kubernetes.pem
+ kube-proxy.pem
+ kube-proxy-key.pem
+ admin.pem
+ admin-key.pem

使用证书的组件如下：
+ etcd：使用 ca.pem、kubernetes-key.pem、kubernetes.pem；
+ kube-apiserver：使用 ca.pem、kubernetes-key.pem、kubernetes.pem；
+ kubelet：使用 ca.pem；
+ kube-proxy：使用 ca.pem、kube-proxy-key.pem、kube-proxy.pem；
+ kubectl：使用 ca.pem、admin-key.pem、admin.pem；
+ kube-controller、kube-scheduler与kube-apiserver部署在同一台机器上且使用非安全端口通信，故不需要证书。

> kubernetes 1.4 开始支持 TLS Bootstrapping 功能，由 kube-apiserver 为客户端生成 TLS 证书，这样就不需要为每个客户端生成证书（该功能目前仅支持 kubelet，所以本文档没有为 kubelet 生成证书和秘钥）。

## 添加集群机器ip
``` bash
# cat install/pkg/cfssl/config/kubernetes-csr.json
{
  "CN": "kubernetes",
  "hosts": [
    ...
    "192.168.61.71",
    "192.168.61.72",
    "192.168.61.73",
    "192.168.61.100",
    ...
  ],
  ...
}

```
## 使用脚本生成TLS 证书和秘钥
```
# cd install/shell
# ./01-mkssl.sh
```
> 检查/etc/kubernetes/ssl目录下自动生成相关的证书完整性

## 分发证书
将生成的证书和秘钥文件（后缀名为.pem）拷贝到所有机器的 /etc/kubernetes/ssl 目录下

> 当前机器已在/etc/kubernetes/ssl生成了证书，只需要将该目录copy至其他节点机器上

> 确保 /etc/kubernetes/token.csv 也一并分发

# 02 部署高可用etcd集群
kuberntes 使用 etcd 存储数据，本文档部署3个节点的 etcd 高可用集群，(复用kubernetes master机器)，分别命名为node71、node72、node73：

+ node71：192.168.61.71
+ node72：192.168.61.72
+ node73：192.168.61.73

## 修改使用的变量
修改当前机器上的00-globalenv.sh上的相关ip与配置信息
+  CURRENT_IP
+  basedir
+  FLANNEL_ETCD_PREFIX
+  NODE_NAME
+  NODE_IPS
+  ETCD_NODES
+  ETCD_ENDPOINTS

## 确认TLS 认证文件
为 etcd 集群创建加密通信的 TLS 证书，复用/etc/kubernetes/ssl证书,具体如下：
+ ca.pem 
+ kubernetes-key.pem 
+ kubernetes.pem
> kubernetes 证书的hosts字段列表中包含上面三台机器的 IP，否则后续证书校验会失败；

## 安装etcd
执行安装脚本install/shell/02-etcd.sh
``` bash
# cd install/shell
# ./02-etcd.sh
```
> 在所有的etcd节点重复上面的步骤，直到所有机器etcd 服务都已启动。

## 确认集群状态
三台 etcd 的输出均为 healthy 时表示集群服务正常（忽略 warning 信息）
``` bash
# cd install/shell
# ./77-etcd-status.sh
2017-07-11 09:08:40.814488 I | warning: ignoring ServerName for user-provided CA for backwards compatibility is deprecated
https://192.168.31.180:2379 is healthy: successfully committed proposal: took = 8.442607ms
```
## 检查 etcd集群中配置的网段信息
```
[root@node71 shell]# ./77-etcdctl.sh get /kubernetes/network/config
```

# 03 部署kubernetes master节点
kubernetes master 节点包含的组件：
+ kube-apiserver
+ kube-scheduler
+ kube-controller-manager
+ flanneld

> 安装flanneld组件用以dashboard，heapster访问node上的pod用

目前这三个组件需要部署在同一台机器上

## 修改环境变量
确认以下环境变量为当前机器上正确的参数
+  CURRENT_IP
+  basedir
+  FLANNEL_ETCD_PREFIX
+  ETCD_ENDPOINTS
+  KUBE_APISERVER
+  kube_pkg_dir
+  kube_tar_file

> ETCD_ENDPOINTS该参数被flanneld启动使用

## 确认TLS 证书文件
确认token.csv，ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem 存在
``` bash
# find /etc/kubernetes/
/etc/kubernetes/
/etc/kubernetes/ssl
/etc/kubernetes/ssl/admin-key.pem
/etc/kubernetes/ssl/admin.pem
/etc/kubernetes/ssl/ca-key.pem
/etc/kubernetes/ssl/ca.pem
/etc/kubernetes/ssl/kube-proxy-key.pem
/etc/kubernetes/ssl/kube-proxy.pem
/etc/kubernetes/ssl/kubernetes-key.pem
/etc/kubernetes/ssl/kubernetes.pem
/etc/kubernetes/token.csv
```
## 安装和配置 flanneld
### 检查修改flanneld指定的网卡信息
+ 查看实际ip所在的网卡名字
``` bash
[root@k8s-master shell]# ip a
```
+ 设置网卡名字为：**eno16777984**
``` bash
# vi install/shell/00-setenv.sh
NET_INTERFACE_NAME=eno16777984
```
> 因flanneld启动会绑定网卡以生成虚拟ip信息，若不指定，会自动找寻除lookback外的网卡信息

### 安装并启动flanneld
```
# cd install/shell
# ./04-flanneld.sh
```
> 该脚本会安装flanneld软件，以供dashboard，heapster可以通过web访问

## 部署kube-apiserver,kube-scheduler,kube-controller-manager
执行部署脚本，部署相关master应用
``` bash
# cd install/shell
# ./03-kube-master.sh
```
> 该脚本中会安装kube master相关组件并配置kubectl config

## 验证 master 节点功能
``` bash
[root@node71 shell]# kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-0               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"} 
```

# 04 部署kubernetes node节点
kubernetes Node 节点包含如下组件：
+ flanneld
+ docker
+ kubelet
+ kube-proxy

## 确认环境变量
> cat install/shell/00-globalenv.sh
+ CURRENT_IP
+ basedir
+ KUBE_APISERVER
+ kube_pkg_dir
+ kube_tar_file

## 确认TLS 证书文件
确认token.csv，ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem 存在
```
# find /etc/kubernetes/
/etc/kubernetes/
/etc/kubernetes/ssl
/etc/kubernetes/ssl/admin-key.pem
/etc/kubernetes/ssl/admin.pem
/etc/kubernetes/ssl/ca-key.pem
/etc/kubernetes/ssl/ca.pem
/etc/kubernetes/ssl/kube-proxy-key.pem
/etc/kubernetes/ssl/kube-proxy.pem
/etc/kubernetes/ssl/kubernetes-key.pem
/etc/kubernetes/ssl/kubernetes.pem
/etc/kubernetes/token.csv
```
## 安装和配置 flanneld  
具体见master上安装flanneld步骤

## 安装和配置 docker
```
# cd install/shell
# ./04-docker.sh

```
> 若安装失败，请检查os版本安装时，是否是最小化安装，或者根据报错依赖信息，直接删除掉systemd-python-219-19.el7.x86_64和libcgroup-tools-0.41-8.el7.x86_64

```
# yum remove -y systemd-python-219-19.el7.x86_64 libcgroup-tools-0.41-8.el7.x86_64
```
> 该脚本会自动关闭并配置selinux为被动模式并停止防火墙;
> + 设置selinux为被动模式，是避免docker创建文件系统报权限失败；
> + 设置firewalld是为了防止添加的iptables信息与docker自身的冲突，造成访问失败；

```
# 可以通过如下命令查看下相关信息
# sestatus
# systemctl status -l firewalld
```

## 安装和配置 kubelet和kube-proxy
```
# ./06-kube-node.sh
```

# 05 部署kubedns 插件
## 安装
``` bash
[root@node71 ~/install/yml]# ls -ltr  ~/install/yml/01-kubedns/
total 20
-rw-r--r-- 1 root root 1061 Jul  5 12:43 kubedns-svc.yaml
-rw-r--r-- 1 root root  195 Jul  5 12:43 kubedns-sa.yaml
-rw-r--r-- 1 root root  752 Jul  5 12:43 kubedns-cm.yaml
-rw-r--r-- 1 root root 5535 Jul  7 11:03 kubedns-controller.yaml

[root@node71 ~/install/yml]# kubectl create -f 01-kubedns/
configmap "kube-dns" created
deployment "kube-dns" created
serviceaccount "kube-dns" created
service "kube-dns" created
```
> 确保yaml配置的image源地址正确

## 确认状态
``` bash
root@node71 ~/install]# kubectl get svc,po -o wide --all-namespaces
NAMESPACE     NAME             CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE   SELECTOR
default       svc/kubernetes   10.254.0.1    <none>        443/TCP   5d    <none>
kube-system   svc/kube-dns     10.254.0.2   <none>        53/UDP,53/TCP   7m        k8s-app=kube-dns

NAMESPACE     NAME             READY     STATUS    RESTARTS   AGE     IP        NODE
kube-system   po/default-http-backend-1865486490-r500p   1/1      Running   0      8h   172.30.74.2   192.168.61.76
```

# 06 部署 dashboard 插件
## 创建
``` bash
[root@node71 ~/install/yml]# ls -ltr  ~/install/yml/02-dashboard/
total 12
-rw-r--r-- 1 root root  355 Jul  5 12:43 dashboard-service.yaml
-rw-r--r-- 1 root root  384 Jul  5 12:43 dashboard-rbac.yaml
-rw-r--r-- 1 root root 1193 Jul  7 11:04 dashboard-controller.yaml

[root@node71 ~/install/yml]# kubectl create -f 02-dashboard
deployment "kubernetes-dashboard" created
serviceaccount "dashboard" created
clusterrolebinding "dashboard" created
service "kubernetes-dashboard" created
```
## 确认状态
``` bash
[root@node71 ~/install/yml]# kubectl get svc,po -o wide --all-namespaces
NAMESPACE     NAME                       CLUSTER-IP     EXTERNAL-IP   PORT(S)         AGE       SELECTOR
default       svc/kubernetes             10.254.0.1     <none>        443/TCP         3d        <none>
kube-system   svc/kube-dns               10.254.0.2     <none>        53/UDP,53/TCP   12m       k8s-app=kube-dns
kube-system   svc/kubernetes-dashboard   10.254.41.68   <nodes>       80:8522/TCP     19s       k8s-app=kubernetes-dashboard

NAMESPACE     NAME                                       READY     STATUS    RESTARTS   AGE       IP            NODE
kube-system   po/kube-dns-682617846-2k9xn                3/3       Running   0          12m       172.30.61.2   192.168.61.73
kube-system   po/kubernetes-dashboard-2172513996-thb5q   1/1       Running   0          18s       172.30.57.2   192.168.61.72
```
查看分配的 NodePort
+ 通过之前的命令，可以看到svc/kubernetes-dashboard NodePort 8522映射到 dashboard pod 80端口；

## 访问dashboard
+ kubernetes-dashboard 服务暴露了 NodePort，可以使用 http://NodeIP:nodePort 地址访问 dashboard；
``` bash
[root@node71 ~/install/yml]# kubectl get po,svc -o wide --all-namespaces |grep dashboard

kube-system   po/kubernetes-dashboard-3851771191-k5839   1/1       Running   0          4d        172.30.46.2   192.168.61.75
kube-system   svc/kubernetes-dashboard    10.254.178.184   <nodes>       80:16304/TCP                    4d        k8s-app=kubernetes-dashboard
```
> 直接访问： http://192.168.61.75:16304 或者 http://192.168.61.71:8080/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy/#!/workload?namespace=default
+ 通过 kube-apiserver 访问 dashboard；

``` bash
[root@node71 ~/install/yml]# kubectl cluster-info
Kubernetes master is running at https://192.168.61.71:6443
Elasticsearch is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/elasticsearch-logging/proxy
Heapster is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/heapster/proxy
Kibana is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/kibana-logging/proxy
KubeDNS is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/kube-dns/proxy
kubernetes-dashboard is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy
monitoring-grafana is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/monitoring-grafana/proxy
monitoring-influxdb is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/monitoring-influxdb/proxy
```
> 直接通过https访问会报错，可以通过http api的8080端口访问
+ 通过 kubectl proxy 访问 dashboard：

``` bash
任意安装kubectl节点执行
# kubectl proxy --address=0.0.0.0 --accept-hosts='^*$'
# 通过 http://ip:8001/ui/ 访问 kubernetes-dashboard
```

# 07 部署 Heapster插件
## 创建
``` bash
[root@node71 ~/install/yml]# kubectl create -f 03-heapster
deployment "monitoring-grafana" created
service "monitoring-grafana" created
deployment "heapster" created
serviceaccount "heapster" created
clusterrolebinding "heapster" created
service "heapster" created
configmap "influxdb-config" created
deployment "monitoring-influxdb" created
service "monitoring-influxdb" created
```
## 确认状态
``` bash
[root@node71 ~/install/yml]# kubectl get svc,po -o wide --all-namespaces
kube-system   svc/heapster               10.254.244.190   <none>        80/TCP                        28s       k8s-app=heapster
kube-system   svc/monitoring-grafana     10.254.72.242    <none>        80/TCP                        28s       k8s-app=grafana
kube-system   svc/monitoring-influxdb    10.254.129.64    <nodes>       8086:8815/TCP,8083:8471/TCP   27s       k8s-app=influxdb

NAMESPACE     NAME                                       READY     STATUS    RESTARTS   AGE       IP            NODE
kube-system   po/heapster-1982147024-17ltr               1/1       Running   0          27s       172.30.61.4   192.168.61.73
kube-system   po/monitoring-grafana-1505740515-46r2h     1/1       Running   0          28s       172.30.57.3   192.168.61.72
kube-system   po/monitoring-influxdb-14932621-ztgh4      1/1       Running   0          27s       172.30.61.3   192.168.61.73
```
# 08 部署 EFK 插件
## 安装
``` bash
[root@node71 ~/install/yml/05-efk]# kubectl create -f ./      
replicationcontroller "elasticsearch-logging-v1" created
serviceaccount "elasticsearch" created
clusterrolebinding "elasticsearch" created
service "elasticsearch-logging" created
daemonset "fluentd-es-v1.23" created
serviceaccount "fluentd" created
clusterrolebinding "fluentd" created
deployment "kibana-logging" created
service "kibana-logging" created
```
> 确保yaml里面配置的image可用
## 给 Node 设置标签
DaemonSet fluentd-es-v1.23 只会调度到设置了标签 beta.kubernetes.io/fluentd-ds-ready=true 的 Node，需要在期望运行 fluentd 的 Node 上设置该标签；

``` bash
kubectl label nodes 192.168.61.73 beta.kubernetes.io/fluentd-ds-ready=true
```
## 检查状态

``` bash
[root@node71 ~/install/yml/05-efk]# kubectl cluster-info
Kubernetes master is running at https://192.168.61.71:6443
Elasticsearch is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/elasticsearch-logging/proxy
Heapster is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/heapster/proxy
Kibana is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/kibana-logging/proxy
KubeDNS is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/kube-dns/proxy
kubernetes-dashboard is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy
monitoring-grafana is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/monitoring-grafana/proxy
monitoring-influxdb is running at https://192.168.61.71:6443/api/v1/namespaces/kube-system/services/monitoring-influxdb/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

## 访问
直接通过https访问会报错，可以通过http直接访问8080端口

> 在 Settings -> Indices 页面创建一个 index（相当于 mysql 中的一个database），选中 Index contains time-based events，使用默认的 logstash-* pattern，点击 Create ;

> 节点上的docker日志类型默认为journald, 若需要EFK监控，需要修改docker配置文件，并重启才可以操作生效

```
# vi /etc/sysconfig/docker
将如下配置
OPTIONS='--selinux-enabled --log-driver=journald --signature-verification=false'
修改为：
OPTIONS='--selinux-enabled --log-driver=json-file --signature-verification=false'
重启docker服务后，生效
```
