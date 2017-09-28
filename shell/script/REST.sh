###############################################################################
# File Name: REST.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-h4rest}
VERSION=${VERSION:-1.21}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
WEBPORT=${WEBPORT:-18580}
DEPLOYDIR=${DEPLOYDIR:-data}
LOGDIR=${LOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}}
EXTRANETHOST=${EXTRANETHOST:-192-168-251-5}
PROTOCOL=http
PAYURL=${PAYURL:-https:\/\/api.u.hd123.com\/4y2n8u7j\/pay}
OLDORAURL=${OLDORAURL:-dev-orasvr-2:1521:DBINST1}
NEWORAURL=${NEWORAURL:-192.168.251.4:1521:hdappts}
NEWORAPWD=${NEWORAPWD:-yfrp4vh0bpwg}
NEWPAYUSER=${NEWPAYUSER:-guest}
NEWPAYPWD=${NEWPAYPWD:-guest}

#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long webport: -n 'REST.sh' -- "$@"`
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
						 -p 9648:9648 \
						 -v ${LOGDIR}:/opt/heading/tomcat7/logs \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
						 --restart=on-failure:3 \
						 --log-opt max-size=50m \
						 -m 1g \
						 -e JAVA_OPTS="-server -Xms512m -Xmx1024m -XX:PermSize=256M -XX:MaxPermSize=512M -Duser.timezone=GMT+08 -Dfile.encoding=UTF-8 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9648 -Dcom.sun.management.jmxremote.rmi.port=9648 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=${INTRANETIP}" \
						 --name ${IMAGE}_${ENVNAME} ${DOCKERHUB}/${IMAGE}:${VERSION}) >/dev/null 2>&1
}

deploying_container() {

    ID=$(sudo docker exec \
						-e CEXTRANETIP="${EXTRANETIP}" \
						-e COLDORAURL="${OLDORAURL}" \
						-e CNEWORAURL="${NEWORAURL}" \
						-e CNEWORAPWD="${NEWORAPWD}" \
						-e CNEWPAYUSER="${NEWPAYUSER}" \
						-e CNEWPAYPWD="${NEWPAYPWD}" \
						-e CPAYURL="${PAYURL}" \
						${IMAGE}_${ENVNAME} sh -c '
												sed -i  "
													s%\r$%%;\
													7,27{/h4rest-core/s%#%%;\
																	  s%${COLDORAURL}%${CNEWORAURL}%;\
																      s%password=hd40%password=${CNEWORAPWD}%};\
													172,193{/h4rest-core/s%#%%;\
																		 s%Username=guest%Username=${CNEWPAYUSER}%;\
																		 s%Password=guest%Password=${CNEWPAYPWD}%;\
																		 s%=false%=true%;\
																		 s%=https:\/\/api.u.hd123.com\/4y2n8u7j\/pay%=${CPAYURL}%}" /opt/heading/tomcat7/webapps/h4rest-server/WEB-INF/classes/h4rest-server.properties') >/dev/null 2>&1
}

cpout_config() {
    sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/h4rest-server/WEB-INF/classes/h4rest-server.properties ${ConfPath}
}

cpin_config() {
    sudo docker cp ${ConfPath}/h4rest-server.properties ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/h4rest-server/WEB-INF/classes/
}

if [ "${ACTION}" = "install" ]; then
	pro_install
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/${IMAGE}-server or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/${IMAGE}-server"
	echo "Done."
elif [ "${ACTION}" = "redeploy" ]; then
	pro_redeploy
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/${IMAGE}-server or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/${IMAGE}-server"
	echo "Done."
else
    echo "Unknown action ${ACTION}"
    exit 1
fi
