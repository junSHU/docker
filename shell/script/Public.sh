#########################################################################
# File Name: Public.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
#########################################################################
#!/bin/bash
set +e
get_ip() {
    if [ -z "${INTRANETIP}" ];then
        INTRANETIP=`sudo docker run --rm --net=host alpine ip route get 8.8.8.8 | awk '{print $7}'`
    fi
}

get_exip() {
    if [ -z "${EXTRANETIP}" ];then
        EXTRANETIP=`curl -s ipecho.net/plain;echo`
    fi
}

image_exist() {
    RESULT=$(cat /tmp/${IMAGE}-${VERSION}_pull.log | tail -n 1);
    if [[ ${RESULT} != Status* ]];then
		exit 1
	fi
}

container_exist() {
    RESULT=$(sudo docker ps -a | grep -w ${IMAGE}_${ENVNAME} | awk '{print $1}');
    [[ ${RESULT} != '' ]] && remove_container
}

azexecutor_exist() {
    RESULT=$(sudo docker ps -a | grep -w azkaban-executor_${ENVNAME} | awk '{print $1}');
    [[ ${RESULT} != '' ]] && sudo docker rm -f azkaban-executor_${ENVNAME}
}

mysql_exist() {
    RESULT1=$(sudo docker ps -a | grep -w mysql_${ENVNAME} | grep -v "pasoreport" | awk '{print $1}');
	RESULT2=$(sudo docker ps -a | grep -w mysql_${ENVNAME} | grep -v "pasoreport" | awk '{print $7}');
    if [[ ${RESULT1} != '' ]];then
		[[ ${RESULT2} = 'Up' ]] && \
			return 0 || \
			sudo docker rm -f mysql_${ENVNAME}
			echo "Install mysql"
			echo "## Install begins : mysql"
			start_mysql
			if [ $? -ne 0 ]; then
				echo "Install failed..."
				exit 1
			fi
			echo "## Install ends   : mysql"
	else
	    echo "Install mysql"
        echo "## Install begins : mysql"
        start_mysql
        if [ $? -ne 0 ]; then
			echo "Install failed..."
			exit 1
		fi
		echo "## Install ends   : mysql"
	fi
}

pamysql_exist() {
    RESULT1=$(sudo docker ps -a | grep -w pasoreport-mysql_${ENVNAME} | awk '{print $1}');
	RESULT2=$(sudo docker ps -a | grep -w pasoreport-mysql_${ENVNAME} | awk '{print $7}');
    if [[ ${RESULT1} != '' ]];then
		[[ ${RESULT2} = 'Up' ]] && \
			return 0 || \
			sudo docker rm -f pasoreport-mysql_${ENVNAME}
			echo "Install pasoreport-mysql"
			echo "## Install begins : pasoreport-mysql"
			start_pamysql
			if [ $? -ne 0 ]; then
				echo "Install failed..."
				exit 1
			fi
			echo "## Install ends   : pasoreport-mysql"
	else 
	    echo "Install pasoreport-mysql"
        echo "## Install begins : pasoreport-mysql"
        start_pamysql
        if [ $? -ne 0 ]; then
			echo "Install failed..."
			exit 1
		fi
		echo "## Install ends   : pasoreport-mysql"
	fi
}

azmysql_exist() {
    RESULT1=$(sudo docker ps -a | grep -w azkaban-mysql_${ENVNAME} | awk '{print $1}');
	RESULT2=$(sudo docker ps -a | grep -w azkaban-mysql_${ENVNAME} | awk '{print $7}');
    if [[ ${RESULT1} != '' ]];then
		[[ ${RESULT2} = 'Up' ]] && \
			return 0 || \
			sudo docker rm -f azkaban-mysql_${ENVNAME}
			echo "Install azkaban-mysql"
			echo "## Install begins : azkaban-mysql"
			start_azmysql
			if [ $? -ne 0 ]; then
				echo "Install failed..."
				exit 1
			fi
			echo "## Install ends   : azkaban-mysql"
	else 
	    echo "Install azkaban-mysql"
        echo "## Install begins : azkaban-mysql"
        start_azmysql
        if [ $? -ne 0 ]; then
			echo "Install failed..."
			exit 1
		fi
		echo "## Install ends   : azkaban-mysql"
	fi
}

zk_exist() {
    RESULT1=$(sudo docker ps -a | grep -w zookeeper_${ENVNAME} | awk '{print $1}');
	RESULT2=$(sudo docker ps -a | grep -w zookeeper_${ENVNAME} | awk '{print $7}');
    if [[ ${RESULT1} != '' ]];then
		[[ ${RESULT2} = 'Up' ]] && \
			return 0 || \
			sudo docker rm -f zookeeper_${ENVNAME}
			echo "Install zookeeper"
			echo "## Install begins : zookeeper"
			start_zookeeper
			if [ $? -ne 0 ]; then
				echo "Install failed..."
				exit 1
			fi
			echo "## Install ends   : zookeeper"
	else 
	    echo "Install zookeeper"
        echo "## Install begins : zookeeper"
        start_zookeeper
        if [ $? -ne 0 ]; then
			echo "Install failed..."
			exit 1
		fi
		echo "## Install ends   : zookeeper"
	fi
}

