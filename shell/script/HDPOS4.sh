###############################################################################
# File Name: HDPOS4.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-hdpos4-dist}
VERSION=${VERSION:-1.0-SNAPSHOT}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
WEBPORT=${WEBPORT:-18380}
DEPLOYDIR=${DEPLOYDIR:-data}
LOGDIR=${LOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}}
FILEDIR=${FILEDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/hdpos4_${ENVNAME}/Enclosure}
EXTRANETHOST=${EXTRANETHOST:-192-168-251-5}
PROTOCOL=http
OLDORAURL=${OLDORAURL:-localhost:1521:orcl}
NEWORAURL=${NEWORAURL:-192.168.251.4:1521:hdappts}
NEWORAUSER=${NEWORAUSER:-hd40}
NEWORAPWD=${NEWORAPWD:-yfrp4vh0bpwg}

#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long webport: -n 'HDPOS4.sh' -- "$@"`
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
						 -p 9548:9548 \
					     -v ${LOGDIR}:/opt/heading/tomcat7/logs \
						 -v ${FILEDIR}:/opt/heading/Enclosure \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
					     --restart=on-failure:3 \
					     --log-opt max-size=50m \
					     -m 2g \
						 -e JAVA_OPTS="-server -Xms1024m -Xmx2048m -XX:PermSize=256M -XX:MaxPermSize=512M -Duser.timezone=GMT+08 -Dfile.encoding=UTF-8 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9548 -Dcom.sun.management.jmxremote.rmi.port=9548 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=${INTRANETIP}" \
					     --name ${IMAGE}_${ENVNAME} ${DOCKERHUB}/${IMAGE}:${VERSION}) >/dev/null 2>&1
}

deploying_container() {

    ID=$(sudo docker exec \
						-e COLDORAURL="${OLDORAURL}" \
						-e CNEWORAURL="${NEWORAURL}" \
						-e CNEWORAUSER="${NEWORAUSER}" \
						-e CNEWORAPWD="${NEWORAPWD}" \
						${IMAGE}_${ENVNAME} sh -c '
												sed -i  "
													s%\r$%%;\
													53,74{/hdpos4-core/s%#%%;\
																	   s%${COLDORAURL}%${CNEWORAURL}%;\
																	   s%password=hdpos4%password=${CNEWORAPWD}%;\
																	   s%username=hdpos4%username=${CNEWORAUSER}%;\
																	   s%default_schema=hdpos4%default_schema=${CNEWORAUSER}%};\
													130,145{/rumba-quartz-core/s%#%%;\
																               s%${COLDORAURL}%${CNEWORAURL}%;\
																			   s%password=hdpos4%password=${CNEWORAPWD}%;\
																			   s%username=hdpos4%username=${CNEWORAUSER}%};\
													151,158{/rumba-commons-prefs/s%#%%;\
																                 s%${COLDORAURL}%${CNEWORAURL}%;\
																                 s%password=hd40%password=${CNEWORAPWD}%};\
													s%autoUpdate=false%autoUpdate=true%" /opt/heading/tomcat7/webapps/hdpos4-web/WEB-INF/classes/hdpos4-web.properties') >/dev/null 2>&1
}

cpout_config() {
    sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/hdpos4-web/WEB-INF/classes/hdpos4-web.properties ${ConfPath}
}

cpin_config() {
    sudo docker cp ${ConfPath}/hdpos4-web.properties ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/hdpos4-web/WEB-INF/classes/
}

if [ "${ACTION}" = "install" ]; then
	pro_install
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/hdpos4-web or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/hdpos4-web"
	echo "Done."
elif [ "${ACTION}" = "redeploy" ]; then
	pro_redeploy
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/hdpos4-web or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/hdpos4-web"
	echo "Done."
else
    echo "Unknown action ${ACTION}"
    exit 1
fi
