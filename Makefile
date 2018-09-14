all:
	docker build -t build-admin-ui .
	docker rm -f build-admin-ui || true
	docker create --rm --name build-admin-ui build-admin-ui
	docker cp build-admin-ui:/tarantool-enterprise-admin-ui.tar.gz ./tarantool-enterprise-admin-ui-$(ADMIN_UI_VERSION).tar.gz
	docker rm -f build-admin-ui || true
