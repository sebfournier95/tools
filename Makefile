##############################################
# WARNING : THIS FILE SHOULDN'T BE TOUCHED   #
#    FOR ENVIRONNEMENT CONFIGURATION         #
# CONFIGURABLE VARIABLES SHOULD BE OVERRIDED #
# IN THE 'artifacts' FILE, AS NOT COMMITTED  #
##############################################

SHELL=/bin/bash
include /etc/os-release

USE_TTY := $(shell test -t 1 && USE_TTY="-t")

#base paths
APP_GROUP=matchID
APP_GROUP_MAIL=matchid.project@gmail.com
TOOLS = tools
TOOLS_PATH := $(shell pwd)
APP_GROUP_PATH := $(shell dirname ${TOOLS_PATH})
export APP = ${TOOLS}
export APP_PATH = ${TOOLS_PATH}

GIT_ROOT=https://github.com/matchid-project
GIT_BRANCH := $(shell git branch | grep '*' | awk '{print $$2}')
GIT_BRANCH_MASTER=master

export DOCKER_USERNAME=$(shell echo ${APP_GROUP} | tr '[:upper:]' '[:lower:]')
export DC_DIR=${APP_PATH}
export DC_FILE=${DC_DIR}/docker-compose
export DC_PREFIX := $(shell echo ${APP} | tr '[:upper:]' '[:lower:]')
export DC_NETWORK := $(shell echo ${APP} | tr '[:upper:]' '[:lower:]')
export DC_IMAGE_NAME = ${DC_PREFIX}
export DC_BUILD_ARGS = --pull --no-cache
export DC := /usr/local/bin/docker-compose

AWS=${TOOLS_PATH}/aws

DATAGOUV_CATALOG = ${DATA_DIR}/${DATAGOUV_DATASET}.datagouv.list
DATAGOUV_FILES_TO_SYNC=(^|\s)test.bin($$|\s)

DATA_DIR = ${PWD}/data
export FILE=${DATA_DIR}/test.bin

include ./artifacts.EC2.outscale
include ./artifacts.OS.ovh
include ./artifacts.SCW

S3_BUCKET=$(shell echo ${APP_GROUP} | tr '[:upper:]' '[:lower:]')
S3_CATALOG = ${DATA_DIR}/${DATAGOUV_DATASET}.s3.list
S3_CONFIG = ${TOOLS_PATH}/.aws/config

SSHID=${APP_GROUP_MAIL}
SSHKEY_PRIVATE = ${HOME}/.ssh/id_rsa_${APP_GROUP}
SSHKEY = ${SSHKEY_PRIVATE}.pub
SSHKEYNAME = ${TOOLS}
SSH_TIMEOUT = 90

EC2=ec2 ${EC2_ENDPOINT_OPTION} --profile ${EC2_PROFILE}

START_TIMEOUT = 120
CLOUD_DIR=${TOOLS_PATH}/cloud
CLOUD=SCW

CONFIG_DIR=${TOOLS_PATH}/configured
CONFIG_INIT_FILE=${CONFIG_DIR}/init
CONFIG_NEXT_FILE=${CONFIG_DIR}/next
CONFIG_FILE=${CONFIG_DIR}/conf
CONFIG_REMOTE_FILE=${CONFIG_DIR}/remote
CONFIG_REMOTE_PROXY_FILE=${CONFIG_DIR}/remote.proxy
CONFIG_TOOLS_FILE=${CONFIG_DIR}/${TOOLS}.deployed
CONFIG_APP_FILE=${CONFIG_DIR}/${APP}.deployed
CONFIG_DOCKER_FILE=${CONFIG_DIR}/docker
CONFIG_AWS_FILE=${CONFIG_DIR}/aws

dummy		    := $(shell touch artifacts)
include ./artifacts

