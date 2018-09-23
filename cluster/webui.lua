#!/usr/bin/env tarantool

local log = require('log')
local fun = require('fun')
local fio = require('fio')
local json = require('json')
local yaml = require('yaml').new()
local errors = require('errors')
local uuid_lib = require('uuid')
local membership = require('membership')

local admin = require('cluster.admin')
local static = require('cluster.webui-static')
local graphql = require('cluster.graphql')
local gql_types = require('cluster.graphql.types')

yaml.cfg({
    encode_use_tostring = true
})

local statistics_schema = {
    kind = gql_types.object {
        name='ServerStat',
        desciprtion = 'Slab allocator statistics.' ..
            ' This can be used to monitor the total' ..
            ' memory usage and memory fragmentation.',
        fields={
            items_size = gql_types.long,
            items_used_ratio = gql_types.string,
            quota_size = gql_types.long,
            quota_used_ratio = gql_types.string,
            arena_used_ratio = gql_types.string,
            items_used = gql_types.long,
            quota_used = gql_types.long,
            arena_size = gql_types.long,
            arena_used = gql_types.long,
        }
    },
    arguments = {},
    description = 'Node statistics',
    resolve = function(self, args)
        -- TODO stat.graphql_stat,
        return {}
    end,
}

gql_types.object {
    name = 'Server',
    description = 'A server participating in tarantool cluster',
    fields = {
        alias = gql_types.string,
        uri = gql_types.string.nonNull,
        uuid = gql_types.string.nonNull,
        status = gql_types.string.nonNull,
        message = gql_types.string.nonNull,
        statistics = statistics_schema,
        replicaset = gql_types.object {
            name = 'Replicaset',
            description = 'Group of servers replicating the same data',
            fields = {
                uuid = gql_types.string.nonNull,
                roles = gql_types.list(gql_types.string.nonNull),
                status = gql_types.string.nonNull,
                servers = gql_types.list('Server'),
            }
        },
    }
}



-- local function render_root()
--     local fullpath = fio.pathjoin(env.binarydir, '_front_output', 'index.html')
--     return http.render_file(fullpath)
-- end

-- local function render_doc_file(req)
--     local relpath = req.path:match('^/docs/(.+)$')
--     local fullpath = fio.pathjoin(env.binarydir, '_doc_output', relpath)
--     return http.render_file(fullpath)
-- end

-- local upload_error = errors.new_class('Config upload failed')
-- local function upload_config(req)
--     local body = req:read()
--     if body == nil then
--         return {
--             status = 400,
--             body = json.encode(upload_error:new('empty request body'))
--         }
--     end
--     log.info('Config uploaded')

--     local content_type = req.headers['content-type']
--     local content_type, boundary = content_type:match('(multipart/form%-data); boundary=(.+)')
--     if content_type == 'multipart/form-data' then
--         body = body:match(boundary..'.-\r\n\r\n(.+)\r\n'..boundary)
--     end

--     local tempdir = fio.tempdir()
--     local tempzip = tempdir..'/config.zip'
--     local ok, err = utils.write_file(tempzip, body)
--     if not ok then
--         fio.rmdir(tempdir)
--         log.error(tostring(err))
--         -- log.error(err)
--         return {
--             status = 500,
--             body = json.encode(err),
--         }
--     end
--     log.info('Config saved to ' .. tempzip)

--     local cmd = string.format('unzip -o -d %s %s', tempdir, tempzip)
--     local ret = os.execute(cmd)
--     if ret ~= 0 then
--         err = upload_error:new('unzip non-zero return code %d', ret)
--         fio.rmdir(tempdir)
--         log.error(tostring(err))
--         return {
--             status = 500,
--             body = json.encode(err),
--         }
--     end
--     log.info('Config unzipped')

--     local conf_new, err = confapplier.read_from_file(fio.pathjoin(tempdir, 'config.yml'))
--     fio.rmdir(tempdir)
--     if not conf_new then
--         log.error(tostring(err))
--         return {
--             status = 400,
--             body = json.encode(err),
--         }
--     end
--     log.info('Config parsed')

--     local conf_old, err = confapplier.get_current()
--     if not conf_old then
--         return {
--             status = 500,
--             body = json.encode(err),
--         }
--     end

--     if not conf_new.servers then
--         conf_new.servers = conf_old.servers
--     end

--     if not conf_new.bucket_count then
--         conf_new.bucket_count = conf_old.bucket_count
--     end

--     conf_new, err = model_ddl.config_save_ddl(conf_old, conf_new)
--     if conf_new == nil then
--         log.error(tostring(err))
--         return {
--             status = 400,
--             body = json.encode(err),
--         }
--     end

