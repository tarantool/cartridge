import React, { useCallback, useMemo } from 'react';
import { cx } from '@emotion/css';
import { useStore } from 'effector-react';
/* eslint-disable @typescript-eslint/ban-ts-comment */
import { FormikProps, withFormik } from 'formik';
// @ts-ignore
// prettier-ignore
import { Alert, Button, Checkbox, FormField, LabeledInput, Modal, Select, Spin, Tabbed, Text, TextArea } from '@tarantool.io/ui-kit';

import { FAILOVER_STATE_PROVIDERS } from 'src/constants';
import { app, cluster } from 'src/models';
import type { Failover, NumberSchema, ObjectSchema, StringSchema } from 'src/models';

import {
  FailoverMode,
  FailoverStateProvider,
  toFailoverMode,
  toFailoverStateProvider,
} from './FailoverModalForm.types';

import { styles } from './FailoverModalForm.styles';

export interface FailoverFormProps {
  mode: string | undefined;
  failover: Failover;
}

const { $failoverModal, failoverModalCloseEvent } = cluster.failover;

const FAILOVER_MODES_INFO: Record<FailoverMode, string> = {
  disabled: 'The leader is the first instance according to topology configuration. No automatic decisions are taken.',
  eventual:
    'The leader isn’t elected consistently. Every instance thinks the leader is the first healthy server in the replicaset. The instance health is determined according to the membership status (the SWIM protocol).',
  stateful:
    'Leader appointments are polled from the external state provider. Decisions are taken by one of the instances with the failover-coordinator role enabled.',
  raft: 'The replicaset leader is chosen by built-in Raft, then the other replicasets get information about leader change from membership.',
};

const INFOS = {
  failoverTimeout: 'Timeout in seconds to mark suspect members as dead and trigger failover',
  fencingEnabled: 'A leader will go read-only when both the state provider and one of replicas are unreachable',
  fencingTimeout: 'Time in seconds to actuate the fencing after the health check fails',
  fencingPause: 'The period in seconds of performing the health check',
  lockDelayInfo: 'Expiration time of a lock that the failover-coordinator role acquires',
};

const FAILOVER_TABS: [FailoverMode, FailoverMode, FailoverMode, FailoverMode] = [
  'disabled',
  'eventual',
  'stateful',
  'raft',
];

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
const { tryCatchWithNotify, messages, yup } = app;

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
    mode: yup.string().oneOf(['disabled', 'eventual', 'stateful', 'raft']).required(app.messages.errors.REQUIRED),
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

