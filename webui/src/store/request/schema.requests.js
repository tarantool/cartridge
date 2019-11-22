// @flow
import graphql from 'src/api/graphql';
import {
  getSchemaQuery,
  setSchemaMutation,
  checkSchemaMutation
} from './queries.graphql';

export function getSchema() {
  return graphql.fetch(getSchemaQuery).then(({ cluster: { schema: { as_yaml } } }) => as_yaml);
}

export function applySchema(yaml: string) {
  return graphql.mutate(setSchemaMutation, { yaml });
}

export function checkSchema(yaml: string) {
  return graphql.mutate(checkSchemaMutation, { yaml });
}
