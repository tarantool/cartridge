// @flow
import React from 'react';
import { css, cx } from 'react-emotion';
import { Formik } from 'formik';

import SelectedServersList from 'src/components/SelectedServersList';
import {
  Button,
  FormField,
  IconInfo,
  LeaderFlagSmall,
  PopupFooter,
  RadioButton,
  Text,
  Tooltip
} from '@tarantool.io/ui-kit';
import ReplicasetRoles from 'src/components/ReplicasetRoles';
import ReplicasetFilterInput from 'src/components/ReplicasetFilterInput';
import type {
  Server,
  Replicaset,
  Role
} from 'src/generated/graphql-typing';

const styles = {
  wrap: css`
    width: calc(100% + 32px);
    margin-left: -16px;
    margin-right: -16px;
  `,
  filter: css`
    width: 305px;
  `,
  splash: css`
    flex-basis: 100%;
    max-width: 100%;
  `,
  wideField: css`
    flex-basis: 100%;
    margin-left: 16px;
    margin-right: 16px;
  `,
  radioWrap: css`
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    padding-bottom: 8px;
    border-bottom: solid 1px lightgray;
    margin-bottom: 8px;

    &:last-child {
      padding-bottom: 0;
      border-bottom: 0;
    }
  `,
  radio: css`
    flex-basis: calc(100% - 24px - 150px);
    max-width: calc(100% - 24px - 150px);
  `,
  replicasetServersCount: css`
    flex-basis: 120px;
    text-align: right;
    display: flex;
    align-items: center;
    justify-content: space-between;
  `,
  roles: css`
    flex-basis: 100%;
    margin-top: 8px;
  `,
  replicasetServersTooltip: css`
    padding: 0;
    margin: 8px 0;
    list-style: none;
  `,
  tooltipListItem: css`
    color: #ffffff;
    margin-bottom: 8px;

    &:last-child {
      margin-bottom: 0;
    }
  `,
  tooltipLeaderFlag: css`
    margin-left: 28px;
  `
}

const validateForm = ({
  replicasetUuid
}) => {
  const errors = {};

  if (!replicasetUuid) {
    errors.replicasetUuid = 'Replicaset is required';
  }

  return errors;
};

type JoinReplicasetFormData = {
  uri: string,
  replicasetUuid: string,
};

type JoinReplicasetFormProps = {
  filter: string,
  filteredReplicasetList?: Replicaset[],
  selfURI?: string,
  onCancel: () => void,
  onSubmit: (d: JoinReplicasetFormData) => void,
  replicasetList?: Replicaset[],
  knownRoles?: Role[],
  setFilter: (s: string) => void,
  selectedServers?: Server[]
};

class JoinReplicasetForm extends React.Component<JoinReplicasetFormProps> {
  componentWillUnmount () {
    this.props.setFilter('');
  };

  renderServersTooltipContent = (servers?: Server[], masterUuid: string) => (
    <ul className={styles.replicasetServersTooltip}>
      {(servers || []).map(({ alias, uuid }) => (
        <Text className={styles.tooltipListItem} variant='p' tag='li'>
          {alias}
          {masterUuid === uuid && (
            <LeaderFlagSmall className={styles.tooltipLeaderFlag} />
          )}
        </Text>
      ))}
    </ul>
  );

  render() {
    const {
      filter,
      filteredReplicasetList,
      selfURI,
      onCancel,
      onSubmit,
      replicasetList,
      selectedServers,
      knownRoles
    } = this.props;

    return (
      <Formik
        initialValues={{
          replicasetUuid: ''
        }}
        validate={validateForm}
        onSubmit={(values, { setSubmitting }) => {
          onSubmit({
            ...values,
            uri: (selectedServers && selectedServers[0].uri) || ''
          });
        }}
      >
        {({
          values,
          errors,
          touched,
          handleChange,
          handleBlur,
          handleSubmit,
          isSubmitting
        }) => {
          return (
            <form onSubmit={handleSubmit}>
              <SelectedServersList className={styles.splash} serverList={selectedServers} selfURI={selfURI} />
              <div className={styles.wrap}>
                <FormField
                  className={styles.wideField}
                  itemClassName={styles.radioWrap}
                  label='Choose replica set'
                  subTitle={(
                    <Text variant='p' tag='span'>
                      <b>{(replicasetList && replicasetList.length) || 0}</b> total
                      {
                        filteredReplicasetList
                        &&
                        replicasetList
                        &&
                        filteredReplicasetList.length !== replicasetList.length
                        &&
                        (
                          <>, <b>{filteredReplicasetList.length}</b> filtered</>
                        )
                      }
                    </Text>
                  )}
                  topRightControls={[
                    <ReplicasetFilterInput
                      className={cx(styles.filter, 'meta-test__Filter')}
                      value={filter}
                      setValue={this.props.setFilter}
                      roles={knownRoles}
                    />
                  ]}
                  largeMargins
                >
                  {filteredReplicasetList && filteredReplicasetList.map(({
                    alias,
                    servers,
                    uuid,
                    roles,
                    master
                  }) => (
                    <React.Fragment>
                      <RadioButton
                        onChange={handleChange}
                        className={styles.radio}
                        name='replicasetUuid'
                        value={uuid}
                        key={uuid}
                        checked={uuid === values.replicasetUuid}
                      >
                        {alias || uuid}
                      </RadioButton>
                      <Tooltip
                        className={styles.replicasetServersCount}
                        content={this.renderServersTooltipContent(servers, master.uuid)}
                      >
                        <IconInfo />
                        <Text variant='basic' tag='span'>
                          <b>{servers.length}</b>
                          {` total server${servers.length > 1 ? 's' : ''}`}
                        </Text>
                      </Tooltip>
                      <ReplicasetRoles className={styles.roles} roles={roles || []} />
                    </React.Fragment>
                  ))}
                </FormField>
              </div>
              <PopupFooter
                className={styles.splash}
                controls={([
                  <Button type='button' onClick={onCancel} size='l'>Cancel</Button>,
                  <Button
                    className='meta-test__JoinReplicaSetBtn'
                    disabled={Object.keys(errors).length > 0 || !values.replicasetUuid}
                    intent='primary'
                    type='submit'
                    text='Join replica set'
                    size='l'
                  />
                ])}
              />
            </form>
          )
        }}
      </Formik>
    );
  }
}

export default JoinReplicasetForm;
