DIR := webui
.PHONY: all install doc test schema

all: $(DIR)/node_modules
	npm run build --prefix=$(DIR)

$(DIR)/node_modules: $(DIR)/package.json
	npm install --production --prefix=$(DIR)
	@ touch $@

install:
	mkdir -p $(INST_LUADIR)/cluster
	cp $(DIR)/build/bundle.lua $(INST_LUADIR)/cluster/front-bundle.lua

doc:
	ldoc .

schema:
	WORKDIR=dev/gql-schema pytest/instance.lua & \
	PID=$$!; \
	graphql get-schema -o doc/schema.graphql; \
	kill $$PID; \

test:
	./taptest.lua
	pytest

