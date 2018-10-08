#!/usr/bin/env tarantool

local fio = require('fio')

function merge(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            merge(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end

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

    local files = find_tests('./taptest')

    for _, file in ipairs(files) do
        print("Running tests from: " .. file)

        local res = os.execute('tarantool ' .. file)
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
