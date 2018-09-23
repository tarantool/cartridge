DIR := webui
.PHONY: all install

all: $(DIR)/node_modules
	npm run build --prefix=$(DIR)

$(DIR)/node_modules: $(DIR)/package.json
	npm install --prefix=$(DIR)
	@ touch $@

install:
	mkdir -p $(INST_LUADIR)/cluster
	$(LUA) pack.lua $(DIR)/build $(INST_LUADIR)/cluster/webuil-static.lua
