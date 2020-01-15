##############################################
# WARNING : THIS FILE SHOULDN'T BE TOUCHED   #
#    FOR ENVIRONNEMENT CONFIGURATION         #
# CONFIGURABLE VARIABLES SHOULD BE OVERRIDED #
# IN THE 'artifacts' FILE, AS NOT COMMITTED  #
##############################################

SHELL=/bin/bash

export USE_TTY := $(shell test -t 1 && USE_TTY="-t")

#search-ui
export PORT=8082

#base paths
export APP = tools
export APP_PATH := $(shell pwd)
export APP_VERSION :=
export DOCKER_USERNAME=matchid

dummy		    := $(shell touch artifacts)
include ./artifacts

export APP_VERSION :=  $(shell git describe --tags || cat VERSION )

build:
	docker build .

docker-push: docker-login
	docker push ${DOCKER_USERNAME}/${APP}:${APP_VERSION}

docker-login:
	@echo docker login for ${DOCKER_USERNAME}
	@echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin

docker-pull:
	docker pull ${DOCKER_USERNAME}/${APP}:${APP_VERSION}