SSHOPTS=-o "StrictHostKeyChecking no" -i ${SSHKEY} ${CLOUD_SSHOPTS}
SCW_SERVER_CONF={"name": "${APP}", "image": "${SCW_IMAGE_ID}", "commercial_type": "${SCW_FLAVOR}", "organization": "${SCW_ORGANIZATION_ID}"}
export APP_VERSION :=  $(shell git describe --tags)
CLOUD_SSHKEY_FILE=${CLOUD_DIR}/${CLOUD}.sshkey
CLOUD_SERVER_ID_FILE=${CLOUD_DIR}/${CLOUD}.id
CLOUD_HOST_FILE=${CLOUD_DIR}/${CLOUD}.host
CLOUD_FIRST_USER_FILE=${CLOUD_DIR}/${CLOUD}.user.first
CLOUD_USER_FILE=${CLOUD_DIR}/${CLOUD}.user
CLOUD_UP_FILE=${CLOUD_DIR}/${CLOUD}.up
CLOUD_HOSTNAME=${APP_GROUP}-${APP}

${DATA_DIR}:
	@if [ ! -d "${DATA_DIR}" ]; then mkdir -p ${DATA_DIR};fi

${CONFIG_DIR}:
	@mkdir -p ${CONFIG_DIR}

${CONFIG_INIT_FILE}: ${CONFIG_DIR} config-proxy tools-install docker-install
	@touch ${CONFIG_INIT_FILE}

${CONFIG_NEXT_FILE}: ${CONFIG_DIR} config-aws
	@touch ${CONFIG_NEXT_FILE}

config-init: ${CONFIG_INIT_FILE}

config-next: ${CONFIG_NEXT_FILE}

${CONFIG_FILE}: ${CONFIG_INIT_FILE} ${CONFIG_NEXT_FILE}
	@touch ${CONFIG_FILE}

config: ${CONFIG_FILE}

config-proxy:
	@if [ ! -z "${http_proxy}" ];then\
		if [ -z "$(grep http_proxy /etc/environment)"]; then\
			(echo "http_proxy=${http_proxy}" | sudo tee -a /etc/environment);\
		fi;\
	fi;
	@if [ ! -z "${https_proxy}" ];then\
		if [ -z "$(grep https_proxy /etc/environment)"]; then\
			(echo "https_proxy=${https_proxy}" | sudo tee -a /etc/environment);\
		fi;\
	fi;
	@if [ ! -z "${no_proxy}" ];then\
		if [ -z "$(grep no_proxy /etc/environment)"]; then\
			(echo "no_proxy=${no_proxy}" | sudo tee -a /etc/environment);\
		fi;\
	fi;

# system tools, widely used in matchID projects

tools-install:
ifeq ("$(wildcard /usr/bin/envsubst)","")
	sudo apt-get install -yqq gettext; true
endif
ifeq ("$(wildcard /usr/bin/curl)","")
	sudo apt-get install -yqq curl; true
endif
ifeq ("$(wildcard /usr/bin/gawk)","")
	sudo apt-get install -yqq gawk; true
endif
ifeq ("$(wildcard /usr/bin/jq)","")
	sudo apt-get install -yqq jq; true
endif

#docker section
docker-install: ${CONFIG_DOCKER_FILE} docker-config-proxy

docker-config-proxy:
	if [ ! -z "${http_proxy}" ];then\
		if [ ! -f "/etc/systemd/system/docker.service.d/http-proxy.conf" ]; then\
			sudo mkdir -p /etc/systemd/system/docker.service.d/;\
			(echo '[Service]' | sudo tee -a /etc/systemd/system/docker.service.d/http-proxy.conf);\
			(echo 'Environment="HTTPS_PROXY=${http_proxy}" "HTTP_PROXY=${https_proxy}"' | sudo tee -a /etc/systemd/system/docker.service.d/http-proxy.conf);\
			sudo systemctl daemon-reload;\
			sudo systemctl restart docker;\
		fi;\
	fi

${CONFIG_DOCKER_FILE}: ${CONFIG_DIR}
ifeq ("$(wildcard /usr/bin/docker /usr/local/bin/docker)","")
	echo install docker-ce, still to be tested
	sudo echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
	sudo apt-get update -yqq
	sudo apt-get install -yqq \
	apt-transport-https \
	ca-certificates \
	curl \
	software-properties-common

	curl -fsSL https://download.docker.com/linux/${ID}/gpg | sudo apt-key add -
	sudo add-apt-repository \
		"deb https://download.docker.com/linux/ubuntu \
		`lsb_release -cs` \
		stable"
	sudo apt-get update -yqq
	sudo apt-get install -yqq docker-ce
