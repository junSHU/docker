###############################################################################
# File Name: JPOSBO.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-jposbo}
VERSION=${VERSION:-ncyj_2017042_pro}
MYSQLVERSION=${MYSQLVERSION:-5.7.14}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
WEBPORT=${WEBPORT:-18680}
DEPLOYDIR=${DEPLOYDIR:-data}
LOGDIR=${LOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}}
#TOOLSDIR=${TOOLSDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/tools_${IMAGE}_${ENVNAME}}
#TOOLSURL=${TOOLSURL:-http://download.hd123.com/TmpFiles/TA/20170522}
PRINTDIR=${PRINTDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/print_${IMAGE}_${ENVNAME}}
EXTRANETHOST=${EXTRANETHOST:-192-168-251-5}
PROTOCOL=http
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-root}
MYSQL_DATABASE=${MYSQL_DATABASE:-jposbo}
MYSQL_USER=${MYSQL_USER:-headingjpos}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-headingjpos}
MYSQLPORT=${MYSQLPORT:-3306}
MYSQLDATADIR=${MYSQLDATADIR:-/${DEPLOYDIR}/heading/${ENVNAME}/jposbo_mysql_${ENVNAME}/data}
MYSQLCONFDIR=${MYSQLCONFDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/jposbo_mysql_${ENVNAME}/conf}
OLDMYSQL_PASSWORD=${OLDMYSQL_PASSWORD:-myN3wPassw0rd}
OLDORAURL=${OLDORAURL:-172.17.12.9:1521:pos4stanew}
NEWORAURL=${NEWORAURL:-192.168.251.4:1521:hdappts}
OLDORAPWD=${OLDORAPWD:-hd40}
NEWORAPWD=${NEWORAPWD:-yfrp4vh0bpwg}
OLDOTTERURL=${OLDOTTERURL:-172.17.2.41:8580}
OTTERPORT=${OTTERPORT:-18480}
OLDPFSURL=${OLDPFSURL:-172.17.2.41:8680}
PFSPORT=${PFSPORT:-18280}
OLDLIC=${OLDLIC:-172.17.2.24}
NEWLIC=${NEWLIC:-192.168.251.8}


#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long webport: -n 'JPOSBO.sh' -- "$@"`
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
			shift 2 
			;;
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

start_container() {

    ID=$(sudo docker run -d \
					     --add-host ${HOSTNAME}:${INTRANETIP} \
					     --add-host ${EXTRANETHOST}:${EXTRANETIP} \
						 -e JPOSBO_MYSQL_HOST=${INTRANETIP} \
						 -e JPOSBO_MYSQL_PORT=${MYSQLPORT} \
						 -e JPOSBO_MYSQL_USER=${MYSQL_USER} \
						 -e JPOSBO_MYSQL_PASSWORD=${MYSQL_PASSWORD} \
					     -p ${WEBPORT}:8080 \
						 -p 10001:10001 \
						 -p 10002:10002 \
						 -v ${LOGDIR}:/opt/heading/tomcat6/logs \
						 -v ${PRINTDIR}:/opt/heading/tomcat6/webapps/jposbo/WEB-INF/hdhome/jpos/data/template/print \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
						 --restart=on-failure:3 \
						 --log-opt max-size=50m \
						 -m 4g \
						 --name ${IMAGE}_${ENVNAME} ${DOCKERHUB}/${IMAGE}:${VERSION}) >/dev/null 2>&1
}

start_mysql() {

    ID=$(sudo docker run -d \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
						 -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
						 -e MYSQL_DATABASE=${MYSQL_DATABASE} \
						 -e MYSQL_USER=${MYSQL_USER} \
					         --restart=always \
						 -e MYSQL_PASSWORD=${MYSQL_PASSWORD} \
						 -p ${MYSQLPORT}:3306 \
						 -v ${MYSQLDATADIR}:/var/lib/mysql \
						 -v ${MYSQLCONFDIR}:/etc/mysql/conf.d \
						 --name mysql_${ENVNAME} ${DOCKERHUB}/mysql:${MYSQLVERSION} \
						 --character-set-server=gbk --collation-server=gbk_chinese_ci) >/dev/null 2>&1
}

