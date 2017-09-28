###############################################################################
# File Name: CARD.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-card}
VERSION=${VERSION:-3.48}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
HQPORT=${HQPORT:-28480}
CTPORT=${CTPORT:-28580}
CSPORT=${CSPORT:-28680}
HQMPORT=${HQMPORT:-1299}
CTMPORT=${CTMPORT:-1199}
DEPLOYDIR=${DEPLOYDIR:-data}
HQLOGDIR=${HQLOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}-hq}
CTLOGDIR=${CTLOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}-ct}
CSLOGDIR=${CSLOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}-cs}
UPGRADEDIR=${UPGRADEDIR:-/opt/heading/hdcard/${ENVNAME}}
EXTRANETHOST=${EXTRANETHOST:-192-168-251-5}
PROTOCOL=http
OLDLIC=${OLDLIC:-127.0.0.1}
NEWLIC=${NEWLIC:-172.17.2.24}
OLDCARDORAURLN=${OLDCARDORAURLN:-172.17.11.254:1521:HDCARDN}
NEWCARDORAURLN=${NEWCARDORAURLN:-192.168.251.4:1521:HDCARDN}
OLDCARDORAURLS=${OLDCARDORAURLS:-172.17.11.254:1521:HDCARDS}
NEWCARDORAURLS=${NEWCARDORAURLS:-192.168.251.4:1521:HDCARDS}
OLDCARDCTS=${OLDCARDCTS:-hdcardcts}
NEWCARDCTS=${NEWCARDCTS:-hdcardcts7}
OLDCARDCTN=${OLDCARDCTN:-hdcardctn}
NEWCARDCTN=${NEWCARDCTN:-hdcardctn7}
OLDCARDHQS=${OLDCARDHQS:-hdcardhqs}
NEWCARDHQS=${NEWCARDHQS:-hdcardhqs7}
OLDCARDHQN=${OLDCARDHQN:-hdcardhqn}
NEWCARDHQN=${NEWCARDHQN:-hdcardhqn7}
OLDVER=${OLDVER:-34}
NEWVER=${NEWVER:-45}


#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long hqport:,ctport:,hqmport:,ctmport:,csport: -n 'CARD.sh' -- "$@"`
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
		--hqport)
      		HQPORT="$2"; 
			shift 2 
			;;
        --ctport)
      		CTPORT="$2"; 
			shift 2 
			;;
		--hqmport)
      		HQMPORT="$2"; 
			shift 2 
			;;
        --ctmport)
      		CTMPORT="$2"; 
			shift 2 
			;;
		--csport)
      		CSPORT="$2"; 
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
					     --restart=on-failure:3 \
					     --log-opt max-size=50m \
					     -m 6g \
					     -p ${CTPORT}:8180 \
					     -p ${HQPORT}:8280 \
						 -p ${CSPORT}:8380 \
						 -p ${CTMPORT}:1199 \
						 -p ${HQMPORT}:1299 \
					     -v ${HQLOGDIR}:/opt/heading/hq/server/default/log \
					     -v ${CTLOGDIR}:/opt/heading/ct/server/default/log \
						 -v ${CSLOGDIR}:/opt/heading/cs/server/default/log \
					     -v ${UPGRADEDIR}:/opt/heading/upgrade/log \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
					     --privileged=true \
					     --name ${IMAGE}_${ENVNAME} ${DOCKERHUB}/${IMAGE}:${VERSION}) >/dev/null 2>&1
}