endif
	@(if (id -Gn ${USER} | grep -vc docker); then sudo usermod -aG docker ${USER} ;fi) > /dev/null
ifeq ("$(wildcard /usr/bin/docker-compose /usr/local/bin/docker-compose)","")
	@echo installing docker-compose
	@sudo curl -s -L https://github.com/docker/compose/releases/download/1.19.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
	@sudo chmod +x /usr/local/bin/docker-compose
endif
	@touch ${CONFIG_DOCKER_FILE}

docker-build:
	if [ ! -z "${VERBOSE}" ];then\
		${DC} config;\
	fi;
	${DC} build $(DC_BUILD_ARGS)

docker-tag:
	@if [ "${GIT_BRANCH}" == "${GIT_BRANCH_MASTER}" ];then\
		docker tag ${DOCKER_USERNAME}/${DC_IMAGE_NAME}:${APP_VERSION} ${DOCKER_USERNAME}/${DC_IMAGE_NAME}:latest;\
	else\
		docker tag ${DOCKER_USERNAME}/${DC_IMAGE_NAME}:${APP_VERSION} ${DOCKER_USERNAME}/${DC_IMAGE_NAME}:${GIT_BRANCH};\
	fi

docker-push: docker-login docker-tag
	@docker push ${DOCKER_USERNAME}/${DC_IMAGE_NAME}:${APP_VERSION}
	@if [ "${GIT_BRANCH}" == "${GIT_BRANCH_MASTER}" ];then\
		docker push ${DOCKER_USERNAME}/${DC_IMAGE_NAME}:latest;\
	else\
		docker push ${DOCKER_USERNAME}/${DC_IMAGE_NAME}:${GIT_BRANCH};\
	fi

docker-login:
	@echo docker login for ${DOCKER_USERNAME}
	@echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

docker-pull:
	docker pull ${DOCKER_USERNAME}/${DC_IMAGE_NAME}:${APP_VERSION}

generate-test-file: ${DATA_DIR}
	dd if=/dev/urandom bs=16M count=16 > ${FILE}

#cloud section
${SSHKEY}:
	@echo ssh keygen
	@ssh-keygen -t rsa -b 4096 -C "${SSHID}" -f ${SSHKEY_PRIVATE} -q -N "${SSH_PASSPHRASE}"

${CLOUD_DIR}:
	@mkdir -p ${CLOUD_DIR};\
	echo creating ${CLOUD_DIR} for cloud ids

cloud-dir-delete:
	@rm -rf ${CLOUD_DIR} > /dev/null 2>&1

${CLOUD_FIRST_USER_FILE}: ${CLOUD_DIR}
	@if [ "${CLOUD}" == "SCW" ];then\
		echo "root" > ${CLOUD_FIRST_USER_FILE};\
	elif [ "${CLOUD}" == "OS" ];then\
		echo ${OS_SSHUSER} > ${CLOUD_FIRST_USER_FILE};\
	elif [ "${CLOUD}" == "EC2" ];then\
		echo ${EC2_SSHUSER} > ${CLOUD_FIRST_USER_FILE};\
	else\
		echo ${SSHUSER} > ${CLOUD_FIRST_USER_FILE};\
	fi;\
	echo using $$(cat ${CLOUD_FIRST_USER_FILE}) for first ssh connexion

${CLOUD_USER_FILE}: ${CLOUD_DIR}
	@if [ "${CLOUD}" == "SCW" ];then\
		echo ${SCW_SSHUSER} > ${CLOUD_USER_FILE};\
	elif [ "${CLOUD}" == "OS" ];then\
		echo ${OS_SSHUSER} > ${CLOUD_USER_FILE};\
	elif [ "${CLOUD}" == "EC2" ];then\
		echo ${EC2_SSHUSER} > ${CLOUD_USER_FILE};\
	else\
		echo ${SSHUSER} > ${CLOUD_USER_FILE};\
	fi;\
	echo using $$(cat ${CLOUD_USER_FILE}) for next ssh connexions

${CLOUD_SERVER_ID_FILE}: ${CLOUD_DIR} ${CLOUD}-instance-order
	@echo ${CLOUD} id: $$(cat ${CLOUD_SERVER_ID_FILE})

${CLOUD_HOST_FILE}: ${CLOUD_DIR} ${CLOUD}-instance-get-host
	@echo ${CLOUD} ip: $$(cat ${CLOUD_HOST_FILE})

