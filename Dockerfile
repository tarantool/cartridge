FROM centos:7 as build

ARG VERSION
ARG DOWNLOAD_TOKEN

RUN set -x &&\
    yum -y install https://centos7.iuscommunity.org/ius-release.rpm &&\
    curl -sL https://rpm.nodesource.com/setup_8.x | bash - &&\
    yum -y install gcc git make cmake unzip python python-pip nodejs &&\
    # cypress deps
    yum -y install gtk3 xorg-x11-server-Xvfb libXScrnSaver GConf2 alsa-lib

RUN npm install graphql-cli@3.0.14
ENV PATH="${PWD}/node_modules/.bin:${PATH}"

RUN set -x &&\
    echo "Using tarantool-enterprise-bundle ${VERSION}" &&\
    curl -O -L https://tarantool:${DOWNLOAD_TOKEN}@download.tarantool.io/enterprise/tarantool-enterprise-bundle-${VERSION}.tar.gz &&\
    tar -xzf tarantool-enterprise-bundle-${VERSION}.tar.gz &&\
    rm -rf tarantool-enterprise-bundle-${VERSION}.tar.gz

ENV PATH="${PWD}/tarantool-enterprise:${PATH}"

RUN yum clean all &&\
    rm -rf /var/cache &&\
    rm -rf /root/.cache

RUN tarantoolctl rocks install ldoc --server=http://rocks.moonscript.org &&\
    tarantoolctl rocks install luacheck &&\
    tarantoolctl rocks install luacov &&\
    tarantoolctl rocks install luacov-console 1.1.0 &&\
    tarantoolctl rocks install luatest 0.3.0

ENV PATH="${PWD}/.rocks/bin:${PATH}"
COPY test/integration/requirements.txt /tmp/requirements.txt

RUN pip install -r /tmp/requirements.txt
RUN rm tmp/requirements.txt
