return {
    init = function(opts)
        if opts.is_master then
            assert(box.info.ro == false)
            box.schema.space.create('test', { if_not_exists = true })
            box.space.test:format{
                {'bucket_id', 'unsigned'},
                {'key', 'string'},
                {'value', 'any'},
            }
            box.space.test:create_index('primary', {
                parts = {'key'},
                if_not_exists = true,
            })
            box.space.test:create_index('bucket_id', {
                parts = {'bucket_id'},
                if_not_exists = true,
                unique = false,
            })
        end
    end,
    dependencies = { 'cartridge.roles.vshard-storage' },
}
