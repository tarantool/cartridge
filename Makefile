version := scm-1

.PHONY: all doc test schema install
all: webui/build/bundle.lua
	mkdir -p doc

webui/build/bundle.lua: $(shell find webui/src -type f) webui/node_modules
	npm run build --prefix=webui

test:
	./taptest.lua
	pytest -v

install:
	mkdir -p $(INST_LUADIR)/cluster
	cp webui/build/bundle.lua $(INST_LUADIR)/cluster/front-bundle.lua

webui/node_modules: webui/package.json
	NODE_ENV=production npm ci --prefix=webui
	@ touch $@

doc:
ifeq (${version},scm-1)
	ldoc -t "cluster-${version}" -p "cluster (${version})" --all .
else
	ldoc -t "cluster-${version}" -p "cluster (${version})" .
endif

schema: doc/schema.graphql
doc/schema.graphql: cluster/webui.lua
	WORKDIR=dev/gql-schema pytest/instance.lua & \
	PID=$$!; \
	graphql get-schema -o $@; \
	kill $$PID;