${CLOUD}-instance-wait-ssh: ${CLOUD_FIRST_USER_FILE} ${CLOUD_HOST_FILE}
	@if [ ! -f "${CLOUD_UP_FILE}" ];then\
		HOST=$$(cat ${CLOUD_HOST_FILE});\
		SSHUSER=$$(cat ${CLOUD_FIRST_USER_FILE});\
		(ssh-keygen -R $$HOST > /dev/null 2>&1) || true;\
		timeout=${SSH_TIMEOUT} ; ret=1 ;\
		until [ "$$timeout" -le 0 -o "$$ret" -eq "0"  ] ; do\
			((ssh ${SSHOPTS} $$SSHUSER@$$HOST sleep 1) );\
			ret=$$? ; \
			if [ "$$ret" -ne "0" ] ; then\
				echo "waiting for ssh service on ${CLOUD} instance - $$timeout" ; \
				if [ ! -z "${VERBOSE}" ];then\
					echo 'cmd: ssh ${SSHOPTS} -o ConnectTimeout=1 '"$$SSHUSER@$$HOST"; \
				fi;\
			fi ;\
			((timeout--)); sleep 1 ; \
		done ;\
		exit $$ret;\
	fi

${CLOUD_UP_FILE}: ${CLOUD}-instance-wait-ssh ${CLOUD_USER_FILE}
	@touch ${CLOUD_UP_FILE}

cloud-instance-up: ${CLOUD_UP_FILE}

cloud-instance-down: ${CLOUD}-instance-delete
	@(rm ${CLOUD_UP_FILE} ${CLOUD_HOST_FILE} ${CLOUD_SERVER_ID_FILE} \
		${CLOUD_FIRST_USER_FILE} ${CLOUD_USER_FILE} ${CLOUD_SSHKEY_FILE} > /dev/null 2>&1) || true

#Scaleway section
SCW-instance-order: ${CLOUD_DIR}
	@if [ ! -f ${CLOUD_SERVER_ID_FILE} ]; then\
		SCW_SERVER_OPTS=$$(echo '${SCW_SERVER_CONF}' '${SCW_SERVER_OPTS}' | jq -cs add);\
		if [ ! -z "${VERBOSE}" ]; then\
			echo "SCW server options $$SCW_SERVER_OPTS";\
		fi;\
		curl -s ${SCW_API}/servers -H "X-Auth-Token: ${SCW_SECRET_TOKEN}" \
			-H "Content-Type: application/json" \
			-d "$$SCW_SERVER_OPTS" \
		| jq -r '.server.id' > ${CLOUD_SERVER_ID_FILE};\
	fi

SCW-instance-start: ${CLOUD_SERVER_ID_FILE}
	@SCW_SERVER_ID=$$(cat ${CLOUD_SERVER_ID_FILE});\
		(curl -s ${SCW_API}/servers -H "X-Auth-Token: ${SCW_SECRET_TOKEN}" | jq -cr  ".servers[] | select (.id == \"$$SCW_SERVER_ID\") | .state" | (grep running > /dev/null) && \
		echo scaleway instance already running)\
		|| \
	 	(\
			(\
				(curl -s --fail ${SCW_API}/servers/$$SCW_SERVER_ID/action -H "X-Auth-Token: ${SCW_SECRET_TOKEN}" \
					-H "Content-Type: application/json" -d '{"action": "poweron"}' > /dev/null) &&\
				echo scaleway instance starting\
			) || echo scaleway instance still starting\
		)

SCW-instance-wait-running: SCW-instance-start
	@if [ ! -f "${CLOUD_UP_FILE}" ];then\
		SCW_SERVER_ID=$$(cat ${CLOUD_SERVER_ID_FILE});\
		timeout=${START_TIMEOUT} ; ret=1 ;\
		until [ "$$timeout" -le 0 -o "$$ret" -eq "0"  ] ; do\
			curl -s ${SCW_API}/servers -H "X-Auth-Token: ${SCW_SECRET_TOKEN}" | jq -cr  ".servers[] | select (.id == \"$$SCW_SERVER_ID\") | .state" | (grep running > /dev/null);\
			ret=$$? ; \
			if [ "$$ret" -ne "0" ] ; then echo "waiting for scaleway instance $$SCW_SERVER_ID to start $$timeout" ; fi ;\
			((timeout--)); sleep 1 ; \
		done ; \
		exit $$ret;\
	fi

