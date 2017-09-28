###############################################################################
# File Name: PASOREPORT.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-pasoreport-web}
VERSION=${VERSION:-1.0}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
PREFIX=${PREFIX:-pasoreport}
WEBPORT=${WEBPORT:-8080}
PAMYSQLPORT=${PAMYSQLPORT:-3306}
PAREDISPORT=${PAREDISPORT:-6379}
DEPLOYDIR=${DEPLOYDIR:-data}
LOGDIR=${LOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}}
FILEDIR=${FILEDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/pasoreport_${ENVNAME}/Enclosure}
PAMYSQLDATADIR=${PAMYSQLDATADIR:-/${DEPLOYDIR}/heading/${ENVNAME}/pasoreport_${ENVNAME}/mysqldata}
PAREDISDATADIR=${PAREDISDATADIR:-/${DEPLOYDIR}/heading/${ENVNAME}/pasoreport_${ENVNAME}/redisdata}
PAMYSQL_ROOT_PASSWORD=${PAMYSQL_ROOT_PASSWORD:-hG4uWDsgcHmvyte4}
PAMYSQL_DATABASE=${PAMYSQL_DATABASE:-pasoreport}
PAMYSQL_USER=${PAMYSQL_USER:-pasoreport}
PAMYSQL_PASSWORD=${PAMYSQL_PASSWORD:-hG4uWDsgcHmvyte4}
LINKMYSQL={LINKMYSQL:mysqlurl}
LINKREDIS={LINKREDIS:redisurl}
PROTOCOL=http
EXTRANETHOST=${EXTRANETHOST:-192-168-251-5}


#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long webport: -n 'PASOREPORT.sh' -- "$@"`
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

start_pamysql() {

    ID=$(sudo docker run -d \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
						 -e MYSQL_ROOT_PASSWORD=${PAMYSQL_ROOT_PASSWORD} \
						 -e MYSQL_DATABASE=${PAMYSQL_DATABASE} \
						 -e MYSQL_USER=${PAMYSQL_USER} \
						 -e MYSQL_PASSWORD=${PAMYSQL_PASSWORD} \
						 -p ${PAMYSQLPORT}:3306 \
						 -v ${PAMYSQLDATADIR}:/var/lib/mysql \
						 --name ${PREFIX}-mysql_${ENVNAME} \
						 ${DOCKERHUB}/${PREFIX}-mysql:5.6 \
						 --character-set-server=utf8 --collation-server=utf8_general_ci) >/dev/null 2>&1
}

start_paredis() {

    ID=$(sudo docker run -d \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
						 -p ${PAREDISPORT}:6379 \
						 -v ${PAREDISDATADIR}:/data \
						 --name ${PREFIX}-redis_${ENVNAME} \
						 ${DOCKERHUB}/${PREFIX}-redis:2.8) >/dev/null 2>&1
}

start_container() {

    ID=$(sudo docker run -d \
						 --link ${PREFIX}-mysql_${ENVNAME}:mysqlurl \
						 --link ${PREFIX}-redis_${ENVNAME}:redisurl \
						 -p ${WEBPORT}:8080 \
						 -v ${LOGDIR}:/apache-tomcat/logs \
						 -v ${FILEDIR}:/opt/heading/Enclosure \
						 --restart=on-failure:3 \
						 --log-opt max-size=50m \
						 -m 1g \
						 --name ${IMAGE}_${ENVNAME} ${DOCKERHUB}/${IMAGE}:${VERSION}) >/dev/null 2>&1
}

deploying_container() {

    ID=$(sudo docker exec \
						${IMAGE}_${ENVNAME} sh -c '
												sed -i "
													s%\r$%%;\
													/Encryption/{s%#%%;\
																 s%md5%hdpos4%}" /apache-tomcat/webapps/pasoreport-web/WEB-INF/classes/pasoreport-web.properties') >/dev/null 2>&1
}

cpout_config() {
    sudo docker cp ${IMAGE}_${ENVNAME}:/apache-tomcat/webapps/pasoreport-web/WEB-INF/classes/pasoreport-web.properties ${ConfPath}
}

cpin_config() {
    sudo docker cp ${ConfPath}/pasoreport-web.properties ${IMAGE}_${ENVNAME}:/apache-tomcat/webapps/pasoreport-web/WEB-INF/classes/
}

if [ "$ACTION" = "install" ]; then
	set -e
    get_ip
	get_exip
    pull_image
	image_exist
    pamysql_exist
    paredis_exist
	container_exist
	
	echo "Install and deploying ${IMAGE}"
    echo "## Install begins : ${IMAGE}"
    start_container
    if [ $? -ne 0 ]; then
		echo "Install failed..."
		exit 1
    fi
    echo "## Install ends   : ${IMAGE}"
	sleep 15
	echo "## deploying begins : ${IMAGE}"
    deploying_container
    if [ $? -ne 0 ]; then
		echo "deploying failed..."
		exit 1
    fi
    echo "## deploying ends   : ${IMAGE}"
	
	sleep 10
	echo "Restart ${IMAGE}"
	restart_container
	cpout_config

	echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/${IMAGE} or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/${IMAGE}"
    echo "Username: admin Password: 123456"
	echo "Done."
elif [ "${ACTION}" = "redeploy" ]; then
	pro_redeploy
	echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/${IMAGE} or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/${IMAGE}"
    echo "Username: admin Password: 123456"
	echo "Done."	
else
    echo "Unknown action ${ACTION}"
    exit 1
fi
