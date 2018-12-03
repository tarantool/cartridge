DIR := webui
.PHONY: all install doc test schema

all: $(DIR)/node_modules
	npm run build --prefix=$(DIR)

$(DIR)/node_modules: $(DIR)/package.json
	npm install --prefix=$(DIR)
	@ touch $@

install:
	mkdir -p $(INST_LUADIR)/cluster
	tarantool pack.lua $(DIR)/build $(INST_LUADIR)/cluster/webui-static.lua

start:
	mkdir -p ./dev
	ALIAS=srv-1 WORKDIR=dev/3301 ADVERTISE_URI=localhost:3301 HTTP_PORT=8081 ./pytest/instance.lua & echo $$! >> ./dev/pids
	ALIAS=srv-2 WORKDIR=dev/3302 ADVERTISE_URI=localhost:3302 HTTP_PORT=8082 ./pytest/instance.lua & echo $$! >> ./dev/pids
	ALIAS=srv-3 WORKDIR=dev/3303 ADVERTISE_URI=localhost:3303 HTTP_PORT=8083 ./pytest/instance.lua & echo $$! >> ./dev/pids
	ALIAS=srv-4 WORKDIR=dev/3304 ADVERTISE_URI=localhost:3304 HTTP_PORT=8084 ./pytest/instance.lua & echo $$! >> ./dev/pids
	ALIAS=srv-5 WORKDIR=dev/3305 ADVERTISE_URI=localhost:3305 HTTP_PORT=8085 ./pytest/instance.lua & echo $$! >> ./dev/pids
	echo "All instances started!"

stop:
	cat ./dev/pids | xargs kill -SIGINT || true
	rm ./dev/pids

doc:
	ldoc .

schema:
	WORKDIR=dev/gql-schema pytest/instance.lua & \
	PID=$$!; \
	graphql get-schema -o doc/schema.graphql; \
	kill $$PID; \

test:
	tarantoolctl rocks install http 1.0.5-1
	./taptest.lua
	pytest