--     local instance_uuid, err = confapplier.validate(conf_new)
--     if not instance_uuid then
--         log.error(tostring(err))
--         return {
--             status = 400,
--             body = json.encode(err),
--         }
--     end
--     log.info('Config validated')

--     local ok, err = confapplier.validate_and_apply_clusterwide(conf_new)
--     if not ok then
--         log.error(tostring(err))
--         return {
--             status = 400,
--             body = json.encode(err),
--         }
--     end
--     log.info('Config applied')

--     return {
--         status = 200,
--         headers = {
--             ['content-type'] = "text/html; charset=utf-8"
--         },
--         body = 'Config applied',
--     }
-- end

-- local download_error = errors.new_class('Config download failed')
-- local function download_config(req)
--     local tempdir = fio.tempdir()
--     local function finalize_error(http_code, err)
--         fio.rmdir(tempdir)
--         log.error(tostring(err))
--         return {
--             status = http_code,
--             body = json.encode(err),
--         }
--     end

--     local conf, err = confapplier.get_current()
--     if not conf then
--         return finalize_error(500, err)
--     end
--     conf.servers = nil
--     conf.bucket_count = nil

--     local ok, err = utils.write_file(tempdir..'/model.avsc', conf['types'])
--     if not ok then
--         return finalize_error(500, err)
--     end
--     conf.types = {__file = 'model.avsc'}

--     for fn, code in pairs(conf.functions or {}) do
--         local filename = fn .. '.lua'
--         local ok, err = utils.write_file(tempdir..'/'..filename, code)
--         if not ok then
--             return finalize_error(500, err)
--         end
--         conf.functions[fn] = {__file = filename}
--     end

--     local tconnect_conf = conf['t-connect'] or {}
--     for _, input in pairs(tconnect_conf.input or {}) do
--         if input.wsdl then
--             local ok, err = utils.write_file(tempdir..'/WSIBConnect.wsdl', input.wsdl)
--             if not ok then
--                 return finalize_error(500, err)
--             end
--             input.wsdl = {__file = 'WSIBConnect.wsdl'}
--         end
--     end

--     local ok, err = utils.write_file(tempdir..'/config.yml', yaml.encode(conf))
--     if not ok then
--         return finalize_error(500, err)
--     end

--     local tempzip = tempdir..'/config.zip'
--     local cmd = string.format('zip -j -r %s %s', tempzip, tempdir)
--     local ret = os.execute(cmd)
--     if ret == 0 then
--         -- ok
--     else
--         err = download_error:new('zip non-zero return code %d', ret)
--         return finalize_error(500, err)
--     end
--     log.info('Config zipped')

--     local raw, err = utils.read_file(tempzip)
--     if not raw then
--         return finalize_error(500, err)
--     end

--     fio.rmdir(tempdir)
--     return {
--         status = 200,
--         headers = {
--             ['content-type'] = "application/zip",
--             ['content-disposition'] = 'attachment; filename="config.zip"',
--         },
--         body = raw,
--     }
-- end

local function get_servers(_, args)
    return admin.get_servers(args.uuid)
end

local function get_replicasets(_, args)
    return admin.get_replicasets(args.uuid)
end

local function probe_server(_, args)
    return admin.probe_server(args.uri)
end

local function join_server(_, args)
    return admin.join_server(args)
end

local function edit_server(_, args)
    return admin.edit_server(args)
end

local function expell_server(_, args)
    return admin.expell_server(args.uuid)
end

local function edit_replicaset(_, args)
    return admin.edit_replicaset(args)
end

local function file_mime_type(filename)
    if string.endswith(filename, ".css") then
        return "text/css; charset=utf-8"
    elseif string.endswith(filename, ".js") then
        return "application/javascript; charset=utf-8"
    elseif string.endswith(filename, ".html") then
        return "text/html; charset=utf-8"
    elseif string.endswith(filename, ".jpeg") then
        return "image/jpeg"
    elseif string.endswith(filename, ".jpg") then
        return "image/jpeg"
    elseif string.endswith(filename, ".gif") then
        return "image/gif"
    elseif string.endswith(filename, ".png") then
        return "image/png"
    elseif string.endswith(filename, ".svg") then
        return "image/svg+xml"
    elseif string.endswith(filename, ".ico") then
        return "image/x-icon"
    elseif string.endswith(filename, "manifest.json") then
        return "application/manifest+json"
    end

    return "application/octet-stream"
end