SCW-instance-get-host: SCW-instance-wait-running
	@if [ ! -f "${CLOUD_HOST_FILE}" ];then\
		SCW_SERVER_ID=$$(cat ${CLOUD_SERVER_ID_FILE});\
		curl -s ${SCW_API}/servers -H "X-Auth-Token: ${SCW_SECRET_TOKEN}" \
			| jq -cr  ".servers[] | select (.id == \"$$SCW_SERVER_ID\") | .${SCW_IP}" \
			> ${CLOUD_HOST_FILE};\
	fi

SCW-instance-delete:
	@if [ -f "${CLOUD_SERVER_ID_FILE}" ];then\
		SCW_SERVER_ID=$$(cat ${CLOUD_SERVER_ID_FILE});\
		(\
			(\
				curl -s --fail ${SCW_API}/servers/$$SCW_SERVER_ID/action -H "X-Auth-Token: ${SCW_SECRET_TOKEN}" \
					-H "Content-Type: application/json" -d '{"action": "terminate"}' > /dev/null \
			) \
		&& \
			(\
				echo scaleway server $$(cat ${CLOUD_SERVER_ID_FILE}) terminating\
			)\
		) || (echo scaleway error while terminating server && exit 1);\
	else\
		(echo no ${CLOUD_SERVER_ID_FILE} for deletion);\
	fi


#Openstack section
OS-add-sshkey: ${SSHKEY} ${CLOUD_DIR}
	@if [ ! -f "${CLOUD_SSHKEY_FILE}" ];then\
	(\
		(nova keypair-list | sed 's/|//g' | egrep -v '\-\-\-|Name' | (egrep '^\s*${SSHKEYNAME}\s' > /dev/null) &&\
		 echo "ssh key already deployed to openstack" &&\
		 touch ${CLOUD_SSHKEY_FILE}\
		 ) \
	  || \
		(nova keypair-add --pub-key ${SSHKEY} ${SSHKEYNAME} &&\
		 nova keypair-list | sed 's/|//g' | egrep -v '\-\-\-|Name' | (egrep '^\s*${SSHKEYNAME}\s' > /dev/null) &&\
		 echo "ssh key deployed with success to openstack" &&\
		 touch ${CLOUD_SSHKEY_FILE}\
		 ) \
	  );\
	fi;

OS-instance-order: ${CLOUD_DIR} OS-add-sshkey
	@if [ ! -f "${CLOUD_SERVER_ID_FILE}" ];then\
	(\
		(nova list | sed 's/|//g' | egrep -v '\-\-\-|Name' | (egrep '\s${CLOUD_HOSTNAME}\s' > /dev/null) && \
		echo "openstack instance already ordered")\
	 || \
		(nova boot --key-name ${SSHKEYNAME} --flavor ${OS_FLAVOR_ID} --image ${OS_IMAGE_ID} ${CLOUD_HOSTNAME} && \
	 		echo "openstack intance ordered with success" &&\
			(echo ${CLOUD_HOSTNAME} > ${CLOUD_SERVER_ID_FILE}) \
		) || echo "openstance instance order failed"\
	);\
	fi

OS-instance-wait-running: ${CLOUD_SERVER_ID_FILE}
	@if [ ! -f "${CLOUD_UP_FILE}" ];then\
		timeout=${START_TIMEOUT} ; ret=1 ;\
		until [ "$$timeout" -le 0 -o "$$ret" -eq "0"  ] ; do\
	  		nova list | sed 's/|//g' | egrep -v '\-\-\-|Name' | (egrep '\s${CLOUD_HOSTNAME}\s.*Running' > /dev/null) ;\
	  		ret=$$? ; \
	  		if [ "$$ret" -ne "0" ] ; then echo "waiting for openstack instance to start $$timeout" ; fi ;\
	  		((timeout--)); sleep 1 ; \
		done ; \
		exit $$ret;\
	fi

