###############################################################################
# File Name: JCRM.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-jcrm-server-card}
VERSION=${VERSION:-2.0.17}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
WEBPORT=${WEBPORT:-38580}
DEPLOYDIR=${DEPLOYDIR:-data}
LOGDIR=${LOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}}
EXTRANETHOST=${EXTRANETHOST:-192-168-251-5}
PROTOCOL=http
CTMPORT=${CTMPORT:-1199}
CTPORT=${CTPORT:-28580}
NEWLIC=${NEWLIC:-172.17.2.24}

#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long webport: -n 'JCRM.sh' -- "$@"`
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
						 --link card_${ENVNAME}:card \
						 -p ${WEBPORT}:8080 \
						 -p 9348:9348 \
						 -v ${LOGDIR}:/opt/heading/tomcat7/logs \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
						 --restart=on-failure:3 \
						 --log-opt max-size=50m \
						 -m 1g \
						 -e JAVA_OPTS="-server -Xms512m -Xmx1024m -XX:PermSize=256M -XX:MaxPermSize=512M -Duser.timezone=GMT+08 -Dfile.encoding=UTF-8 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9348 -Dcom.sun.management.jmxremote.rmi.port=9348 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=${INTRANETIP}" \
						 --name ${IMAGE}_${ENVNAME} ${DOCKERHUB}/${IMAGE}:${VERSION}) >/dev/null 2>&1
}

start_zookeeper() {

    ID=$(docker run -d \
					-v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
					-p 2181:2181 \
					--name zookeeper_${ENVNAME} zookeeper) >/dev/null 2>&1
}

deploying_container() {

    ID=$(sudo docker exec \
						-e CEXTRANETIP="${EXTRANETIP}" \
						-e CNEWLIC="${NEWLIC}" \
						-e CCTMPORT="${CTMPORT}" \
						-e CCTPORT="${CTPORT}" \
						-e CWEBPORT="${WEBPORT}" \
						${IMAGE}_${ENVNAME} sh -c '
												sed -i "
													s%\r$%%;\
													s%127.0.0.1:1199%${CEXTRANETIP}:${CCTMPORT}%;\
													s%zookeeper:\/\/127.0.0.1:2181%zookeeper:\/\/${CEXTRANETIP}:2181%};\
													s%127.0.0.1:8088%${CNEWLIC}:8088%;\
													s%127.0.0.1:8180%${CEXTRANETIP}:${CCTPORT}%" /opt/heading/tomcat7/webapps/jcrm-server-card/WEB-INF/classes/jcrm-server-card.properties && \
												sed -i "
													s%\r$%%;\
													s%http:\/\/127.0.0.1:8081\/jcrm-server-crm\/rest%http:\/\/${CEXTRANETIP}:${CWEBPORT}\/jcrm-server-card\/rest%" /opt/heading/tomcat7/webapps/jcrm-rest-doc-server/WEB-INF/classes/jcrm-rest-doc-server.properties') >/dev/null 2>&1
}

cpout_config() {
    sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/jcrm-server-card/WEB-INF/classes/jcrm-server-card.properties ${ConfPath}
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/jcrm-rest-doc-server/WEB-INF/classes/jcrm-rest-doc-server.properties ${ConfPath}
}

cpin_config() {
    sudo docker cp ${ConfPath}/jcrm-rest-doc-server.properties ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/jcrm-rest-doc-server/WEB-INF/classes/
	sudo docker cp ${ConfPath}/jcrm-server-card.properties ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/jcrm-server-card/WEB-INF/classes/
}

if [ "${ACTION}" = "install" ]; then
	zk_exist
	pro_install
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
