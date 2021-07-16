// @flow

type __Description = string | null

declare type __TypeKind = 'SCALAR'
  | 'OBJECT'
  | 'INTERFACE'
  | 'UNION'
  | 'ENUM'
  | 'INPUT_OBJECT'
  | 'LIST'
  | 'NON_NULL'

declare type __Type = {
  kind: __TypeKind,
  name: string,
  description: __Description,
  fields: Array<__Field>,
  interfaces?: Array<__Type>,
  possibleTypes?: Array<__Type>,
  inputFields?: Array<__InputValue>,
  ofType?: __Type
}


declare type __InputValue = {
  name: string,
  description: __Description,
  type: __Type,
  defaultValue: any,
}

declare type __Field = {
  name: string,
  description: __Description,
  args: Array<__InputValue>,
  type: __Type,
  isDeprecated: boolean,
  deprecationReason?: string
}
