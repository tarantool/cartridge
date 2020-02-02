local path = (...):gsub('%.[^%.]+$', '')
local types = require(path .. '.types')
local util = require(path .. '.util')
local introspection = require(path .. '.introspection')

local function typeFromAST(node, schema)
  local innerType
  if node.kind == 'listType' then
    innerType = typeFromAST(node.type)
    return innerType and types.list(innerType)
  elseif node.kind == 'nonNullType' then
    innerType = typeFromAST(node.type)
    return innerType and types.nonNull(innerType)
  else
    assert(node.kind == 'namedType', 'Variable must be a named type')
    return schema:getType(node.name.value)
  end
end

local function getFieldResponseKey(field)
  return field.alias and field.alias.name.value or field.name.value
end

local function shouldIncludeNode(selection, context)
  if selection.directives then
    local function isDirectiveActive(key, _type)
      local directive = util.find(selection.directives, function(directive)
        return directive.name.value == key
      end)

      if not directive then return end

      local ifArgument = util.find(directive.arguments, function(argument)
        return argument.name.value == 'if'
      end)

      if not ifArgument then return end

      return util.coerceValue(ifArgument.value, _type.arguments['if'],
                              context.variables, context.defaultValues)
    end

    if isDirectiveActive('skip', types.skip) then return false end
    if isDirectiveActive('include', types.include) == false then return false end
  end

  return true
end

local function doesFragmentApply(fragment, type, context)
  if not fragment.typeCondition then return true end

  local innerType = typeFromAST(fragment.typeCondition, context.schema)

  if innerType == type then
    return true
  elseif innerType.__type == 'Interface' then
    local implementors = context.schema:getImplementors(innerType.name)
    return implementors and implementors[type]
  elseif innerType.__type == 'Union' then
    return util.find(innerType.types, function(member)
      return member == type
    end)
  end
end

local function mergeSelectionSets(fields)
  local selections = {}

  for i = 1, #fields do
    local selectionSet = fields[i].selectionSet
    if selectionSet then
      for j = 1, #selectionSet.selections do
        table.insert(selections, selectionSet.selections[j])
      end
    end
  end

  return selections
end

local function defaultResolver(object, arguments, info)
  return object[info.fieldASTs[1].name.value]
end

local function buildContext(schema, tree, rootValue, variables, operationName)
  local context = {
    schema = schema,
    rootValue = rootValue,
    variables = variables,
    operation = nil,
    fragmentMap = {},
    defaultValues = {},
    request_cache = {},
  }

  for _, definition in ipairs(tree.definitions) do
    if definition.kind == 'operation' then
      if not operationName and context.operation then
        error('Operation name must be specified if more than one operation exists.')
      end

      if not operationName or definition.name.value == operationName then
        context.operation = definition
      end

      for _, variableDefinition in ipairs(definition.variableDefinitions or {}) do
          if variableDefinition.defaultValue ~= nil then
              context.defaultValues[variableDefinition.variable.name.value] =
                  variableDefinition.defaultValue.value

          end
      end
    elseif definition.kind == 'fragmentDefinition' then
      context.fragmentMap[definition.name.value] = definition
    end
  end

  if not context.operation then
    if operationName then
      error('Unknown operation "' .. operationName .. '"')
    else
      error('Must provide an operation')
    end
  end

  return context
end

local function collectFields(objectType, selections, visitedFragments, result, context)
  for _, selection in ipairs(selections) do
    if selection.kind == 'field' then
      if shouldIncludeNode(selection, context) then
        local name = getFieldResponseKey(selection)
        table.insert(result, {name = name, selection = selection})
      end
    elseif selection.kind == 'inlineFragment' then
      if shouldIncludeNode(selection, context) and doesFragmentApply(selection, objectType, context) then
        collectFields(objectType, selection.selectionSet.selections, visitedFragments, result, context)
      end
    elseif selection.kind == 'fragmentSpread' then
      local fragmentName = selection.name.value
      if shouldIncludeNode(selection, context) and not visitedFragments[fragmentName] then
        visitedFragments[fragmentName] = true
        local fragment = context.fragmentMap[fragmentName]
        if fragment and shouldIncludeNode(fragment, context) and doesFragmentApply(fragment, objectType, context) then
          collectFields(objectType, fragment.selectionSet.selections, visitedFragments, result, context)
        end
      end
    end
  end

  return result
end

local evaluateSelection
local serializemap = {__serialize='map'}