local function render_file(path)
    local body = static[path]

    if body == nil then
        return {
            status = 404,
            body = string.format('File does not exist: %q', path)
        }
    end

    return {
        status = 200,
        headers = {
            ['content-type'] = file_mime_type(path)
        },
        body = body,
    }
end

local function init(httpd)
    -- httpd:route(
    --     {
    --         method = 'POST',
    --         path = '/config',
    --     },
    --     upload_config
    -- )

    -- httpd:route(
    --     {
    --         method = 'GET',
    --         path = '/config',
    --     },
    --     download_config
    -- )

    -- http.add_route({ public = true,
    --                  path = '/login', method = 'POST' }, 'common.admin.users', 'login')
    -- http.add_route({ path = '/logout', method = 'GET' }, 'common.admin.users', 'logout')



    graphql.init(httpd)
    graphql.add_mutation_prefix('cluster', 'Cluster management')
    graphql.add_callback_prefix('cluster', 'Cluster management')

    graphql.add_callback({
        name = 'servers',
        args = {
            uuid = gql_types.string
        },
        kind = gql_types.list('Server'),
        callback = 'cluster.webui.get_servers',
    })

    graphql.add_callback({
        name = 'replicasets',
        args = {
            uuid = gql_types.string
        },
        kind = gql_types.list('Replicaset'),
        callback = 'cluster.webui.get_replicasets',
    })

    graphql.add_mutation({
        name = 'probe_server',
        args = {
            uri = gql_types.string.nonNull
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.probe_server',
    })

    graphql.add_mutation({
        name = 'join_server',
        args = {
            uri = gql_types.string.nonNull,
            instance_uuid = gql_types.string,
            replicaset_uuid = gql_types.string,
            roles = gql_types.list(gql_types.string.nonNull),
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.join_server',
    })

    graphql.add_mutation({
        name = 'edit_server',
        args = {
            uuid = gql_types.string.nonNull,
            uri = gql_types.string.nonNull,
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.edit_server',
    })

    graphql.add_mutation({
        name = 'expell_server',
        args = {
            uuid = gql_types.string.nonNull,
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.expell_server',
    })

    graphql.add_mutation({
        name = 'edit_replicaset',
        args = {
            uuid = gql_types.string.nonNull,
            roles = gql_types.list(gql_types.string.nonNull),
        },
        kind = gql_types.boolean,
        callback = 'cluster.webui.edit_replicaset',
    })

    -- graphql.add_mutation({
    --     prefix = 'cluster',
    --     name = 'load_config_example',
    --     doc = 'Loads example config',
    --     args = {},
    --     kind = gql_types.boolean,
    --     callback = 'cluster.webui.load_config_example',
    -- })

    graphql.add_callback({
        prefix = 'cluster',
        name = 'self',
        doc = 'Get current server',
        args = {},
        kind = gql_types.object({
            name = 'ServerShortInfo',
            description = 'A short server information',
            fields = {
                uri = gql_types.string.nonNull,
                uuid = gql_types.string,
                alias = gql_types.string,
            },
        }),
        callback = 'cluster.webui.get_self',
    })

    -- graphql.add_mutation({
    --     prefix = 'cluster',
    --     name = 'evaluate',
    --     doc = 'Returns evaluated string on local or remote node',
    --     args = {
    --         eval = gql_types.string,
    --         uri = gql_types.string,
    --     },
    --     kind = gql_types.string,
    --     callback = 'ib-common.admin.graphql_evaluate',
    -- })

    httpd:route({
            method = 'GET',
            path = '/',
            public = true,
        },
        function(req)
            return render_file('index.html')
        end
    )
    httpd:route({
            method = 'GET',
            path = '/index.html',
            public = true,
        },
        function(req)
            return { status = 404, body = '404 Not Found' }
        end
    )

    -- Paths w/o dot are treated as app routes
    httpd:route({
            method = 'GET',
            path = '/[^.]*',
            public = true,
        },
        function(req)
            return render_file('index.html')
        end
    )

    -- All other paths are treaded as file paths
    httpd:route({
            method = 'GET',
            path = '/.*',
            public = true,
        },
        function(req)
            return render_file(req.path)
        end
    )

    return true
end

return {
    init = init,
    -- render_root = render_root,
    -- render_doc_file = render_doc_file,

    get_self = admin.get_self,
    get_servers = get_servers,
    get_replicasets = get_replicasets,

    probe_server = probe_server,
    join_server = join_server,
    edit_server = edit_server,
    edit_replicaset = edit_replicaset,
    expell_server = expell_server,

    -- graphql_evaluate = graphql_evaluate,
}