OS-instance-get-host: OS-instance-wait-running
	@if [ ! -f "${CLOUD_HOST_FILE}" ];then\
		(nova list | sed 's/|//g' | egrep -v '\-\-\-|Name' | egrep '\s${CLOUD_HOSTNAME}\s.*Running' |\
			sed 's/.*Ext-Net=//;s/,.*//' > ${CLOUD_HOST_FILE});\
	fi

OS-instance-delete:
	@nova delete $$(cat ${CLOUD_SERVER_ID_FILE})

#EC2 section

${CONFIG_AWS_FILE}: ${CONFIG_DIR}
	@docker pull matchid/tools && echo docker pulled matchid/tools
	@if [ ! -d "${HOME}/.aws" ];then\
		echo create aws configuration;\
		mkdir -p ${HOME}/.aws;\
		echo -e "[default]\naws_access_key_id=${aws_access_key_id}\naws_secret_access_key=${aws_secret_access_key}\n" \
		> ${HOME}/.aws/credentials;\
		cp .aws/config ${HOME}/.aws/;\
	fi;
	@touch ${CONFIG_AWS_FILE}

config-aws: ${CONFIG_AWS_FILE}

EC2-add-sshkey:
	@if [ ! -f "${CLOUD_SSHKEY_FILE}" ];then\
		(\
			(\
				(${AWS} ${EC2} describe-key-pairs --key-name ${SSHKEYNAME}  > /dev/null 2>&1) &&\
				(echo "ssh key already deployed to EC2";\
				touch ${CLOUD_SSHKEY_FILE})\
			) \
		|| \
			(\
				(${AWS} ${EC2} import-key-pair --key-name ${SSHKEYNAME} --public-key-material file://${SSHKEY} \
					> /dev/null 2>&1)\
				&&\
					(echo "ssh key deployed with success to EC2";\
					touch ${CLOUD_SSHKEY_FILE})\
			) \
		);\
	fi

EC2-instance-order: ${CLOUD_DIR} EC2-add-sshkey
	@if [ ! -f "${CLOUD_SERVER_ID_FILE}" ];then\
		(\
			(\
				${AWS} ${EC2} run-instances --key-name ${SSHKEYNAME} \
		 			--image-id ${EC2_IMAGE_ID} --instance-type ${EC2_FLAVOR_TYPE} \
				| jq -r '.Instances[0].InstanceId' > ${CLOUD_SERVER_ID_FILE} 2>&1 \
		 	) && echo "EC2 instance ordered with success"\
		) || echo "EC2 instance order failed";\
	fi

EC2-instance-get-host: EC2-instance-wait-running
	@if [ ! -f "${CLOUD_HOST_FILE}" ];then\
		EC2_SERVER_ID=$$(cat ${CLOUD_SERVER_ID_FILE});\
		(${AWS} ${EC2} describe-instances --instance-ids $$EC2_SERVER_ID \
			| jq -r ".Reservations[].Instances[].${EC2_IP}" > ${CLOUD_HOST_FILE});\
	fi

EC2-instance-wait-running: ${CLOUD_SERVER_ID_FILE}
	@if [ ! -f "${CLOUD_UP_FILE}" ];then\
		EC2_SERVER_ID=$$(cat ${CLOUD_SERVER_ID_FILE});\
		timeout=${START_TIMEOUT} ; ret=1 ; \
		until [ "$$timeout" -le 0 -o "$$ret" -eq "0"  ] ; do\
			${AWS} ${EC2} describe-instances --instance-ids $$EC2_SERVER_ID | jq -c '.Reservations[].Instances[].State.Name' | (grep running > /dev/null);\
			ret=$$? ; \
			if [ "$$ret" -ne "0" ] ; then echo "waiting for EC2 instance $$EC2_SERVER_ID to start $$timeout" ; fi ;\
			((timeout--)); sleep 1 ; \
		done ;\
		exit $$ret;\
	fi

EC2-instance-delete:
	@if [ -f "${CLOUD_SERVER_ID_FILE}" ];then\
		EC2_SERVER_ID=$$(cat ${CLOUD_SERVER_ID_FILE});\
		${AWS} ${EC2} terminate-instances --instance-ids $$EC2_SERVER_ID |\
			jq -r '.TerminatingInstances[0].CurrentState.Name' | sed 's/$$/ EC2 instance/';\
	fi