deploying_container() {

    ID=$(sudo docker exec \
						-e COLDLIC="${OLDLIC}" \
						-e CNEWLIC="${NEWLIC}" \
						-e COLDCARDORAURLN="${OLDCARDORAURLN}" \
						-e CNEWCARDORAURLN="${NEWCARDORAURLN}" \
						-e COLDCARDORAURLS="${OLDCARDORAURLS}" \
						-e CNEWCARDORAURLS="${NEWCARDORAURLS}" \
						-e COLDCARDCTS="${OLDCARDCTS}" \
						-e CNEWCARDCTS="${NEWCARDCTS}" \
						-e COLDCARDCTN="${OLDCARDCTN}" \
						-e CNEWCARDCTN="${NEWCARDCTN}" \
						-e COLDCARDHQS="${OLDCARDHQS}" \
						-e CNEWCARDHQS="${NEWCARDHQS}" \
						-e COLDCARDHQN="${OLDCARDHQN}" \
						-e CNEWCARDHQN="${NEWCARDHQN}" \
						-e COLDVER="${OLDVER}" \
						-e CNEWVER="${NEWVER}" \
						${IMAGE}_${ENVNAME} sh -c '
												sed -i "
													s%\r$%%;\
													s%${COLDCARDORAURLN}%${CNEWCARDORAURLN}%;\
													s%${COLDCARDORAURLS}%${CNEWCARDORAURLS}%;\
													s%${COLDCARDCTS}%${CNEWCARDCTS}%;\
													s%${COLDCARDCTN}%${CNEWCARDCTN}%" /opt/heading/ct/server/default/deploy/hdcard-xa-ds.xml && \
												sed -i "
													s%\r$%%;\
													s%${COLDCARDORAURLN}%${CNEWCARDORAURLN}%;\
													s%${COLDCARDORAURLS}%${CNEWCARDORAURLS}%;\
													s%${COLDCARDHQS}%${CNEWCARDHQS}%;\
													s%${COLDCARDHQN}%${CNEWCARDHQN}%" /opt/heading/hq/server/default/deploy/hdcard-xa-ds.xml && \
												sed -i "
													s%\r$%%;\
													s%${COLDLIC}%${CNEWLIC}%" /opt/heading/ct/server/default/deploy/card.war/WEB-INF/web.xml && \
												sed -i "
													s%\r$%%;\
													s%${COLDLIC}%${CNEWLIC}%" /opt/heading/ct/server/default/deploy/cardserver.war/WEB-INF/web.xml && \
												sed -i "
													s%\r$%%;\
													s%${COLDLIC}%${CNEWLIC}%" /opt/heading/hq/server/default/deploy/card.war/WEB-INF/web.xml && \
												sed -i "
													s%\r$%%;\
													s%${COLDCARDORAURLN}%${CNEWCARDORAURLN}%;\
													s%${COLDCARDORAURLS}%${CNEWCARDORAURLS}%;\
													s%${COLDCARDCTS}%${CNEWCARDCTS}%;\
													s%${COLDCARDCTN}%${CNEWCARDCTN}%" /opt/heading/cs/server/default/deploy/hdcard-xa-ds.xml && \
												sed -i "
													s%\r$%%;\
													s%${COLDLIC}%${CNEWLIC}%" /opt/heading/cs/server/default/deploy/cardserver.war/WEB-INF/web.xml && \
												sed -i "
													s%\r$%%;\
													s%${COLDVER}%${CNEWVER}%g" /opt/heading/upgrade/rumba-upgrader-3.3.8/bin/upgrade_env.sh') >/dev/null 2>&1
}

upgrade_card() {

    ID=$(sudo docker exec ${IMAGE}_${ENVNAME} sh -c 'sh /opt/heading/upgrade/rumba-upgrader-3.3.8/bin/hdcard_upgrade.sh') >/dev/null 2>&1
}

cpout_config() {
    sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/hq/server/default/deploy/card.war/WEB-INF/web.xml ${ConfPath}/hq
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/hq/server/default/deploy/hdcard-xa-ds.xml ${ConfPath}/hq
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/hq/server/default/deploy/hdcard-ejb-ear.ear/hdcard-ejb-user.jar/custommade/appOptions.xml ${ConfPath}/hq
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/hq/server/default/conf/rumba-rt.xml ${ConfPath}/hq
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/ct/server/default/conf/rumba-rt.xml ${ConfPath}/ct
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/ct/server/default/deploy/hdcard-ejb-ear.ear/hdcard-ejb-user.jar/custommade/appOptions.xml ${ConfPath}/ct
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/ct/server/default/deploy/cardserver.war/WEB-INF/web.xml ${ConfPath}/ct
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/ct/server/default/deploy/card.war/WEB-INF/web.xml ${ConfPath}/ct
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/ct/server/default/deploy/hdcard-xa-ds.xml ${ConfPath}/ct
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/cardserver.war/WEB-INF/web.xml ${ConfPath}/cs
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/hdcard-xa-ds.xml ${ConfPath}/cs
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/hdcard-ejb-ear.ear/hdcard-ejb-user.jar/custommade/appOptions.xml ${ConfPath}/cs
}

cpin_config() {
    sudo docker cp ${ConfPath}/hq/web.xml ${IMAGE}_${ENVNAME}:/opt/heading/hq/server/default/deploy/card.war/WEB-INF/
	sudo docker cp ${ConfPath}/hq/hdcard-xa-ds.xml ${IMAGE}_${ENVNAME}:/opt/heading/hq/server/default/deploy/
	sudo docker cp ${ConfPath}/hq/appOptions.xml ${IMAGE}_${ENVNAME}:/opt/heading/hq/server/default/deploy/hdcard-ejb-ear.ear/hdcard-ejb-user.jar/custommade/
	sudo docker cp ${ConfPath}/hq/rumba-rt.xml ${IMAGE}_${ENVNAME}:/opt/heading/hq/server/default/conf/
	sudo docker cp ${ConfPath}/ct/rumba-rt.xml ${IMAGE}_${ENVNAME}:/opt/heading/ct/server/default/conf/
	sudo docker cp ${ConfPath}/ct/appOptions.xml ${IMAGE}_${ENVNAME}:/opt/heading/ct/server/default/deploy/hdcard-ejb-ear.ear/hdcard-ejb-user.jar/custommade/
	sudo docker cp ${ConfPath}/ct/web.xml ${IMAGE}_${ENVNAME}:/opt/heading/ct/server/default/deploy/cardserver.war/WEB-INF/
	sudo docker cp ${ConfPath}/ct/web.xml ${IMAGE}_${ENVNAME}:/opt/heading/ct/server/default/deploy/card.war/WEB-INF/
	sudo docker cp ${ConfPath}/ct/hdcard-xa-ds.xml ${IMAGE}_${ENVNAME}:/opt/heading/ct/server/default/deploy/
	sudo docker cp ${ConfPath}/cs/web.xml ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/cardserver.war/WEB-INF/
	sudo docker cp ${ConfPath}/cs/hdcard-xa-ds.xml ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/
	sudo docker cp ${ConfPath}/cs/appOptions.xml ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/hdcard-ejb-ear.ear/hdcard-ejb-user.jar/custommade/
}

download_zip() {
	sudo wget -P ${UPGRADEDIR} http://download.hd123.com/TmpFiles/TA/20170509.7/hdcard_upgrade.zip && \
	sudo unzip -qo ${UPGRADEDIR}/hdcard_upgrade.zip -d ${UPGRADEDIR} && \
	sudo rm -rf ${UPGRADEDIR}/hdcard_upgrade.zip* && \
	sudo mkdir -p ${UPGRADEDIR}/log/${ENVNAME}
}

if [ "${ACTION}" = "install" ]; then
    set -e
    get_ip
	get_exip
	#download_zip
    pull_image
	image_exist
	container_exist
	
	echo "Install and deploying ${IMAGE}"
    echo "## Install begins : ${IMAGE}"
    start_container
    if [ $? -ne 0 ]; then
		echo "Install failed..."
		exit 1
    fi
    echo "## Install ends   : ${IMAGE}"
	echo "## Deploying begins : ${IMAGE}"
	sleep 10
    deploying_container
    if [ $? -ne 0 ]; then
		echo "Deploying failed..."
		exit 1
    fi
    echo "## Deploying ends   : ${IMAGE}"
	
	echo "Upgrade ${IMAGE}"
	echo "## Upgrade begins : ${IMAGE}"
	sleep 3
	restart_container
	sleep 60
    upgrade_card
    if [ $? -ne 0 ]; then
		echo "Upgrade failed..."
		exit 1
    fi
    echo "## Upgrade ends   : ${IMAGE}"
	
	echo "Restart ${IMAGE}"
	sleep 5
    restart_container
	cpout_config

    echo "cardhq available at ${PROTOCOL}://${INTRANETIP}:${HQPORT}/card or ${PROTOCOL}://${EXTRANETIP}:${HQPORT}/card"
    echo "cardct available at ${PROTOCOL}://${INTRANETIP}:${CTPORT}/card or ${PROTOCOL}://${EXTRANETIP}:${CTPORT}/card"
	echo "cardserver available at ${PROTOCOL}://${INTRANETIP}:${CSPORT}/cardserver or ${PROTOCOL}://${EXTRANETIP}:${CSPORT}/cardserver"
	echo "Done."
elif [ "${ACTION}" = "redeploy" ]; then
	pro_redeploy
	echo "cardhq available at ${PROTOCOL}://${INTRANETIP}:${HQPORT}/card or ${PROTOCOL}://${EXTRANETIP}:${HQPORT}/card"
    echo "cardct available at ${PROTOCOL}://${INTRANETIP}:${CTPORT}/card or ${PROTOCOL}://${EXTRANETIP}:${CTPORT}/card"
	echo "cardserver available at ${PROTOCOL}://${INTRANETIP}:${CSPORT}/cardserver or ${PROTOCOL}://${EXTRANETIP}:${CSPORT}/cardserver"
	echo "Done."
else
    echo "Unknown action ${ACTION}"
    exit 1
fi
