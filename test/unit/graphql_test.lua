local t = require('luatest')
local g = t.group()

local parse = require('cartridge.graphql.parse').parse
function g.test_parse_comments()
    t.assert_equals(parse('#').definitions, {})
    t.assert_equals(parse('#{}').definitions, {})
    t.assert_not_equals(parse('{}').definitions, {})

    t.assert_error(parse('{}#a$b@').definitions, {})
    t.assert_error(parse('{a(b:"#")}').definitions, {})
end

function g.test_parse_document()
    t.assert_error(parse)
    t.assert_error(parse, 'foo')
    t.assert_error(parse, 'query')
    t.assert_error(parse, 'query{} foo')

    t.assert_covers(parse(''), { kind = 'document', definitions = {} })
    t.assert_equals(parse('query{} mutation{} {}').kind, 'document')
    t.assert_equals(#parse('query{} mutation{} {}').definitions, 3)
end

function g.test_parse_operation_shorthand()
    local operation = parse('{}').definitions[1]
    t.assert_equals(operation.kind, 'operation')
    t.assert_equals(operation.name, nil)
    t.assert_equals(operation.operation, 'query')
end

function g.test_parse_operation_operationType()
    local operation = parse('query{}').definitions[1]
    t.assert_equals(operation.operation, 'query')

    operation = parse('mutation{}').definitions[1]
    t.assert_equals(operation.operation, 'mutation')

    t.assert_error(parse, 'kneeReplacement{}')
end

function g.test_parse_operation_name()
    local operation = parse('query{}').definitions[1]
    t.assert_equals(operation.name, nil)

    operation = parse('query queryName{}').definitions[1]
    t.assert_not_equals(operation.name, nil)
    t.assert_equals(operation.name.value, 'queryName')
end

function g.test_parse_operation_variableDefinitions()
    t.assert_error(parse, 'query(){}')
    t.assert_error(parse, 'query(x){}')

    local operation = parse('query name($a:Int,$b:Int){}').definitions[1]
    t.assert_equals(operation.name.value, 'name')
    t.assert_not_equals(operation.variableDefinitions, nil)
    t.assert_equals(#operation.variableDefinitions, 2)

    operation = parse('query($a:Int,$b:Int){}').definitions[1]
    t.assert_not_equals(operation.variableDefinitions, nil)
    t.assert_equals(#operation.variableDefinitions, 2)
end

function g.test_parse_operation_directives()
    local operation = parse('query{}').definitions[1]
    t.assert_equals(operation.directives, nil)

    operation = parse('query @a{}').definitions[1]
    t.assert_not_equals(operation.directives, nil)

    operation = parse('query name @a{}').definitions[1]
    t.assert_not_equals(operation.directives, nil)

    operation = parse('query ($a:Int) @a {}').definitions[1]
    t.assert_not_equals(operation.directives, nil)

    operation = parse('query name ($a:Int) @a {}').definitions[1]
    t.assert_not_equals(operation.directives, nil)
end

function g.test_parse_fragmentDefinition_fragmentName()
    t.assert_error(parse, 'fragment {}')
    t.assert_error(parse, 'fragment on x {}')
    t.assert_error(parse, 'fragment on on x {}')

    local fragment = parse('fragment x on y {}').definitions[1]
    t.assert_equals(fragment.kind, 'fragmentDefinition')
    t.assert_equals(fragment.name.value, 'x')
end

function g.test_parse_fragmentDefinition_typeCondition()
    t.assert_error(parse, 'fragment x {}')

    local fragment = parse('fragment x on y {}').definitions[1]
    t.assert_equals(fragment.typeCondition.name.value, 'y')
end

function g.test_parse_fragmentDefinition_selectionSet()
    t.assert_error(parse, 'fragment x on y')

    local fragment = parse('fragment x on y {}').definitions[1]
    t.assert_not_equals(fragment.selectionSet, nil)
end

function g.test_parse_selectionSet()
    t.assert_error(parse, '{')
    t.assert_error(parse, '}')

    local selectionSet = parse('{}').definitions[1].selectionSet
    t.assert_equals(selectionSet.kind, 'selectionSet')
    t.assert_equals(selectionSet.selections, {})

    selectionSet = parse('{a b}').definitions[1].selectionSet
    t.assert_equals(#selectionSet.selections, 2)
end

function g.test_parse_field_name()
    t.assert_error(parse, '{$a}')
    t.assert_error(parse, '{@a}')
    t.assert_error(parse, '{.}')
    t.assert_error(parse, '{,}')

    local field = parse('{a}').definitions[1].selectionSet.selections[1]
    t.assert_equals(field.kind, 'field')
    t.assert_equals(field.name.value, 'a')
end

function g.test_parse_field_alias()
    t.assert_error(parse, '{a:b:}')
    t.assert_error(parse, '{a:b:c}')
    t.assert_error(parse, '{:a}')

    local field = parse('{a}').definitions[1].selectionSet.selections[1]
    t.assert_equals(field.alias, nil)

    field = parse('{a:b}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(field.alias, nil)
    t.assert_equals(field.alias.kind, 'alias')
    t.assert_equals(field.alias.name.value, 'a')
    t.assert_equals(field.name.value, 'b')
end

function g.test_parse_field_arguments()
    t.assert_error(parse, '{a()}')

    local field = parse('{a}').definitions[1].selectionSet.selections[1]
    t.assert_equals(field.arguments, nil)

    field = parse('{a(b:false)}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(field.arguments, nil)
end

function g.test_parse_field_directives()
    t.assert_error(parse, '{a@skip(b:false)(c:true)}')

    local field = parse('{a}').definitions[1].selectionSet.selections[1]
    t.assert_equals(field.directives, nil)

    field = parse('{a@skip}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(field.directives, nil)

    field = parse('{a(b:1)@skip}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(field.directives, nil)
end

function g.test_parse_field_selectionSet()
    t.assert_error(parse, '{{}}')

    local field = parse('{a}').definitions[1].selectionSet.selections[1]
    t.assert_equals(field.selectionSet, nil)

    field = parse('{a{}}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(field.selectionSet, nil)

    field = parse('{a{a}}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(field.selectionSet, nil)

    field = parse('{a(b:1)@skip{a}}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(field.selectionSet, nil)
end

function g.test_parse_fragmentSpread_name()
    t.assert_error(parse, '{..a}')
    t.assert_error(parse, '{...}')

    local fragmentSpread = parse('{...a}').definitions[1].selectionSet.selections[1]
    t.assert_equals(fragmentSpread.kind, 'fragmentSpread')
    t.assert_equals(fragmentSpread.name.value, 'a')
end

function g.test_parse_fragmentSpread_directives()
    t.assert_error(parse, '{...a@}')

    local fragmentSpread = parse('{...a}').definitions[1].selectionSet.selections[1]
    t.assert_equals(fragmentSpread.directives, nil)

    fragmentSpread = parse('{...a@skip}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(fragmentSpread.directives, nil)
end

function g.test_parse_inlineFragment_typeCondition()
    t.assert_error(parse, '{...on{}}')

    local inlineFragment = parse('{...{}}').definitions[1].selectionSet.selections[1]
    t.assert_equals(inlineFragment.kind, 'inlineFragment')
    t.assert_equals(inlineFragment.typeCondition, nil)

    inlineFragment = parse('{...on a{}}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(inlineFragment.typeCondition, nil)
    t.assert_equals(inlineFragment.typeCondition.name.value, 'a')
end

function g.test_parse_inlineFragment_directives()
    t.assert_error(parse, '{...on a @ {}}')
    local inlineFragment = parse('{...{}}').definitions[1].selectionSet.selections[1]
    t.assert_equals(inlineFragment.directives, nil)

    inlineFragment = parse('{...@skip{}}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(inlineFragment.directives, nil)

    inlineFragment = parse('{...on a@skip {}}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(inlineFragment.directives, nil)
end

function g.test_parse_inlineFragment_selectionSet()
    t.assert_error(parse, '{... on a}')

    local inlineFragment = parse('{...{}}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(inlineFragment.selectionSet, nil)

    inlineFragment = parse('{... on a{}}').definitions[1].selectionSet.selections[1]
    t.assert_not_equals(inlineFragment.selectionSet, nil)
end

function g.test_parse_arguments()
    t.assert_error(parse, '{a()}')

    local arguments = parse('{a(b:1)}').definitions[1].selectionSet.selections[1].arguments
    t.assert_equals(#arguments, 1)

    arguments = parse('{a(b:1 c:1)}').definitions[1].selectionSet.selections[1].arguments
    t.assert_equals(#arguments, 2)
end

function g.test_parse_argument()
    t.assert_error(parse, '{a(b)}')
    t.assert_error(parse, '{a(@b)}')
    t.assert_error(parse, '{a($b)}')
    t.assert_error(parse, '{a(b::)}')
    t.assert_error(parse, '{a(:1)}')
    t.assert_error(parse, '{a(b:)}')
    t.assert_error(parse, '{a(:)}')
    t.assert_error(parse, '{a(b c)}')

    local argument = parse('{a(b:1)}').definitions[1].selectionSet.selections[1].arguments[1]
    t.assert_equals(argument.kind, 'argument')
    t.assert_equals(argument.name.value, 'b')
    t.assert_equals(argument.value.value, '1')
end

function g.test_parse_directives()
    t.assert_error(parse, '{a@}')
    t.assert_error(parse, '{a@@}')

    local directives = parse('{a@b}').definitions[1].selectionSet.selections[1].directives
    t.assert_equals(#directives, 1)

    directives = parse('{a@b(c:1)@d}').definitions[1].selectionSet.selections[1].directives
    t.assert_equals(#directives, 2)
end

function g.test_parse_directive()
    t.assert_error(parse, '{a@b()}')

    local directive = parse('{a@b}').definitions[1].selectionSet.selections[1].directives[1]
    t.assert_equals(directive.kind, 'directive')
    t.assert_equals(directive.name.value, 'b')
    t.assert_equals(directive.arguments, nil)

    directive = parse('{a@b(c:1)}').definitions[1].selectionSet.selections[1].directives[1]
    t.assert_not_equals(directive.arguments, nil)
end

function g.test_parse_variableDefinitions()
    t.assert_error(parse, 'query(){}')
    t.assert_error(parse, 'query(a){}')
    t.assert_error(parse, 'query(@a){}')
    t.assert_error(parse, 'query($a){}')

    local variableDefinitions = parse('query($a:Int){}').definitions[1].variableDefinitions
    t.assert_equals(#variableDefinitions, 1)

    variableDefinitions = parse('query($a:Int $b:Int){}').definitions[1].variableDefinitions
    t.assert_equals(#variableDefinitions, 2)
end

function g.test_parse_variableDefinition_variable()
    local variableDefinition = parse('query($a:Int){}').definitions[1].variableDefinitions[1]
    t.assert_equals(variableDefinition.kind, 'variableDefinition')
    t.assert_equals(variableDefinition.variable.name.value, 'a')
end

function g.test_parse_variableDefinition_type()
    t.assert_error(parse, 'query($a){}')
    t.assert_error(parse, 'query($a:){}')
    t.assert_error(parse, 'query($a Int){}')

    local variableDefinition = parse('query($a:Int){}').definitions[1].variableDefinitions[1]
    t.assert_equals(variableDefinition.type.name.value, 'Int')
end

function g.test_parse_variableDefinition_defaultValue()
    t.assert_error(parse, 'query($a:Int=){}')

    local variableDefinition = parse('query($a:Int){}').definitions[1].variableDefinitions[1]
    t.assert_equals(variableDefinition.defaultValue, nil)

    variableDefinition = parse('query($a:Int=1){}').definitions[1].variableDefinitions[1]
    t.assert_not_equals(variableDefinition.defaultValue, nil)
end

local function run(input, result, type)
    local value = parse('{x(y:' .. input .. ')}').definitions[1].selectionSet.selections[1].arguments[1].value
    if type then
        t.assert_equals(value.kind, type)
    end
    if result then
        t.assert_equals(value.value, result)
    end
    return value
end

function g.test_parse_value_variable()
    t.assert_error(parse, '{x(y:$)}')
    t.assert_error(parse, '{x(y:$a$)}')

    local value = run('$a')
    t.assert_equals(value.kind, 'variable')
    t.assert_equals(value.name.value, 'a')
end

function g.test_parse_value_int()
    t.assert_error(parse, '{x(y:01)}')
    t.assert_error(parse, '{x(y:-01)}')
    t.assert_error(parse, '{x(y:--1)}')
    t.assert_error(parse, '{x(y:+0)}')

    run('0', '0', 'int')
    run('-0', '-0', 'int')
    run('1234', '1234', 'int')
    run('-1234', '-1234', 'int')
end

function g.test_parse_value_float()
    t.assert_error(parse, '{x(y:.1)}')
    t.assert_error(parse, '{x(y:1.)}')
    t.assert_error(parse, '{x(y:1..)}')
    t.assert_error(parse, '{x(y:0e1.0)}')

    run('0.0', '0.0', 'float')
    run('-0.0', '-0.0', 'float')
    run('12.34', '12.34', 'float')
    run('1e0', '1e0', 'float')
    run('1e3', '1e3', 'float')
    run('1.0e3', '1.0e3', 'float')
    run('1.0e+3', '1.0e+3', 'float')
    run('1.0e-3', '1.0e-3', 'float')
    run('1.00e-30', '1.00e-30', 'float')
end

function g.test_parse_value_boolean()
    run('true', 'true', 'boolean')
    run('false', 'false', 'boolean')
end

function g.test_parse_value_string()
    t.assert_error(parse, '{x(y:")}')
    t.assert_error(parse, '{x(y:\'\')}')
    t.assert_error(parse, '{x(y:"\n")}')

    run('"yarn"', 'yarn', 'string')
    run('"th\\"read"', 'th"read', 'string')
end

function g.test_parse_value_enum()
    run('a', 'a', 'enum')
end

function g.test_parse_value_list()
    t.assert_error(parse, '{x(y:[)}')

    local value = run('[]')
    t.assert_equals(value.values, {})

    value = run('[a 1]')
    t.assert_equals(value, {
        kind = 'list',
        values = {
            {
                kind = 'enum',
                value = 'a'
            },
            {
                kind = 'int',
                value = '1'
            }
        }
    })

    value = run('[a [b] c]')
    t.assert_equals(value, {
        kind = 'list',
        values = {
            {
                kind = 'enum',
                value = 'a'
            },
            {
                kind = 'list',
                values = {
                    {
                        kind = 'enum',
                        value = 'b'
                    }
                }
            },
            {
                kind = 'enum',
                value = 'c'
            }
        }
    })
end

function g.test_parse_value_object()
    t.assert_error(parse, '{x(y:{a})}')
    t.assert_error(parse, '{x(y:{a:})}')
    t.assert_error(parse, '{x(y:{a::})}')
    t.assert_error(parse, '{x(y:{1:1})}')
    t.assert_error(parse, '{x(y:{"foo":"bar"})}')

    local value = run('{}')
    t.assert_equals(value.kind, 'inputObject')
    t.assert_equals(value.values, {})

    value = run('{a:1}')
    t.assert_equals(value.values, {
        {
            name = 'a',
            value = {
                kind = 'int',
                value = '1'
            }
        }
    })

    value = run('{a:1 b:2}')
    t.assert_equals(#value.values, 2)
end

function g.test_parse_namedType()
    t.assert_error(parse, 'query($a:$b){}')

    local namedType = parse('query($a:b){}').definitions[1].variableDefinitions[1].type
    t.assert_equals(namedType.kind, 'namedType')
    t.assert_equals(namedType.name.value, 'b')
end

function g.test_parse_listType()
    t.assert_error(parse, 'query($a:[]){}')

    local listType = parse('query($a:[b]){}').definitions[1].variableDefinitions[1].type
    t.assert_equals(listType.kind, 'listType')
    t.assert_equals(listType.type.kind, 'namedType')
    t.assert_equals(listType.type.name.value, 'b')

    listType = parse('query($a:[[b]]){}').definitions[1].variableDefinitions[1].type
    t.assert_equals(listType.kind, 'listType')
    t.assert_equals(listType.type.kind, 'listType')
end

function g.test_parse_nonNullType()
    t.assert_error(parse, 'query($a:!){}')
    t.assert_error(parse, 'query($a:b!!){}')

    local nonNullType = parse('query($a:b!){}').definitions[1].variableDefinitions[1].type
    t.assert_equals(nonNullType.kind, 'nonNullType')
    t.assert_equals(nonNullType.type.kind, 'namedType')
    t.assert_equals(nonNullType.type.name.value, 'b')

    nonNullType = parse('query($a:[b]!){}').definitions[1].variableDefinitions[1].type
    t.assert_equals(nonNullType.kind, 'nonNullType')
    t.assert_equals(nonNullType.type.kind, 'listType')
end
