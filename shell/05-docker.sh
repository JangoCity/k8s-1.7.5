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
test ! -d $docker_pkg_dir && echo "$docker_pkg_dir not found!" && exit 1

# uninstall package && deal with confix package
yum remove -y systemd-python-219-19.el7.x86_64 libcgroup-tools-0.41-8.el7.x86_64

# install docker packages
cd $docker_pkg_dir && yum install -y *.rpm

# disable firewalld & selinux
systemctl daemon-reload
systemctl disable firewalld
systemctl stop firewalld
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# reset 
systemctl enable docker
systemctl restart docker
systemctl status -l docker