local function completeValue(fieldType, result, subSelections, context, opts)
  local fieldName = opts and opts.fieldName or '???'
  local fieldTypeName = fieldType.__type

  if fieldTypeName == 'NonNull' then
    local innerType = fieldType.ofType
    local completedResult = completeValue(innerType, result, subSelections, context, opts)

    if completedResult == nil then
      local err = string.format(
        'No value provided for non-null %s %q',
        (innerType.name or innerType.__type),
        fieldName
      )
      error(err)
    end

    return completedResult
  end

  if result == nil then
    return nil
  end

  if fieldTypeName == 'List' then
    local innerType = fieldType.ofType

    if type(result) ~= 'table' then
      error('Expected a table for ' .. innerType.name .. ' list')
    end

    local values = {}
    for i, value in ipairs(result) do
      values[i] = completeValue(innerType, value, subSelections, context)
    end

    return values
  end

  if fieldTypeName == 'Scalar' or fieldTypeName == 'Enum' then
    return fieldType.serialize(result)
  end

  if fieldTypeName == 'Object' then
    local completed = evaluateSelections(fieldType, result, subSelections, context)
    setmetatable(completed, serializemap)
    return completed
  elseif fieldTypeName == 'Interface' or fieldTypeName == 'Union' then
    local objectType = fieldType.resolveType(result)
    local completed = evaluateSelections(objectType, result, subSelections, context)
    setmetatable(completed, serializemap)
    return completed
  end

  error('Unknown type "' .. fieldTypeName .. '" for field "' .. fieldName .. '"')
end

local function getFieldEntry(objectType, object, fields, context)
  local firstField = fields[1]
  local fieldName = firstField.name.value
  local responseKey = getFieldResponseKey(firstField)
  local fieldType = introspection.fieldMap[fieldName] or objectType.fields[fieldName]

  if fieldType == nil then
    return nil
  end

  local argumentMap = {}
  for _, argument in ipairs(firstField.arguments or {}) do
    argumentMap[argument.name.value] = argument
  end

  local arguments = util.map(fieldType.arguments or {}, function(argument, name)
    local supplied = argumentMap[name] and argumentMap[name].value

    local value = supplied and util.coerceValue(supplied, argument,
                                                context.variables,
                                                context.defaultValues)
    if value ~= nil then
      return value
    end

    return argument.defaultValue
  end)

  --[[
      Make arguments ordered map using metatble.
      This way callback can use positions to access argument values.
      For example buisness logic depends on argument positions to choose
      appropriate storage iteration.
  ]]
  local positions = {}
  local pos = 1
  for _, argument in ipairs(firstField.arguments or {}) do
      if argument and argument.value then
          positions[pos] = {
              name=argument.name.value,
              value=arguments[argument.name.value]
          }
          pos = pos + 1
      end
  end

  arguments = setmetatable(arguments, {__index=positions})

  local info = {
    context = context,
    fieldName = fieldName,
    fieldASTs = fields,
    returnType = fieldType.kind,
    parentType = objectType,
    schema = context.schema,
    fragments = context.fragmentMap,
    rootValue = context.rootValue,
    operation = context.operation,
    variableValues = context.variables,
    defaultValues = context.defaultValues,
  }

  local resolvedObject, err = (fieldType.resolve or defaultResolver)(object, arguments, info)
  if err ~= nil then
    error(err)
  end

  local subSelections = mergeSelectionSets(fields)
  return completeValue(fieldType.kind, resolvedObject, subSelections, context,
    {fieldName = fieldName}
  )
end

evaluateSelections = function(objectType, object, selections, context)
  local result = {}
  local fields = collectFields(objectType, selections, {}, {}, context)
  for _, field in ipairs(fields) do
    assert(result[field.name] == nil,
      'two selections into the one field: ' .. field.name)
    result[field.name] = getFieldEntry(objectType, object, {field.selection},
                                       context)

    if result[field.name] == nil then
        result[field.name] = box.NULL
    end
  end
  return result
end

local function execute(schema, tree, rootValue, variables, operationName)
  local context = buildContext(schema, tree, rootValue, variables, operationName)
  local rootType = schema[context.operation.operation]

  if not rootType then
    error('Unsupported operation "' .. context.operation.operation .. '"')
  end

  return evaluateSelections(rootType, rootValue, context.operation.selectionSet.selections, context)
end


return {execute=execute}
