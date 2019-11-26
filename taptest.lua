#!/usr/bin/env tarantool

local fio = require('fio')

local function find_tests(dir)
    local files = fio.listdir(dir)
    local res = {}

    for _, file in ipairs(files) do
        local fullpath = fio.pathjoin(dir, file)

        if fio.path.is_dir(fullpath) then
            local subres = find_tests(fullpath)
            for _,v in pairs(subres) do table.insert(res, v) end
        elseif fio.path.is_file(fullpath) then
            if (string.startswith(file, "test_") and
                    string.endswith(file, ".lua")) or
            string.endswith(file, "_test.lua") then
                table.insert(res, fullpath)
            end
        end
    end

    return res
end

local function run()
    local failed_tests = {}

    local files = find_tests('./test/unit')

    for _, file in ipairs(files) do
        print("Running tests from: " .. file)

        local res = os.execute([[tarantool -e "require('luacov')" ]] .. file)
        if res ~= 0 then
            table.insert(failed_tests, file)
        end
    end

    return failed_tests
end

local failed_tests = run()

if #failed_tests > 0 then
    print('failed tests:')
    for _, file in pairs(failed_tests) do
        print('    ' .. file)
    end
    print(string.format("%d tests failed", #failed_tests))
    os.exit(1)
end

os.exit(0)
