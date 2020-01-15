#######################
# Step 1: Base target #
#######################
FROM python:alpine as base
ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG app_path
ARG app_name
ARG app_ver
ENV APP ${APP}
ENV APP_VERSION ${app_ver}

VOLUME /root/.aws
VOLUME /$app_path

WORKDIR /$app_path


# update debian w/proxy & mirror then installs git in case of git dependencies

# RUN apk add curl jq gawk gettext gcc python-dev linux-headers libc-dev
RUN apk add curl jq gawk gettext gcc libc-dev libffi-dev openssl-dev make

RUN pip install `echo $proxy | sed 's/\(\S\S*\)/--proxy \1/'` nova aws awscli_plugin_endpoint

RUN apk del gcc libc-dev libffi-dev openssl-dev make

RUN rm /var/cache/apk/*

# container shall not be definitively started, it's a tool
ENTRYPOINT [ "aws" ]
