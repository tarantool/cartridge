/* eslint-disable @typescript-eslint/ban-ts-comment */
import { FormikProps, withFormik } from 'formik';
import * as yup from 'yup';
import type { NumberSchema, ObjectSchema, StringSchema } from 'yup';

import { Failover, app, cluster } from 'src/models';

import {
  FailoverMode,
  FailoverStateProvider,
  toFailoverMode,
  toFailoverStateProvider,
} from './FailoverModalForm.types';

export interface FailoverFormProps {
  mode: string | undefined;
  failover: Failover;
}

export interface FailoverFormValues {
  mode: FailoverMode;
  failover_timeout?: number;
  //
  fencing_enabled: boolean;
  fencing_timeout?: number;
  fencing_pause?: number;
  state_provider?: FailoverStateProvider;
  tarantool_params: {
    uri: string;
    password: string;
  };
  etcd2_params: {
    prefix?: string;
    username?: string;
    password?: string;
    endpoints?: string;
    lock_delay?: number;
  };
}

const { changeFailoverEvent } = cluster.failover;
const { tryCatchWithNotify, messages } = app;

const reqString = (mode: FailoverMode, fencing_enabled: boolean, schema: StringSchema) => {
  return mode === 'stateful' && fencing_enabled ? schema.required(messages.errors.NUMBER_FLOAT) : schema.notRequired();
};

const reqNumber = (mode: FailoverMode, fencing_enabled: boolean, schema: NumberSchema) => {
  return mode === 'stateful' && fencing_enabled
    ? schema.typeError(messages.errors.NUMBER_FLOAT).required(messages.errors.NUMBER_FLOAT)
    : schema.notRequired();
};

const validationSchema = yup
  .object<FailoverFormValues>({
    mode: yup.string().oneOf(['disabled', 'eventual', 'stateful']).required(app.messages.errors.REQUIRED),
    failover_timeout: yup
      .number()
      .typeError(app.messages.errors.NUMBER_FLOAT)
      .required(app.messages.errors.NUMBER_FLOAT),
    fencing_enabled: yup.boolean(),
    fencing_timeout: yup.number().when(['mode', 'fencing_enabled'], reqNumber),
    fencing_pause: yup.number().when(['mode', 'fencing_enabled'], reqNumber),
    state_provider: yup.string().oneOf(['tarantool', 'etcd2']).when(['mode', 'fencing_enabled'], reqString),
    tarantool_params: yup
      .object({
        uri: yup.string(),
        password: yup.string(),
      })
      .when(
        ['mode', 'fencing_enabled', 'state_provider'],
        (mode: FailoverMode, fencing_enabled: boolean, state_provider: FailoverStateProvider, schema: ObjectSchema) =>
          mode === 'stateful' && fencing_enabled && state_provider === 'tarantool'
            ? schema.required()
            : schema.notRequired()
      ),
    etcd2_params: yup
      .object({
        prefix: yup.string(),
        username: yup.string(),
        password: yup.string(),
        endpoints: yup.string(),
        lock_delay: yup.number().typeError(app.messages.errors.NUMBER_FLOAT).required(app.messages.errors.NUMBER_FLOAT),
      })
      .when(
        ['mode', 'fencing_enabled', 'state_provider'],
        (mode: FailoverMode, fencing_enabled: boolean, state_provider: FailoverStateProvider, schema: ObjectSchema) =>
          mode === 'stateful' && fencing_enabled && state_provider === 'etcd2'
            ? schema.required()
            : schema.notRequired()
      ),
  })
  .required();

export type FailoverFormFormikProps = FormikProps<FailoverFormValues>;

export const withFailoverForm = withFormik<FailoverFormProps, FailoverFormValues>({
  displayName: 'FailoverForm',
  enableReinitialize: true,
  mapPropsToValues: ({ mode, failover }) => {
    const failover_params = failover?.cluster?.failover_params;
    const tarantool_params = failover_params?.tarantool_params;
    const etcd2_params = failover_params?.etcd2_params;

    return {
      mode: toFailoverMode(failover_params?.mode ?? mode),
      failover_timeout: failover_params?.failover_timeout,
      fencing_enabled: failover_params?.fencing_enabled ?? false,
      fencing_timeout: failover_params?.fencing_timeout,
      fencing_pause: failover_params?.fencing_pause,
      state_provider: toFailoverStateProvider(failover_params?.state_provider),
      tarantool_params: {
        uri: tarantool_params?.uri ?? '',
        password: tarantool_params?.password ?? '',
      },
      etcd2_params: {
        prefix: etcd2_params?.prefix,
        username: etcd2_params?.username,
        password: etcd2_params?.password,
        endpoints: etcd2_params?.endpoints.join('\n'),
        lock_delay: etcd2_params?.lock_delay,
      },
    };
  },
  validationSchema,
  handleSubmit: (values) => {
    tryCatchWithNotify(() => {
      const casted = validationSchema.cast(values, {
        abortEarly: true,
        stripUnknown: true,
      });

      const state_provider = casted.mode === 'stateful' ? casted.state_provider : null;
      const result = {
        ...casted,
        state_provider,
        tarantool_params: state_provider === 'tarantool' ? casted.tarantool_params : null,
        etcd2_params:
          state_provider === 'etcd2'
            ? {
                ...casted.etcd2_params,
                endpoints: casted.etcd2_params?.endpoints?.split('\n'),
              }
            : null,
      };

      changeFailoverEvent(result);
    });
  },
});
