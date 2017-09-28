###############################################################################
# File Name: CARDSERVER.sh
# Author: shujun
# mail: shujun@hd123.com
# Created Time: Mon Aug 15 11:28:17 CST 2016
###############################################################################
#!/bin/bash
ACTION=${ACTION:-install}
IMAGE=${IMAGE:-cardserver}
VERSION=${VERSION:-3.46}
DOCKERHUB=${DOCKERHUB:-dockerhub.hd123.com}
WEBPORT=${WEBPORT:-28680}
DEPLOYDIR=${DEPLOYDIR:-data}
LOGDIR=${LOGDIR:-/${DEPLOYDIR}/heading/${ENVNAME}/log_${ENVNAME}/${IMAGE}}
UPGRADEDIR=${UPGRADEDIR:-/opt/heading/cardserver/${ENVNAME}}
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
OLDVER=${OLDVER:-34}
NEWVER=${NEWVER:-45}


#选项后面的冒号表示该选项需要参数
ARGS=`getopt -o v: --long webport: -n 'CARDSERVER.sh' -- "$@"`
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
						 --restart=on-failure:3 \
						 --log-opt max-size=50m \
						 -m 2g \
						 -p ${WEBPORT}:8380 \
						 -v ${LOGDIR}:/opt/heading/cs/server/default/log \
					     -v ${UPGRADEDIR}:/opt/heading/upgrade/log \
						 -v /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime \
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
						${IMAGE}_${ENVNAME} sh -c '
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
													/PRODUCT/s%CARD%CRM%" /opt/heading/cs/server/default/deploy/hdcard-ejb-ear.ear/hdcard-ejb-user.jar/custommade/cardserver-user.xml') >/dev/null 2>&1
}

upgrade_cardserver() {

    ID=$(sudo docker exec ${IMAGE}_${ENVNAME} sh -c 'sh /opt/heading/upgrade/rumba-upgrader-3.3.8/bin/hdcard_upgrade.sh') >/dev/null 2>&1
}

cpout_config() {
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/cardserver.war/WEB-INF/web.xml ${ConfPath}
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/hdcard-xa-ds.xml ${ConfPath}
	sudo docker cp ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/hdcard-ejb-ear.ear/hdcard-ejb-user.jar/custommade/appOptions.xml ${ConfPath}
}

cpin_config() {
	sudo docker cp ${ConfPath}/web.xml ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/cardserver.war/WEB-INF/
	sudo docker cp ${ConfPath}/hdcard-xa-ds.xml ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/
	sudo docker cp ${ConfPath}/appOptions.xml ${IMAGE}_${ENVNAME}:/opt/heading/cs/server/default/deploy/hdcard-ejb-ear.ear/hdcard-ejb-user.jar/custommade/
}

if [ "${ACTION}" = "install" ]; then
set -e
    get_ip
	get_exip

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
    upgrade_cardserver
    if [ $? -ne 0 ]; then
		echo "Upgrade failed..."
		exit 1
    fi
    echo "## Upgrade ends   : ${IMAGE}"
	
	echo "Restart ${IMAGE}"
	sleep 5
    restart_container
	cpout_config

    echo "cardserver available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/cardserver or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/cardserver"
	echo "Done."
elif [ "${ACTION}" = "redeploy" ]; then
	pro_redeploy
    echo "cardserver available at ${PROTOCOL}://${INTRANETIP}:${WEBPORT}/cardserver or ${PROTOCOL}://${EXTRANETIP}:${WEBPORT}/cardserver"
	echo "Done."
else
    echo "Unknown action ${ACTION}"
    exit 1
fi
