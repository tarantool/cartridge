local t = require('luatest')
local g = t.group('integration_api')

local helper = require('test.helper.integration')
local cluster = helper.cluster

local function assert_http_json_request(method, path, body, expected)
    checks('string', 'string', '?table', 'table')
    local response = cluster.main_server:http_request(method, path,
            {
                json=body,
                headers={["content-type"]="application/json; charset=utf-8"},
                raw=true
            }
        )

    if expected.body then
        t.assert_equals(response.json, expected.body)
        return response.json
    end

    t.assert_equals(response.status, expected.status)

    return response
end


local customers = {
    ['A'] = {
        customer_id = 42,
        name = "Alice",
        accounts = {
            ['main'] = 10,
            ['car']  = 26,
        }
    },

    ['B'] = {
        customer_id = 15,
        name = "Bob",
        accounts = {
            ['main']   = 31,
            ['future'] = 47,
            ['kids']   = 63,
        }
    },
}

g.test_transaction_chain = function()
    local transactions = { -- {'NameKey', 'AccountName', delta }
        { 'A', 'main', 1000 },   { 'B', 'main', 250 },
        { 'A', 'car', 50.13 },   { 'B', 'future', 250 },
        { 'A', 'main', 50 },     { 'B', 'kids', -0.25 },
        { 'A', 'car', -50 },     { 'B', 'future', 416 },
        { 'A', 'main', -50.07 }, { 'B', 'main', 15.45 },
        -- TODO: can it be better to generate transactions randomly?
    }

    local accumulator = {}

    for _, customer in pairs(customers) do
        local user = table.deepcopy(customer)
        user.accounts = {}
        for acc_name, acc_id in pairs(customer.accounts) do
            table.insert(user.accounts, {
                name = acc_name,
                account_id = acc_id,
                balance = "0.00"
            })
            accumulator[acc_id] = 0
        end

        assert_http_json_request('post', '/storage/customers/create',
            user,
            {status = 201}
        )
    end

    for key, customer in pairs(customers) do
        local user_info = table.deepcopy(customer)
        user_info.bucket_id = nil
        user_info.accounts = {}

        for acc_name, acc_id in pairs(customer.accounts) do
            table.insert(user_info.accounts, {
                name = acc_name,
                account_id = acc_id,
                balance = "0.00"
            })
        end

        local response = assert_http_json_request('get',
            '/storage/customers/'..tostring(customer.customer_id),
            nil, {
                status = 200,
            }
        )
        t.assert(response.json)
        response = response.json
        t.assert_items_equals(response.accounts, user_info.accounts)
        t.assert(response.customer_id, user_info.customer_id)
        t.assert(response.name, user_info.name)

    end

    for _, transaction in pairs(transactions) do
        local key, acc_name, delta = unpack(transaction)
        local acc_id = customers[key].accounts[acc_name]
        accumulator[acc_id] = accumulator[acc_id] + delta

        local response = assert_http_json_request('post',
            '/storage/customers/'..tostring(customers[key].customer_id) .. '/update_balance',
            {
                account_id = acc_id,
                amount = tostring(delta)
            }, {
                status = 200,
            }
        )

        t.assert(response.json.balance)
        t.assert_almost_equals(tonumber(response.json.balance), accumulator[acc_id], 10-5)
    end
end