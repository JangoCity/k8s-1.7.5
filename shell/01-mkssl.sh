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

current_timestamp=`date +%Y%m%d%H%M%S`

if test -d $k8s_ssl_workdir;then
  mv $k8s_ssl_workdir $k8s_ssl_workdir.$current_timestamp
fi
mkdir -p $k8s_ssl_workdir && cd $k8s_ssl_workdir || (echo "$k8s_ssl_workdir not exist";exit 1)
export PATH="$PATH:$k8s_basedir/pkg/cfssl"

# check ssl file
for i in cfssl cfssljson cfssl-certinfo;do
  test ! -f $k8s_ssl_pkg/$i && echo "file $k8s_basedir/pkg/cfssl/$i not found!" && exit 1
done

# check ssl config file
for i in ca-config.json kubernetes-csr.json admin-csr.json kube-proxy-csr.json;do
  test ! -f $k8s_ssl_config/$i && echo "file $k8s_ssl_config/$i not found!" && exit 1
done

# create ssl
## create CA
cfssl gencert -initca $k8s_ssl_config/ca-csr.json | cfssljson -bare ca

## create kubernetes
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=$k8s_ssl_config/ca-config.json -profile=kubernetes $k8s_ssl_config/kubernetes-csr.json | cfssljson -bare kubernetes

## create admin
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=$k8s_ssl_config/ca-config.json -profile=kubernetes $k8s_ssl_config/admin-csr.json | cfssljson -bare admin

## create kube-proxy
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=$k8s_ssl_config/ca-config.json -profile=kubernetes $k8s_ssl_config/kube-proxy-csr.json | cfssljson -bare kube-proxy

# deploy ssl-key
echo -e "\033[32m Deploy SSL KEY FILE to /etc/kubernetes/ssl \033[0m"
if test ! -f /etc/kubernetes/ssl;then
   mkdir -p /etc/kubernetes/ssl
   \cp $k8s_ssl_workdir/*.pem /etc/kubernetes/ssl
else
echo -e "\033[40;31m ################################ \033[5m"
echo -e "\033[40;31m ##  SSL KEY FILE is exists !  ## \033[5m"
echo -e "\033[40;31m ################################ \033[0m"
fi

## create admin client key
cd /etc/kubernetes/ssl
openssl pkcs12 -export -in admin.pem -inkey admin-key.pem -out k8s-admin.p12

echo -e "\033[32m ############################################ \033[0m"
echo -e "\033[32m ##   admin-certificate create Success !   ## \033[0m"
echo -e "\033[32m ############################################ \033[0m"

#echo -n "Do you Deploy SSL KEY FILE to /etc/kubernetes/ssl??? [Y/enter N] "
# read flag
#if [ "X$flag" == "XY" ];then
#  test ! -f /etc/kubernetes/ssl && mkdir -p /etc/kubernetes/ssl
#  \cp $k8s_ssl_workdir/*.pem /etc/kubernetes/ssl
#fi

# copy token csv
# cp $k8s_ssl_config/token.csv /etc/kubernetes