#S3 section
${S3_CATALOG}: ${CONFIG_AWS_FILE} ${DATA_DIR}
	@echo getting ${S3_BUCKET} catalog from s3 API
	@${AWS} s3 ls ${S3_BUCKET} | awk '{print $$NF}' | egrep '${FILES_TO_SYNC}' | sort > ${S3_CATALOG}

s3-get-catalog: ${S3_CATALOG}

s3-push:
	${AWS} s3 cp ${FILE} s3://${S3_BUCKET}/$$(basename ${FILE})

s3-pull:
	${AWS} s3 cp s3://${S3_BUCKET}/$$(basename ${FILE}) ${FILE}

#DATAGOUV section
${DATAGOUV_CATALOG}: config ${DATA_DIR}
	@echo getting ${DATAGOUV_DATASET} catalog from data.gouv API ${DATAGOUV_API}
	@curl -s --fail ${DATAGOUV_API}/${DATAGOUV_DATASET}/ | \
		jq  -cr '.resources[] | .title + " " +.checksum.value + " " + .url' | sort > ${DATAGOUV_CATALOG}

datagouv-get-catalog: ${DATAGOUV_CATALOG}

datagouv-get-files: ${DATAGOUV_CATALOG}
	@if [ -f "${S3_CATALOG}" ]; then\
		(echo egrep -v $$(cat ${S3_CATALOG} | tr '\n' '|' | sed 's/.gz//g;s/^/"(/;s/|$$/)"/') ${DATAGOUV_CATALOG} | sh > ${DATA_DIR}/tmp.list) || true;\
	else\
		cp ${DATAGOUV_CATALOG} ${DATA_DIR}/tmp.list;\
	fi

	@if [ -s "${DATA_DIR}/tmp.list" ]; then\
		i=0;\
		for file in $$(awk '{print $$1}' ${DATA_DIR}/tmp.list); do\
			if [ ! -f ${DATA_DIR}/$$file.gz.sha1 ]; then\
				echo getting $$file ;\
				grep $$file ${DATA_DIR}/tmp.list | awk '{print $$3}' | xargs curl -s > ${DATA_DIR}/$$file; \
				grep $$file ${DATA_DIR}/tmp.list | awk '{print $$2}' > ${DATA_DIR}/$$file.sha1.src; \
				sha1sum < ${DATA_DIR}/$$file | awk '{print $$1}' > ${DATA_DIR}/$$file.sha1.dst; \
				((diff ${DATA_DIR}/$$file.sha1.src ${DATA_DIR}/$$file.sha1.dst > /dev/null) || echo error downloading $$file); \
				gzip ${DATA_DIR}/$$file; \
				sha1sum ${DATA_DIR}/$$file.gz > ${DATA_DIR}/$$file.gz.sha1; \
				((i++));\
			fi;\
		done;\
		if [ "$$i" == "0" ]; then\
			echo no new file downloaded from datagouv;\
		else\
			echo "$$i file(s) donwloaded from datagouv";\
		fi;\
	else\
		echo no new file downloaded from datagouv;\
	fi

remote-config-proxy: ${CLOUD_FIRST_USER_FILE}
	@if [ ! -f "${CONFIG_REMOTE_PROXY_FILE}" ]; then\
		if [ ! -z "${remote_http_proxy}" ]; then\
			H=$$(cat ${CLOUD_HOST_FILE});\
			U=$$(cat ${CLOUD_FIRST_USER_FILE});\
			if [ "${CLOUD}" == "SCW" ];then\
				sudo="";\
			else\
				sudo=sudo;\
			fi;\
			if [ ! -z "${remote_http_proxy}" ];then\
				(echo "http_proxy=${remote_http_proxy}" | ssh ${SSHOPTS} $$U@$$H $$sudo tee -a /etc/environment);\
			fi;\
			if [ ! -z "${remote_https_proxy}" ];then\
				(echo "https_proxy=${remote_https_proxy}" | ssh ${SSHOPTS} $$U@$$H $$sudo tee -a /etc/environment);\
			fi;\
			if [ ! -z "${remote_no_proxy}" ];then\
				(echo "no_proxy=${remote_no_proxy}" | ssh ${SSHOPTS} $$U@$$H $$sudo tee -a /etc/environment);\
			fi;\
		fi;\
		touch ${CONFIG_REMOTE_PROXY_FILE};\
	fi;