paredis_exist() {
    RESULT1=$(sudo docker ps -a | grep -w pasoreport-redis_${ENVNAME} | awk '{print $1}');
	RESULT2=$(sudo docker ps -a | grep -w pasoreport-redis_${ENVNAME} | awk '{print $7}');
	if [[ ${RESULT1} != '' ]];then
		[[ ${RESULT2} = 'Up' ]] && \
			return 0 || \
			sudo docker rm -f pasoreport-redis_${ENVNAME}
			echo "Install pasoreport-redis"
			echo "## Install begins : pasoreport-redis"
			start_paredis
			if [ $? -ne 0 ]; then
				echo "Install failed..."
				exit 1
			fi
			echo "## Install ends   : pasoreport-redis"
	else 
	    echo "Install pasoreport-redis"
        echo "## Install begins : pasoreport-redis"
        start_paredis
        if [ $? -ne 0 ]; then
			echo "Install failed..."
			exit 1
		fi
		echo "## Install ends   : pasoreport-redis"
	fi
}

samba_exist() {
    RESULT1=$(sudo docker ps -a | grep -w samba | awk '{print $1}');
	RESULT2=$(sudo docker ps -a | grep -w samba | awk '{print $9}');
    if [[ ${RESULT1} != '' ]];then
		[[ ${RESULT2} = 'Up' ]] && \
			return 0 || \
			sudo docker rm -f samba
			echo "Install samba"
			echo "## Install begins : samba"
			start_samba
			if [ $? -ne 0 ]; then
				echo "Install failed..."
				exit 1
			fi
			echo "## Install ends   : samba"
	else 
	    echo "Install samba"
        echo "## Install begins : samba"
        start_samba
        if [ $? -ne 0 ]; then
			echo "Install failed..."
			exit 1
		fi
		echo "## Install ends   : samba"
	fi
}

start_samba() {

    ID=$(sudo docker run -d \
						 -v /etc/localtime:/etc/localtime \
						 -p 139:139 \
						 -p 445:445 \
						 --restart=on-failure:3 \
						 --name samba \
						 -v /${DEPLOYDIR}/heading/:/share \
						 dperson/samba -s "public;/share;yes;no;yes;all" -p) >/dev/null 2>&1
}

host_exist() {
    RESULT=$(cat /etc/hosts | tail -n 1 | awk '{print $1}');
    if [[ ${RESULT} = "${EXTRANETIP}" ]];then
		return 0
    else
    	addintr
		addextr
    fi
}

remove_container() {
    sudo docker rm -f ${IMAGE}_${ENVNAME} > /dev/null 2>&1
}

restart_container() {
    sudo docker stop ${IMAGE}_${ENVNAME} && sudo docker start ${IMAGE}_${ENVNAME} > /dev/null 2>&1
}

restart_samba() {
    sudo docker stop samba && sudo docker start samba > /dev/null 2>&1
}

addintr() {
	get_ip
    echo "${INTRANETIP} ${HOSTNAME}" >> /etc/hosts 
}

addextr() {
	get_exip
    echo "${EXTRANETIP} ${EXTRANETHOST}" >> /etc/hosts 
}

pull_image() {
    set +e
    echo "Waiting for pull ${IMAGE}"
	until
		(sudo docker login -u ${DOCKERHUBUSER} -p ${DOCKERHUBUSERPW} ${DOCKERHUB};
		 sudo docker pull ${DOCKERHUB}/${IMAGE}:${VERSION} | sudo tee /tmp/${IMAGE}-${VERSION}_pull.log;
		);do
		printf '.'
		sleep 1
	done
}

pro_install() {
	set -e
	get_ip
	get_exip
	
    echo "Install and deploying ${IMAGE}"
    echo "## Install begins : ${IMAGE}"
    pull_image
	image_exist
	container_exist
	start_container
    if [ $? -ne 0 ]; then
		echo "Install failed..."
		exit 1
    fi
    echo "## Install ends   : ${IMAGE}"
	echo "## deploying begins : ${IMAGE}"
	sleep 10
    deploying_container
    if [ $? -ne 0 ]; then
		echo "deploying failed..."
		exit 1
    fi
    echo "## deploying ends   : ${IMAGE}"
	
	echo "Restart ${IMAGE}"
	sleep 3
    restart_container
	cpout_config
}

pro_redeploy() {
	set -e
	echo "Redeploy ${IMAGE}"
    get_ip
	get_exip
	container_exist
	start_container
	cpin_config
	restart_container
}
export -f pull_image restart_container remove_container mysql_exist container_exist image_exist get_exip get_ip pro_redeploy pro_install paredis_exist pamysql_exist zk_exist azmysql_exist azexecutor_exist

host_exist
samba_exist

products_install() {
    set +e
	PRODUCT=$1
	[[ ${PRODUCT} = 'CARD' ]] && \
	eval bash ${PRODUCT}.sh -v \$${PRODUCT}VERSION --hqport ${HQPORT} --ctport ${CTPORT} --hqmport ${HQMPORT} --ctmport ${CTMPORT} --csport ${CSPORT} || \
	eval bash ${PRODUCT}.sh -v \$${PRODUCT}VERSION --webport \$${PRODUCT}PORT
}

path_config() {
	set +e
	PRODUCT=$1
	export ConfPath="/${DEPLOYDIR}/heading/config_${ENVNAME}/${PRODUCT}"  
	if [ ! -d "$ConfPath" ];then
		[[ ${PRODUCT} = 'CARD' ]] && \
			sudo mkdir -p ${ConfPath}/{hq,ct,cs} || \
			sudo mkdir -p ${ConfPath}
	fi
}

for PRODUCTLIST in $LIST;do
	path_config $PRODUCTLIST
	products_install $PRODUCTLIST
done

restart_samba
