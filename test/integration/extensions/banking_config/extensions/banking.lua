local checks = require('checks')
-- local extensions = require('cartridge').service_get('extensions')

local function customer_add(customer_id, fullname)
    checks('number', 'string')
    return box.space.customer:insert(
        {customer_id, fullname}
    )
end

local function account_add(customer_id, account_id, name)
    checks('number', 'number', 'string')
    return box.space.account:insert(
        {customer_id, account_id, name, 0}
    )
end

local function transfer_money(account_from, account_to, amount)
    box.begin()
    box.space.account:update({account_to}, {{'+', 'balance', amount}})
    box.space.account:update({account_from}, {{'-', 'balance', amount}})
    box.commit()
    return true
end

return {
    customer_add = customer_add,
    account_add = account_add,
    transfer_money = transfer_money,
}
