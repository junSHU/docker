###############################################################################
# File Name: PFS.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-pfs}
VERSION=${VERSION:-2.6}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
WEBPORT=${WEBPORT:-18280}
DEPLOYDIR=${DEPLOYDIR:-data}
LOGDIR=${LOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}}
SHAREDIR=${SHAREDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/dts-store_${ENVNAME}/sharePath}
WORKDIR=${WORKDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/dts-store_${ENVNAME}/workPath}
FTPDIR=${FTPDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/pfs_${ENVNAME}/ftp}
EXTRANETHOST=${EXTRANETHOST:-192-168-251-5}
PROTOCOL=http
DTSPORT=${DTSPORT:-18180}
PFSPORT=${PFSPORT:-18280}
OLDORAURL=${OLDORAURL:-172.17.12.9:1521:pos4stanew}
NEWORAURL=${NEWORAURL:-192.168.251.4:1521:hdappts}
OLDPFSUSER=${OLDPFSUSER:-pfs}
NEWPFSUSER=${NEWPFSUSER:-pfs}
OLDPFSPWD=${OLDPFSPWD:-pfs}
NEWPFSPWD=${NEWPFSPWD:-5p4f3s2}

#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long webport: -n 'PFS.sh' -- "$@"`
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
						 -p 9248:9248 \
						 -v ${LOGDIR}:/opt/heading/tomcat7/logs \
						 -v ${SHAREDIR}:/opt/dts-store/sharePath \
						 -v ${WORKDIR}:/opt/dts-store/workPath \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
						 -v ${FTPDIR}:/opt/ftp \
						 --restart=on-failure:3 \
						 --log-opt max-size=50m \
						 -m 1g \
						 -e JAVA_OPTS="-server -Xms512m -Xmx1024m -XX:PermSize=256M -XX:MaxPermSize=512M -Duser.timezone=GMT+08 -Dfile.encoding=UTF-8 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9248 -Dcom.sun.management.jmxremote.rmi.port=9248 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=${INTRANETIP}" \
						 --name ${IMAGE}_${ENVNAME} ${DOCKERHUB}/${IMAGE}:${VERSION}) >/dev/null 2>&1
}

deploying_container() {

    ID=$(sudo docker exec \
						-e CEXTRANETIP="${EXTRANETIP}" \
						-e COLDORAURL="${OLDORAURL}" \
						-e CNEWORAURL="${NEWORAURL}" \
						-e COLDPFSPWD="${OLDPFSPWD}" \
						-e CNEWPFSPWD="${NEWPFSPWD}" \
						-e COLDPFSUSER="${OLDPFSUSER}" \
						-e CNEWPFSUSER="${NEWPFSUSER}" \
						-e CPFSPORT="${PFSPORT}" \
						-e CDTSPORT="${DTSPORT}" \
						${IMAGE}_${ENVNAME} sh -c '
												sed -i "
													s%\r$%%;\
													s%${COLDORAURL}%${CNEWORAURL}%;\
													/username/s%=${COLDPFSUSER}%=${CNEWPFSUSER}%;\
													/password/s%=${COLDPFSPWD}%=${CNEWPFSPWD}%;\
													/url.1/s%$%http:\/\/${CEXTRANETIP}:${CPFSPORT}\/pfs-server\/download%;\
													/ftpSharedUnc/s%c:\/\/temp\/\/pfs\/\/ftp%\/opt\/ftp%;\
													/enabled/s%false%true%;\
													/server.url/s%$%http:\/\/${CEXTRANETIP}:${CDTSPORT}\/dts-store-server%;\
													s%yourapp-name%guest%;\
													s%yourapp-password%guest%" /opt/heading/tomcat7/webapps/pfs-server/WEB-INF/classes/p*.properties') >/dev/null 2>&1
}

cpout_config() {
    sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/pfs-server/WEB-INF/classes/pfs-server.properties ${ConfPath}
}

cpin_config() {
    sudo docker cp ${ConfPath}/pfs-server.properties ${IMAGE}_${ENVNAME}:/opt/heading/tomcat7/webapps/pfs-server/WEB-INF/classes/
}

if [ "${ACTION}" = "install" ]; then
	pro_install
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/${IMAGE}-server or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/${IMAGE}-server"
    echo "Username: pfs Password: pfs"
	echo "Done."
elif [ "${ACTION}" = "redeploy" ]; then
	pro_redeploy
    echo "${IMAGE} available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/${IMAGE}-server or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/${IMAGE}-server"
    echo "Username: pfs Password: pfs"
	echo "Done."
else
    echo "Unknown action ${ACTION}"
    exit 1
fi