deploying_container() {

    ID=$(sudo docker exec \
						-e CHOSTNAME="${HOSTNAME}" \
						-e CEXTRANETIP="${EXTRANETIP}" \
						-e CMYSQL_DATABASE="${MYSQL_DATABASE}" \
						-e CMYSQL_USER="${MYSQL_USER}" \
						-e CMYSQL_PASSWORD="${MYSQL_PASSWORD}" \
						-e COLDORAURL="${OLDORAURL}" \
						-e CNEWORAURL="${NEWORAURL}" \
						-e COLDORAPWD="${OLDORAPWD}" \
						-e CNEWORAPWD="${NEWORAPWD}" \
						-e COLDMYSQL_PASSWORD="${OLDMYSQL_PASSWORD}" \
						-e COLDMYSQL_URL="${OLDMYSQL_URL}" \
						-e COLDOTTERURL="${OLDOTTERURL}" \
						-e CNEWOTTERPORT="${OTTERPORT}" \
						-e COLDPFSURL="${OLDPFSURL}" \
						-e CNEWPFSPORT="${PFSPORT}" \
						-e COLDLIC="${OLDLIC}" \
						-e CNEWLIC="${NEWLIC}" \
						-e CMYSQLPORT="${MYSQLPORT}" \
						${IMAGE}_${ENVNAME} sh -c '
												sed -i "
													s%\r$%%;\
													/mysql/{s%${COLDMYSQL_URL}%${CHOSTNAME}:${CMYSQLPORT}\/${CMYSQL_DATABASE}%;s%root%${CMYSQL_USER}%;s%${COLDMYSQL_PASSWORD}%${CMYSQL_PASSWORD}%};\
													s%${COLDORAURL}%${CNEWORAURL}%;\
													/password/s%${COLDORAPWD}%${CNEWORAPWD}%;\
													s%${COLDOTTERURL}%${CEXTRANETIP}:${CNEWOTTERPORT}%" /opt/heading/tomcat6/webapps/jposbo/WEB-INF/datasource.xml && \
												sed -i "
													s%\r$%%;\
													/pfs-server/s%${COLDPFSURL}%${CEXTRANETIP}:${CNEWPFSPORT}%;\
													/OTTER/s%${COLDOTTERURL}%${CEXTRANETIP}:${CNEWOTTERPORT}%" /opt/heading/tomcat6/webapps/jposbo/WEB-INF/hdhome/jpos/conf/posboSettings.xml && \
												sed -i "
													s%\r$%%;\
													s%${COLDLIC}%${CNEWLIC}%" /opt/heading/tomcat6/webapps/jposbo/WEB-INF/hdhome/jpos/HDLicense.properties') > /dev/null 2>&1
}

cpout_config() {
    sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/tomcat6/webapps/jposbo/WEB-INF/hdhome/jpos/conf/posboSettings.xml ${ConfPath}
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/tomcat6/webapps/jposbo/WEB-INF/hdhome/jpos/HDLicense.properties ${ConfPath}
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/tomcat6/webapps/jposbo/WEB-INF/datasource.xml ${ConfPath}
}

cpin_config() {
    sudo docker cp ${ConfPath}/posboSettings.xml ${IMAGE}_${ENVNAME}:/opt/heading/tomcat6/webapps/jposbo/WEB-INF/hdhome/jpos/conf/
	sudo docker cp ${ConfPath}/HDLicense.properties ${IMAGE}_${ENVNAME}:/opt/heading/tomcat6/webapps/jposbo/WEB-INF/hdhome/jpos/
	sudo docker cp ${ConfPath}/datasource.xml ${IMAGE}_${ENVNAME}:/opt/heading/tomcat6/webapps/jposbo/WEB-INF/
}

download_zip() {
	set -e
	[ -f ${TOOLSDIR}/jdk-6u21-windows-i586.exe ] && return 0 || wget -P ${TOOLSDIR} ${TOOLSURL}/jdk-6u21-windows-i586.exe
	[ -f ${TOOLSDIR}/jdk-6u20-linux-i586.bin ] && return 0 || wget -P ${TOOLSDIR} ${TOOLSURL}/jdk-6u20-linux-i586.bin
}

if [ "${ACTION}" = "install" ]; then
    set -e
    get_ip
	get_exip
    pull_image
	image_exist
    mysql_exist
	container_exist
	
	echo "Install and deploying ${IMAGE}"
    echo "## Install begins : ${IMAGE}"
    start_container
    if [ $? -ne 0 ]; then
		echo "Install failed..."
		exit 1
    fi
    echo "## Install ends   : ${IMAGE}"
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
	sleep 30
    restart_container
	cpout_config
	#download_zip
	
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/${IMAGE} or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/${IMAGE}"
	echo "Done."
elif [ "${ACTION}" = "redeploy" ]; then
	pro_redeploy
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/${IMAGE} or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/${IMAGE}"
	echo "Done."
else
    echo "Unknown action ${ACTION}"
    exit 1
fi
