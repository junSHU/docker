###############################################################################
# File Name: OTTER.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-otter-r3-std}
VERSION=${VERSION:-1.38}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
WEBPORT=${WEBPORT:-18480}
DEPLOYDIR=${DEPLOYDIR:-data}
LOGDIR=${LOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}}
EXTRANETHOST=${EXTRANETHOST:-192-168-251-5}
PROTOCOL=http
OLDLIC=${OLDLIC:-172.17.2.24}
NEWLIC=${NEWLIC:-192.168.251.8}
OLDORAURL=${OLDORAURL:-172.17.12.9:1521:pos4stanew}
NEWORAURL=${NEWORAURL:-192.168.251.4:1521:hdappts}
OLDORAPWD=${OLDORAPWD:-hd40}
NEWORAPWD=${NEWORAPWD:-yfrp4vh0bpwg}

#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long webport: -n 'OTTER.sh' -- "$@"`
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
						 -p ${WEBPORT}:8080 \
						 -p 9448:9448 \
						 -p 1098:1098 \
						 -v ${LOGDIR}:/opt/heading/jboss/server/default/log \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
						 --restart=on-failure:3 \
						 --log-opt max-size=50m \
						 -m 1g \
						 -e JAVA_OPTS="-Xms512M -Xmx1024M -Xss256K -XX:PermSize=256m -XX:MaxPermSize=256m -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9448 -Dcom.sun.management.jmxremote.rmi.port=9448 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=${INTRANETIP}" \
						 --name ${IMAGE}_${ENVNAME} ${DOCKERHUB}/${IMAGE}:${VERSION}) >/dev/null 2>&1
}

deploying_container() {

    ID=$(sudo docker exec \
						-e COLDLIC="${OLDLIC}" \
						-e CNEWLIC="${NEWLIC}" \
						-e COLDORAURL="${OLDORAURL}" \
						-e CNEWORAURL="${NEWORAURL}" \
						-e COLDORAPWD="${OLDORAPWD}" \
						-e CNEWORAPWD="${NEWORAPWD}" \
						${IMAGE}_${ENVNAME} sh -c '
												sed -i "
													s%\r$%%;\
													s%${COLDORAURL}%${CNEWORAURL}%;\
													/password/s%${COLDORAPWD}%${CNEWORAPWD}%;\
													28s%${COLDORAPWD}%${CNEWORAPWD}%" /opt/heading/jboss/server/default/deploy/otter-oracle-xa-ds.xml && \
												sed -i "
													s%\r$%%;\
													s%${COLDORAURL}%${CNEWORAURL}%;\
													/password/s%${COLDORAPWD}%${CNEWORAPWD}%;\
													16s%${COLDORAPWD}%${CNEWORAPWD}%" /opt/heading/jboss/server/default/deploy/quartz-xa-ds.xml && \
												sed -i "
													s%\r$%%;\
													s%${COLDORAURL}%${CNEWORAURL}%;\
													29s%${COLDORAPWD}%${CNEWORAPWD}%;\
													68s%${COLDORAPWD}%${CNEWORAPWD}%;\
													121s%${COLDORAPWD}%${CNEWORAPWD}%;\
													175s%${COLDORAPWD}%${CNEWORAPWD}%" /opt/heading/jboss/server/default/deploy/OTTER.war/WEB-INF/classes/myrumba.xml && \
												sed -i "
													s%\r$%%;\
													s%=${COLDLIC}%=${CNEWLIC}%" /opt/heading/jboss/server/default/deploy/OTTER.war/WEB-INF/classes/com/hd123/rumba/rumba.properties && \
												sed -i "
													s%\r$%%;\
													s%quieeWindowServer.lic%quieeLinuxServer.lic%" /opt/heading/jboss/server/default/deploy/OTTER.war/WEB-INF/reportConfig.xml') >/dev/null 2>&1
}

cpout_config() {
    sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/jboss/server/default/deploy/OTTER.war/WEB-INF/reportConfig.xml ${ConfPath}
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/jboss/server/default/deploy/otter-oracle-xa-ds.xml ${ConfPath}
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/jboss/server/default/deploy/quartz-xa-ds.xml ${ConfPath}
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/jboss/server/default/deploy/OTTER.war/WEB-INF/classes/com/hd123/rumba/rumba.properties ${ConfPath}
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/jboss/server/default/deploy/OTTER.war/WEB-INF/classes/myrumba.xml ${ConfPath}
}

cpin_config() {
    sudo docker cp ${ConfPath}/reportConfig.xml ${IMAGE}_${ENVNAME}:/opt/heading/jboss/server/default/deploy/OTTER.war/WEB-INF/
	sudo docker cp ${ConfPath}/otter-oracle-xa-ds.xml ${IMAGE}_${ENVNAME}:/opt/heading/jboss/server/default/deploy/
	sudo docker cp ${ConfPath}/quartz-xa-ds.xml ${IMAGE}_${ENVNAME}:/opt/heading/jboss/server/default/deploy/
	sudo docker cp ${ConfPath}/rumba.properties ${IMAGE}_${ENVNAME}:/opt/heading/jboss/server/default/deploy/OTTER.war/WEB-INF/classes/com/hd123/rumba/
	sudo docker cp ${ConfPath}/myrumba.xml ${IMAGE}_${ENVNAME}:/opt/heading/jboss/server/default/deploy/OTTER.war/WEB-INF/classes/
}

if [ "${ACTION}" = "install" ]; then
    pro_install
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/OTTER or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/OTTER"
	echo "Done."
elif [ "${ACTION}" = "redeploy" ]; then
	pro_redeploy
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/OTTER or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/OTTER"
	echo "Done."
else
    echo "Unknown action ${ACTION}"
    exit 1
fi
