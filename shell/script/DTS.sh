###############################################################################
# File Name: DTS.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-dts-store}
VERSION=${VERSION:-1.13}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
WEBPORT=${WEBPORT:-18180}
DEPLOYDIR=${DEPLOYDIR:-data}
LOGDIR=${LOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}}
SHAREDIR=${SHAREDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/dts-store_${ENVNAME}/sharePath}
WORKDIR=${WORKDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/dts-store_${ENVNAME}/workPath}
EXTRANETHOST=${EXTRANETHOST:-192-168-251-5}
PROTOCOL=http
PFSPORT=${PFSPORT:-18280}
OLDORAURL=${OLDORAURL:-Orasvr:1521:DBInst}
NEWORAURL=${NEWORAURL:-192.168.251.4:1521:hdappts}
NEWORAUSER=${NEWORAUSER:-hd40}
NEWORAPWD=${NEWORAPWD:-yfrp4vh0bpwg}

#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long webport: -n 'DTS.sh' -- "$@"`
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
						 -p 9148:9148 \
					     -v ${LOGDIR}:/opt/heading/tomcat7/logs \
					     -v ${SHAREDIR}:/opt/dts-store/sharePath \
					     -v ${WORKDIR}:/opt/dts-store/workPath \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
					     --restart=on-failure:3 \
					     --log-opt max-size=50m \
					     -m 2g \
						 -e JAVA_OPTS="-server -Xms512m -Xmx2048m -XX:PermSize=256M -XX:MaxPermSize=512M -Duser.timezone=GMT+08 -Dfile.encoding=UTF-8 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9148 -Dcom.sun.management.jmxremote.rmi.port=9148 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=${INTRANETIP}" \
					     --name ${IMAGE}_${ENVNAME} ${DOCKERHUB}/${IMAGE}:${VERSION}) >/dev/null 2>&1
}

deploying_container() {

    ID=$(sudo docker exec \
						-e CEXTRANETIP="${EXTRANETIP}" \
						-e COLDORAURL="${OLDORAURL}" \
						-e CNEWORAURL="${NEWORAURL}" \
						-e CNEWORAUSER="${NEWORAUSER}" \
						-e CNEWORAPWD="${NEWORAPWD}" \
						-e CPFSPORT="${PFSPORT}" \
						-e CWEBPORT="${WEBPORT}" \
						${IMAGE}_${ENVNAME} sh -c '
												sed -i "
													s%\r$%%;\
													s%${COLDORAURL}%${CNEWORAURL}%;\
													s%yourusername%${CNEWORAUSER}%;\
													s%yourpassword%${CNEWORAPWD}%;\
													/store-core.data/s%#%%;\
													/jpaAdaptor/s%#%%;\
													/\.className/s%#%%;\
													/\.sharePath/{s%$%\/\/\/\/opt\/dts-store\/sharePath%;s%#%%};\
													/\.workPath/{s%$%\/\/\/\/opt\/dts-store\/workPath%;s%#%%};\
													/=ftp/{s%#%%;s%ftp%pfs%};\
													/pfsService/{s%$%http:\/\/${CEXTRANETIP}:${CPFSPORT}\/pfs-server\/remote\/pfs%;s%#%%};\
													/storeDBNotifyJob/s%#%%;\
													/storeDBTransportJob/s%#%%;\
													/serverAWareJob/s%#%%;\
													/standardVersion/{s%#%%;s%true%false%};\
													/sendAllEmp/{s%#%%;s%false%true%};\
													/sendEmpPassword/{s%#%%;s%false%true%};\
													/threadCount/{s%#%%;s%1%2%};\
													/storeDBservice/{s%#%%;s%2%3%};\
													/storeFilterSql/s%#%%;\
													/core.cleanup.cron/{s%#%%;s%0 0 2%0 0/60 *%}" /opt/heading/tomcat7/webapps/dts-store-server/WEB-INF/classes/d*.properties && \
												sed -i "
													s%\r$%%;\
													/logout/s%172.17.2.41%${CEXTRANETIP}:${CWEBPORT}%" /opt/heading/tomcat7/webapps/dts-store-web/WEB-INF/classes/d*.properties') >/dev/null 2>&1
}

cpout_config() {
    sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/dts-store-server/WEB-INF/classes/dts-store-server.properties ${ConfPath}
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/dts-store-web/WEB-INF/classes/dts-store-web.properties ${ConfPath}
}

cpin_config() {
    sudo docker cp ${ConfPath}/dts-store-server.properties ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/dts-store-server/WEB-INF/classes/
	sudo docker cp ${ConfPath}/dts-store-web.properties ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/dts-store-web/WEB-INF/classes/
}

if [ "${ACTION}" = "install" ]; then
	pro_install
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/${IMAGE}-web or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/${IMAGE}-web"
    echo "Username: guest Password: guest"
	echo "Done."
elif [ "${ACTION}" = "redeploy" ]; then
	pro_redeploy
	echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/${IMAGE}-web or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/${IMAGE}-web"
    echo "Username: guest Password: guest"
	echo "Done."
else
    echo "Unknown action ${ACTION}"
    exit 1
fi
