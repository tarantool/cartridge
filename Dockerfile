FROM node:carbon as builder

WORKDIR /build

COPY . /build
RUN npm i

RUN npm run build

RUN mkdir -p /dist/public && \
    cp -R /build/build/* /dist/public/ && \
    cp /build/example.lua /dist/example.lua  && \
    tar -cz -C /dist . > /tarantool-enterprise-admin-ui.tar.gz