const FailoverModalFormForm = ({
  handleSubmit,
  handleReset,
  setFieldValue,
  handleChange,
  values,
  errors,
}: FailoverFormFormikProps) => {
  const { loading, pending, error } = useStore($failoverModal);

  const handleTabChange = useCallback(
    (index: number) => setFieldValue('mode', toFailoverMode(FAILOVER_TABS[index])),
    [setFieldValue]
  );

  const handleClose = useCallback(() => failoverModalCloseEvent(), []);

  const handleStateProviderChange = useCallback(
    (state_provider: string) =>
      setFieldValue('state_provider', toFailoverStateProvider(state_provider) ? state_provider : 'tarantool'),
    [setFieldValue]
  );

  const footerControls = useMemo(
    () => [
      <Button key="Cancel" className="meta-test__CancelButton" onClick={handleClose} size="l">
        Cancel
      </Button>,
      <Button
        key="Apply"
        className="meta-test__SubmitButton"
        intent="primary"
        type="submit"
        size="l"
        disabled={loading}
        loading={pending}
      >
        Apply
      </Button>,
    ],
    [handleClose, loading, pending]
  );

  const tabs = useMemo(
    () => [
      {
        label: 'Disabled',
        content: (
          <Text variant="p" className={styles.failoverInfo}>
            {FAILOVER_MODES_INFO['disabled']}
          </Text>
        ),
      },
      {
        label: 'Eventual',
        content: (
          <Text variant="p" className={styles.failoverInfo}>
            {FAILOVER_MODES_INFO['eventual']}
          </Text>
        ),
      },
      {
        label: 'Stateful',
        content: (
          <Text variant="p" className={styles.failoverInfo}>
            {FAILOVER_MODES_INFO['stateful']}
          </Text>
        ),
      },
      {
        label: 'Raft',
        content: (
          <Text variant="p" className={styles.failoverInfo}>
            {FAILOVER_MODES_INFO['raft']}
          </Text>
        ),
      },
    ],
    []
  );

  return (
    <Spin enable={loading}>
      <FormField label="Failover mode">
        <Tabbed
          size="small"
          className="meta-test__failover-tabs"
          activeTab={FAILOVER_TABS.findIndex((tab) => tab === values.mode)}
          handleTabChange={handleTabChange}
          tabs={tabs}
        />
      </FormField>
      <form onSubmit={handleSubmit} onReset={handleReset} noValidate>
        <LabeledInput
          name="failover_timeout"
          label="Failover timeout"
          className="meta-test__failoverTimeout"
          error={Boolean(errors.failover_timeout)}
          message={errors.failover_timeout}
          value={`${values.failover_timeout ?? ''}`}
          onChange={handleChange}
          info={INFOS.failoverTimeout}
        />
        {values.mode === 'stateful' && (
          <>
            <FormField label="Fencing" info={INFOS.fencingEnabled}>
              <Checkbox
                name="fencing_enabled"
                className="meta-test__fencingEnableCheckbox"
                checked={values.fencing_enabled}
                onChange={handleChange}
              >
                Enabled
              </Checkbox>
            </FormField>
            <div className={styles.inputs}>
              <LabeledInput
                name="fencing_timeout"
                label="Fencing timeout"
                className={cx(styles.inputField, 'meta-test__fencingTimeout')}
                disabled={!values.fencing_enabled}
                error={Boolean(errors.fencing_timeout)}
                message={errors.fencing_timeout}
                info={INFOS.fencingTimeout}
                value={`${values.fencing_timeout ?? ''}`}
                onChange={handleChange}
              />
              <LabeledInput
                name="fencing_pause"
                label="Fencing pause"
                className={cx(styles.inputField, 'meta-test__fencingPause')}
                disabled={!values.fencing_enabled}
                error={Boolean(errors.fencing_pause)}
                message={errors.fencing_pause}
                info={INFOS.fencingPause}
                value={`${values.fencing_pause ?? ''}`}
                onChange={handleChange}
              />
            </div>
            <LabeledInput
              name="state_provider"
              label="State provider"
              className="meta-test__stateProviderChoice"
              inputClassName={styles.select}
              inputComponent={Select}
              dropdownClassName="meta-test__StateProvider__Dropdown"
              options={FAILOVER_STATE_PROVIDERS}
              value={values.state_provider}
              //@ts-ignore
              onChange={handleStateProviderChange}
            />
            {values.state_provider === 'tarantool' && (
              <div className={styles.inputs}>
                <LabeledInput
                  name="tarantool_params.uri"
                  className={styles.inputField}
                  label="URI"
                  inputClassName="meta-test__stateboardURI"
                  error={Boolean(errors.tarantool_params?.uri)}
                  message={errors.tarantool_params?.uri}
                  value={values.tarantool_params.uri}
                  onChange={handleChange}
                />
                <LabeledInput
                  name="tarantool_params.password"
                  className={styles.inputField}
                  label="Password"
                  inputClassName="meta-test__stateboardPassword"
                  error={Boolean(errors.tarantool_params?.password)}
                  message={errors.tarantool_params?.password}
                  value={values.tarantool_params.password}
                  type="password"
                  onChange={handleChange}
                />
              </div>
            )}
            {values.state_provider === 'etcd2' && (
              <>
                <LabeledInput
                  name="etcd2_params.endpoints"
                  label="Endpoints"
                  className="meta-test__etcd2Endpoints"
                  inputComponent={TextArea}
                  error={Boolean(errors.etcd2_params?.endpoints)}
                  message={errors.etcd2_params?.endpoints}
                  value={values.etcd2_params.endpoints}
                  //@ts-ignore
                  rows={2}
                  onChange={handleChange}
                />
                <div className={styles.inputs}>
                  <LabeledInput
                    name="etcd2_params.lock_delay"
                    className={styles.inputField}
                    label="Lock delay"
                    info={INFOS.lockDelayInfo}
                    error={Boolean(errors.etcd2_params?.lock_delay)}
                    message={errors.etcd2_params?.lock_delay}
                    inputClassName="meta-test__etcd2LockDelay"
                    value={`${values.etcd2_params.lock_delay ?? ''}`}
                    onChange={handleChange}
                  />
                  <LabeledInput
                    name="etcd2_params.prefix"
                    className={styles.inputField}
                    label="Prefix"
                    inputClassName="meta-test__etcd2Prefix"
                    error={Boolean(errors.etcd2_params?.prefix)}
                    message={errors.etcd2_params?.prefix}
                    value={values.etcd2_params.prefix}
                    onChange={handleChange}
                  />
                  <LabeledInput
                    name="etcd2_params.username"
                    className={styles.inputField}
                    label="Username"
                    inputClassName="meta-test__etcd2Username"
                    error={Boolean(errors.etcd2_params?.username)}
                    message={errors.etcd2_params?.username}
                    value={values.etcd2_params.username}
                    onChange={handleChange}
                  />
                  <LabeledInput
                    name="etcd2_params.password"
                    className={styles.inputField}
                    label="Password"
                    inputClassName="meta-test__etcd2Password"
                    error={Boolean(errors.etcd2_params?.password)}
                    message={errors.etcd2_params?.password}
                    value={values.etcd2_params.password}
                    type="password"
                    onChange={handleChange}
                  />
                </div>
              </>
            )}
          </>
        )}
        {error && (
          <Alert type="error" className="meta-test__inlineError">
            <Text variant="basic">{error}</Text>
          </Alert>
        )}
        <Modal.Footer controls={footerControls} />
      </form>
    </Spin>
  );
};

export default withFailoverForm(FailoverModalFormForm);