${CONFIG_REMOTE_FILE}: cloud-instance-up remote-config-proxy ${CONFIG_DIR}
		@\
		if [ ! -f "${CONFIG_REMOTE_FILE}" ];then\
			H=$$(cat ${CLOUD_HOST_FILE});\
			U=$$(cat ${CLOUD_USER_FILE});\
			if [ "${CLOUD}" == "SCW" ];then\
				ssh ${SSHOPTS} root@$$H apt-get install -o Dpkg::Options::="--force-confold" -yq sudo;\
			fi;\
			ssh ${SSHOPTS} $$U@$$H mkdir -p ${APP_GROUP};\
			ssh ${SSHOPTS} $$U@$$H sudo apt-get install -yq make;\
			ssh ${SSHOPTS} $$U@$$H git clone ${GIT_ROOT}/${TOOLS} ${APP_GROUP}/${TOOLS};\
			ssh ${SSHOPTS} $$U@$$H make -C ${APP_GROUP}/${TOOLS} config-init http_proxy=${remote_http_proxy} https_proxy=${remote_https_proxy};\
			ssh ${SSHOPTS} $$U@$$H make -C ${APP_GROUP}/${TOOLS} config-next aws_access_key_id=${aws_access_key_id} aws_secret_access_key=${aws_secret_access_key};\
			touch ${CONFIG_REMOTE_FILE};\
			touch ${CONFIG_TOOLS_FILE};\
		fi

remote-config: ${CONFIG_REMOTE_FILE}

remote-deploy: remote-config ${CONFIG_APP_FILE}

remote-clean: cloud-instance-down
	@(rm ${CONFIG_REMOTE_FILE} ${CONFIG_REMOTE_PROXY_FILE} > /dev/null 2>&1) || true

${CONFIG_APP_FILE}: ${CONFIG_REMOTE_FILE}
		@\
		if [ ! -f "${CONFIG_APP_FILE}" ];then\
			H=$$(cat ${CLOUD_HOST_FILE});\
			U=$$(cat ${CLOUD_USER_FILE});\
			if [ "${APP}" != "${TOOLS}" ];then\
				ssh ${SSHOPTS} $$U@$$H git clone --branch ${GIT_BRANCH} ${GIT_ROOT}/${APP} ${APP_GROUP}/${APP};\
				ssh ${SSHOPTS} $$U@$$H make -C ${APP_GROUP}/${APP} config;\
			fi;\
			touch ${CONFIG_APP_FILE};\
		fi

remote-actions: remote-deploy
		@\
		H=$$(cat ${CLOUD_HOST_FILE});\
		U=$$(cat ${CLOUD_USER_FILE});\
		if [ "${ACTIONS}" != "" ];then\
			ssh ${SSHOPTS} $$U@$$H make -C ${APP_GROUP}/${APP} ${ACTIONS} aws_access_key_id=${aws_access_key_id} aws_secret_access_key=${aws_secret_access_key} ${MAKEOVERRIDES};\
		fi

datagouv-to-s3: s3-get-catalog datagouv-get-files
	@for file in $$(ls ${DATA_DIR} | egrep '${FILES_TO_SYNC}');do\
		${AWS} s3 cp ${DATA_DIR}/$$file s3://${S3_BUCKET}/$$file;\
		${AWS} s3api put-object-acl --acl public-read --bucket ${S3_BUCKET} --key $$file && echo $$file acl set to public;\
	done

#GIT matchid projects section
${GIT_BACKEND}:
	@echo configuring matchID
	@${GIT} clone ${GIT_ROOT}/${GIT_BACKEND}
	@cp artifacts ${GIT_BACKEND}/artifacts
	@cp docker-compose-local.yml ${GIT_BACKEND}/docker-compose-local.yml
	@echo "export ES_NODES=1" >> ${GIT_BACKEND}/artifacts
	@echo "export PROJECTS=${PWD}/projects" >> ${GIT_BACKEND}/artifacts
	@echo "export S3_BUCKET=${S3_BUCKET}" >> ${GIT_BACKEND}/artifacts

# tests for automation
remote-config-test:
	@/usr/bin/time -f %e make remote-actions ACTIONS="generate-test-file s3-push" remote-clean
