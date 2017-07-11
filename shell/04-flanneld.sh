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
if test ! -f $flanneld_rpm_file;then
echo -e "\033[40;31m ######################################### \033[5m"
echo -e "\033[40;31m ##   $flanneld_rpm_file not found !    ## \033[0m"
echo -e "\033[40;31m ######################################### \033[0m" && exit 1
else
yum install -y $flanneld_rpm_file >/dev/null 2>&1
sed 's#{ETCD_ENDPOINTS}#'"$ETCD_ENDPOINTS"'#g;s#{FLANNEL_ETCD_PREFIX}#'"$FLANNEL_ETCD_PREFIX"'#g;s#{NET_INTERFACE_NAME}#'"$NET_INTERFACE_NAME"'#g' $flanneld_config_dir/flanneld > /etc/sysconfig/flanneld
fi

# reset 
systemctl daemon-reload && systemctl enable flanneld
systemctl restart flanneld
systemctl status flanneld >/dev/null 2>&1
if [ $? == 0 ];then
echo -e "\033[32m ######################################### \033[0m"
echo -e "\033[32m ##      Flanneld install Success !     ## \033[0m"
echo -e "\033[32m ######################################### \033[0m" && exit 0
else
echo -e "\033[40;31m ##################################### \033[5m"
echo -e "\033[40;31m ##     Flanneld install Faild !    ## \033[0m"
echo -e "\033[40;31m ##################################### \033[0m"
fi