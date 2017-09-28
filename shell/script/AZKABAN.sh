###############################################################################
# File Name: AZKABAN.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-azkaban-webserver}
VERSION=${VERSION:-latest}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
PREFIX=${PREFIX:-azkaban}
WEBPORT=${WEBPORT:-8443}
AZMYSQLPORT=${AZMYSQLPORT:-3306}
AZEXECUTORPORT=${AZEXECUTORPORT:-12321}
DEPLOYDIR=${DEPLOYDIR:-data}
LOGDIR=${LOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}}
ETLDIR=${ETLDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/azkaban_etl_${ENVNAME}}
PROJDIR=${PROJDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/azkaban_projects_${ENVNAME}}
AZMYSQLDATADIR=${AZMYSQLDATADIR:-/${DEPLOYDIR}/heading/${ENVNAME}/azkaban_${ENVNAME}/mysqldata}
AZMYSQL_ROOT_PASSWORD=${AZMYSQL_ROOT_PASSWORD:-headingazkaban}
AZMYSQL_DATABASE=${AZMYSQL_DATABASE:-azkaban}
AZMYSQL_USER=${AZMYSQL_USER:-azkaban}
AZMYSQL_PASSWORD=${AZMYSQL_PASSWORD:-azkaban}
AZKABAN_METRICS=${AZKABAN_METRICS:-metrics}
PROTOCOL=https


#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long webport: -n 'AZKABAN.sh' -- "$@"`
if [ $? != 0 ]; then
    echo "Terminating..."
    exit 1
fi

#echo $ARGS
#将规范化后的命令行参数分配至位置参数（$1,$2,...)
eval set -- "${ARGS}"

while true
do
    case "$1" in
		-v) 
		    VERSION="$2"; 
			shift 2 ;;
		--webport)
      		WEBPORT="$2"; 
			shift 2 ;;
        --)
            shift
            break
            ;;
        *)
            echo "Internal error!"
            exit 1
            ;;
    esac
done

#处理剩余的参数
for arg in $@
do
    echo "processing $arg"
done

start_azmysql() {

    ID=$(sudo docker run -d \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
						 -e MYSQL_ROOT_PASSWORD=${AZMYSQL_ROOT_PASSWORD} \
						 -e MYSQL_DATABASE=${AZMYSQL_DATABASE} \
						 -e MYSQL_USER=${AZMYSQL_USER} \
						 -e MYSQL_PASSWORD=${AZMYSQL_PASSWORD} \
						 -p ${AZMYSQLPORT}:3306 \
						 -v ${AZMYSQLDATADIR}:/var/lib/mysql \
						 --name ${PREFIX}-mysql_${ENVNAME} ${DOCKERHUB}/mysql:5.7.14 \
						 --character-set-server=utf8 --collation-server=utf8_general_ci) >/dev/null 2>&1
}

start_azexecutor() {

    ID=$(sudo docker run -d \
						  -p ${AZEXECUTORPORT}:12321 \
						  --restart=on-failure:3 \
						  --log-opt max-size=50m \
						  -m 1g \
						  -v ${ETLDIR}:/opt/heading/etl \
						  -v ${PROJDIR}:/opt/heading/azkaban-executor/projects \
						  -e AZKABAN_MYSQL_HOST=${INTRANETIP} \
						  -e AZKABAN_MYSQL_PORT=${AZMYSQLPORT} \
						  -e AZKABAN_MYSQL_DATABASE=${AZMYSQL_DATABASE} \
						  -e AZKABAN_MYSQL_USER=${AZMYSQL_USER} \
						  -e AZKABAN_MYSQL_PASSWORD=${AZMYSQL_PASSWORD} \
						  --name ${PREFIX}-executor_${ENVNAME} ${DOCKERHUB}/${PREFIX}-executor:${VERSION}) >/dev/null 2>&1
}

pull_azexecutor() {
    set +e
    echo "Waiting for pull ${IMAGE}"
	until
		(sudo docker login -u ${DOCKERHUBUSER} -p ${DOCKERHUBUSERPW} -e ${DOCKERHUBUSEREM} ${DOCKERHUB};
		 sudo docker pull ${DOCKERHUB}/${PREFIX}-executor:${VERSION} | sudo tee /tmp/${PREFIX}-executor-${VERSION}_pull.log;
		);do
		printf '.'
		sleep 1
	done
}

azexecutorimage_exist() {
    RESULT=$(cat /tmp/${PREFIX}-executor-${VERSION}_pull.log | tail -n 1);
    if [[ ${RESULT} != Status* ]];then
		exit 1
	fi
}

start_container() {

    ID1=$(sudo docker run -d \
						  -p ${WEBPORT}:8443 \
						  --restart=on-failure:3 \
						  --log-opt max-size=50m \
						  -m 1g \
						  -e AZKABAN_EXECUTOR_PORT=${AZEXECUTORPORT} \
						  -e AZKABAN_MYSQL_HOST=${INTRANETIP} \
						  -e AZKABAN_MYSQL_PORT=${AZMYSQLPORT} \
						  -e AZKABAN_MYSQL_DATABASE=${AZMYSQL_DATABASE} \
						  -e AZKABAN_MYSQL_USER=${AZMYSQL_USER} \
						  -e AZKABAN_MYSQL_PASSWORD=${AZMYSQL_PASSWORD} \
						  -e AZKABAN_ADMIN=${AZMYSQL_USER} \
						  -e AZKABAN_ADMIN_PASSWORD=${AZMYSQL_PASSWORD} \
						  -e AZKABAN_METRICS_PASSWORD=${AZKABAN_METRICS} \
						  -v ${LOGDIR}:/opt/heading/azkaban-web/logs/ \
						  --name ${IMAGE}_${ENVNAME} ${DOCKERHUB}/${IMAGE}:${VERSION}) >/dev/null 2>&1
}

if [ "$ACTION" = "install" ]; then
	set -e
    get_ip
	get_exip
	azmysql_exist
	echo "Install azkaban-executor"
    echo "## Install begins : azkaban-executor"
	pull_azexecutor
	azexecutorimage_exist
	azexecutor_exist
    start_azexecutor
    if [ $? -ne 0 ]; then
		echo "Install failed..."
		exit 1
    fi
    echo "## Install ends   : azkaban-executor"

	echo "Install ${IMAGE}"
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
	
	echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT} or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}"
    echo "Username: ${AZMYSQL_USER} Password: ${AZMYSQL_PASSWORD}"
	echo "Done."
else
    echo "Unknown action ${ACTION}"
    exit 1
fi
