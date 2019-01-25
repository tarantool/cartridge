version := scm-1

.PHONY: all doc test schema install
all: webui/node_modules
	npm run build --prefix=webui
	mkdir -p doc

test:
	./taptest.lua
	pytest

install:
	mkdir -p $(INST_LUADIR)/cluster
	cp webui/build/bundle.lua $(INST_LUADIR)/cluster/front-bundle.lua

webui/node_modules: webui/package.json
	npm install --production --prefix=webui
	@ touch $@

doc: dev/GraphQL.md
	ldoc -t "cluster-${version}" -p "cluster (${version})" .

dev/GraphQL.md: doc/schema.graphql
	echo "# GraphQL schema\n" > $@
	echo '```' >> $@
	cat $< >> $@
	echo '```' >> $@

schema: doc/schema.graphql
doc/schema.graphql: cluster/webui.lua
	WORKDIR=dev/gql-schema pytest/instance.lua & \
	PID=$$!; \
	graphql get-schema -o $@; \
	kill $$PID;
