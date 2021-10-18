import { FormikProps, withFormik } from 'formik';
import * as yup from 'yup';

import { GetClusterRole, KnownRolesNamesResult, Maybe, ServerListReplicaset, ServerListServer, app } from 'src/models';

export interface ReplicasetAddOrEditValues {
  alias: string;
  all_rw: boolean;
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

const { tryCatchWithNotify } = app;

const validationSchema = yup
  .object<ReplicasetAddOrEditValues>({
    alias: yup.string().required(app.messages.errors.REQUIRED),
    all_rw: yup.boolean(),
    roles: yup.array(yup.string()),
    vshard_group: yup.string().nullable(),
    failover_priority: yup.array(yup.string()),
    weight: yup.number().typeError(app.messages.errors.NUMBER_FLOAT).nullable().default(null),
  })
  .required();

export type WithReplicasetAddOrEditFormWithFormikProps = FormikProps<ReplicasetAddOrEditValues> &
  ReplicasetAddOrEditFormProps;

export const withReplicasetAddOrEditForm = withFormik<ReplicasetAddOrEditFormProps, ReplicasetAddOrEditValues>({
  displayName: 'ReplicasetAddOrEditForm',
  validationSchema,
  mapPropsToValues: ({ replicaset }) => ({
    alias: replicaset?.alias ?? '',
    all_rw: replicaset?.all_rw ?? false,
    roles: replicaset?.roles ?? [],
    vshard_group: replicaset?.vshard_group ?? '',
    failover_priority: replicaset?.servers.map(({ uuid }) => uuid) ?? [],
    weight: replicaset?.weight ?? null,
  }),
  handleSubmit: (values, { props: { onSubmit, replicaset, knownRolesNames, vshardGroupsNames } }) => {
    if (!replicaset) {
      return;
    }

    tryCatchWithNotify(() => {
      const storageRoleChecked = values.roles.some((role) => knownRolesNames.storage.includes(role));
      if (!storageRoleChecked && typeof replicaset.weight === 'number') {
        values.weight = replicaset.weight;
      }

      if (values.vshard_group && vshardGroupsNames.length === 1) {
        if (storageRoleChecked && !values.vshard_group) {
          values.vshard_group = vshardGroupsNames[0] ?? null;
        }

        if (!storageRoleChecked && !replicaset?.vshard_group && values.vshard_group) {
          values.vshard_group = null;
        }
      }

      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      //@ts-ignore
      if (values.weight === '') {
        // TODO: formik types issue
        values.weight = null;
      }

      const casted = validationSchema.cast(values, {
        abortEarly: true,
        stripUnknown: true,
      });

      onSubmit(casted);
    });
  },
});
