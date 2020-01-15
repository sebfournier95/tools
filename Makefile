##############################################
# WARNING : THIS FILE SHOULDN'T BE TOUCHED   #
#    FOR ENVIRONNEMENT CONFIGURATION         #
# CONFIGURABLE VARIABLES SHOULD BE OVERRIDED #
# IN THE 'artifacts' FILE, AS NOT COMMITTED  #
##############################################

SHELL=/bin/bash

export USE_TTY := $(shell test -t 1 && USE_TTY="-t")

#base paths
export APP = tools
export APP_PATH := $(shell pwd)
export APP_VERSION :=
export DOCKER_USERNAME=matchid
export DC_DIR=${APP_PATH}
export DC_FILE=${DC_DIR}/docker-compose
export DC_PREFIX := $(shell echo ${APP} | tr '[:upper:]' '[:lower:]')
export DC_NETWORK := $(shell echo ${APP} | tr '[:upper:]' '[:lower:]')
export DC_BUILD_ARGS = --pull --no-cache
export DC := /usr/local/bin/docker-compose

dummy		    := $(shell touch artifacts)
include ./artifacts

export APP_VERSION :=  $(shell git describe --tags || cat VERSION )

docker-build:
	${DC} build $(DC_BUILD_ARGS)

docker-tag:
	docker tag ${DOCKER_USERNAME}/${APP}:${APP_VERSION} ${DOCKER_USERNAME}/${APP}:latest

docker-push: docker-login
	docker push ${DOCKER_USERNAME}/${APP}:${APP_VERSION}
	docker push ${DOCKER_USERNAME}/${APP}:latest

docker-login:
	@echo docker login for ${DOCKER_USERNAME}
	@echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

docker-pull:
	docker pull ${DOCKER_USERNAME}/${APP}:${APP_VERSION}

