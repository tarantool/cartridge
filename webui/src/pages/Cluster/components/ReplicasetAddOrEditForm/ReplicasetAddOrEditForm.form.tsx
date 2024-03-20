import { FormikProps, withFormik } from 'formik';

import { GetClusterRole, KnownRolesNamesResult, Maybe, ServerListReplicaset, ServerListServer, app } from 'src/models';

export interface ReplicasetAddOrEditValues {
  alias: string | null;
  all_rw: boolean;
  rebalancer: boolean | null;
  roles: string[];
  vshard_group: string | null;
  failover_priority: string[];
  weight: number | null;
}

export interface ReplicasetAddOrEditFormProps {
  onSubmit: (values: ReplicasetAddOrEditValues) => void;
  onClose: () => void;
  pending: boolean;
  replicaset?: Maybe<ServerListReplicaset>;
  knownRoles: GetClusterRole[];
  knownRolesNames: KnownRolesNamesResult;
  vshardGroupsNames: string[];
  clusterSelfUri?: string;
  failoverParamsMode?: string;
  server?: ServerListServer;
}

const { tryCatchWithNotify, yup } = app;

const validationSchemaCreator = ({ knownRolesNames }: Pick<ReplicasetAddOrEditFormProps, 'knownRolesNames'>) =>
  yup
    .object<ReplicasetAddOrEditValues>({
      alias: yup
        .string()
        .nullable()
        .max(63, 'Alias must not exceed 63 character')
        .test('allowed', 'Allowed symbols are: a-z, A-Z, 0-9, _ . -', (value: string) => {
          if (!value || value.length === 0) {
            return true;
          }

          return /^[a-zA-Z0-9-_.]+$/.test(value);
        }),
      all_rw: yup.boolean(),
      rebalancer: yup.boolean().nullable(),
      roles: yup.array(yup.string()),
      vshard_group: yup
        .string()
        .nullable()
        .test('required', 'Group is required for some roles', function (value) {
          if (!value && (this.parent.roles || []).some((role: string) => knownRolesNames.storage.includes(role))) {
            return this.createError({
              path: 'vshard_group',
              message: `Group is required for ${knownRolesNames.storage.join(' or ')} role`,
            });
          }

          return true;
        }),
      failover_priority: yup.array(yup.string()),
      weight: yup.number().typeError(app.messages.errors.NUMBER_FLOAT).nullable().default(null),
    })
    .required();

export type WithReplicasetAddOrEditFormWithFormikProps = FormikProps<ReplicasetAddOrEditValues> &
  ReplicasetAddOrEditFormProps;

export const withReplicasetAddOrEditForm = withFormik<ReplicasetAddOrEditFormProps, ReplicasetAddOrEditValues>({
  displayName: 'ReplicasetAddOrEditForm',
  validationSchema: validationSchemaCreator,
  mapPropsToValues: ({ replicaset }) => ({
    alias: replicaset?.alias ?? null,
    all_rw: replicaset?.all_rw ?? false,
    rebalancer: replicaset?.rebalancer ?? null,
    roles: replicaset?.roles ?? [],
    vshard_group: replicaset?.vshard_group ?? null,
    failover_priority: replicaset?.servers.map(({ uuid }) => uuid) ?? [],
    weight: replicaset?.weight ?? null,
  }),
  handleSubmit: (values, { props: { onSubmit, knownRolesNames } }) => {
    tryCatchWithNotify(() => {
      const casted = validationSchemaCreator({ knownRolesNames }).cast(values, {
        abortEarly: true,
        stripUnknown: true,
      });

      onSubmit(casted);
    });
  },
});
