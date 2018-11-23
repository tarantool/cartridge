DIR := webui
.PHONY: all install doc test

all: $(DIR)/node_modules
	npm run build --prefix=$(DIR)

$(DIR)/node_modules: $(DIR)/package.json
	npm install --prefix=$(DIR)
	@ touch $@

install:
	mkdir -p $(INST_LUADIR)/cluster
	tarantool pack.lua $(DIR)/build $(INST_LUADIR)/cluster/webui-static.lua

doc:
	ldoc .

test:
	tarantoolctl rocks install http 1.0.5-1
	./taptest.lua
	pytest

