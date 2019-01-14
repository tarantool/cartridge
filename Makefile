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
	echo "# GraphQL schema\n" > dev/GraphQL.md
	echo '```' >> dev/GraphQL.md
	cat dev/schema.graphql >> dev/GraphQL.md
	echo '```' >> dev/GraphQL.md
	ldoc .

schema:
	WORKDIR=dev/gql-schema pytest/instance.lua & \
	PID=$$!; \
	graphql get-schema -o dev/schema.graphql; \
	kill $$PID; \

test:
	./taptest.lua
	pytest

