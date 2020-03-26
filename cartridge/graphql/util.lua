local yaml = require('yaml').new({encode_use_tostring = true})

local function map(t, fn)
  local res = {}
  for k, v in pairs(t) do res[k] = fn(v, k) end
  return res
end

local function find(t, fn)
  for k, v in pairs(t) do
    if fn(v, k) then return v end
  end
end

local function filter(t, fn)
  local res = {}
  for _,v in pairs(t) do
    if fn(v) then
      table.insert(res, v)
    end
  end
  return res
end

local function values(t)
  local res = {}
  for _, value in pairs(t) do
    table.insert(res, value)
  end
  return res
end

local function compose(f, g)
  return function(...) return f(g(...)) end
end

local function bind1(func, x)
  return function(y)
    return func(x, y)
  end
end

local function trim(s)
  return s:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s%s+', ' ')
end

local function getTypeName(t)
  if t.name ~= nil then
    return t.name
  elseif t.__type == 'NonNull' then
    return ('NonNull(%s)'):format(getTypeName(t.ofType))
  elseif t.__type == 'List' then
    return ('List(%s)'):format(getTypeName(t.ofType))
  end

  local err = ('Internal error: unknown type:\n%s'):format(yaml.encode(t))
  error(err)
end

local function coerceValue(node, schemaType, variables, opts)
  variables = variables or {}
  opts = opts or {}
  local strict_non_null = opts.strict_non_null or false

  if schemaType.__type == 'NonNull' then
    local res = coerceValue(node, schemaType.ofType, variables, opts)
    if strict_non_null and res == nil then
      error(('Expected non-null for "%s", got null'):format(
        getTypeName(schemaType)))
    end
    return res
  end

  if not node then
    return nil
  end

  -- handle precompiled values
  if node.compiled ~= nil then
    return node.compiled
  end

  if node.kind == 'variable' then
    return variables[node.name.value]
  end

  if schemaType.__type == 'List' then
    if node.kind ~= 'list' then
      error('Expected a list')
    end

    return map(node.values, function(value)
      return coerceValue(value, schemaType.ofType, variables, opts)
    end)
  end

  local isInputObject = schemaType.__type == 'InputObject'
  if isInputObject then
    if node.kind ~= 'inputObject' then
      error('Expected an input object')
    end

    -- check all fields: as from value as well as from schema
    local fieldNameSet = {}
    local fieldValues = {}
    for _, field in ipairs(node.values) do
        fieldNameSet[field.name] = true
        fieldValues[field.name] = field.value
    end
    for fieldName, _ in pairs(schemaType.fields) do
        fieldNameSet[fieldName] = true
    end

    local inputObjectValue = {}
    for fieldName, _ in pairs(fieldNameSet) do
      if not schemaType.fields[fieldName] then
        error(('Unknown input object field "%s"'):format(fieldName))
      end

      local childValue = fieldValues[fieldName]
      local childType = schemaType.fields[fieldName].kind
      inputObjectValue[fieldName] = coerceValue(childValue, childType,
        variables, opts)
    end

    return inputObjectValue
  end

  if schemaType.__type == 'Enum' then
    if node.kind ~= 'enum' then
      error(('Expected enum value, got %s'):format(node.kind))
    end

    if not schemaType.values[node.value] then
      error(('Invalid enum value "%s"'):format(node.value))
    end

    return node.value
  end

  if schemaType.__type == 'Scalar' then
    if schemaType.parseLiteral(node) == nil then
      error(('Could not coerce "%s" to "%s"'):format(
        tostring(node.value), schemaType.name))
    end

    return schemaType.parseLiteral(node)
  end
end

return {
  map = map,
  find = find,
  filter = filter,
  values = values,
  compose = compose,
  bind1 = bind1,
  trim = trim,
  getTypeName = getTypeName,
  coerceValue = coerceValue,
}
