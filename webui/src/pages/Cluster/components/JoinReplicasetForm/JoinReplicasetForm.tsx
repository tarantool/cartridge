/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo, useState } from 'react';
import { cx } from '@emotion/css';
import { useStore } from 'effector-react';
// @ts-ignore
import { Button, FormField, IconInfo, LeaderFlagSmall, Modal, RadioButton, Text, Tooltip } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import ReplicasetFilterInput from '../ReplicasetFilterInput';
import ReplicasetRoles from '../ReplicasetRoles';
import { JoinReplicasetFormikProps, withJoinReplicasetForm } from './JoinReplicasetForm.form';

import { styles } from './JoinReplicasetForm.styles';

const { $serverList, $cluster, selectors, filters } = cluster.serverList;

const JoinReplicasetForm = ({
  values,
  onClose,
  handleChange,
  handleSubmit,
  handleReset,
  isValid,
  pending,
}: JoinReplicasetFormikProps) => {
  const clusterStore = useStore($cluster);
  const serverListStore = useStore($serverList);

  const [filter, setFilter] = useState('');

  const knownRoles = useMemo(() => selectors.knownRoles(clusterStore), [clusterStore]);

  const replicasetList = useMemo(() => selectors.replicasetList(serverListStore), [serverListStore]);
  const replicasetListSearchable = useMemo(() => selectors.replicasetListSearchable(replicasetList), [replicasetList]);

  const filteredSearchableReplicasetList = useMemo(
    () => filters.filterSearchableReplicasetList(replicasetListSearchable, filter),
    [replicasetListSearchable, filter]
  );

  return (
    <form onSubmit={handleSubmit} onReset={handleReset} noValidate>
      <div className={styles.wrap}>
        <FormField
          className={styles.wideField}
          itemClassName={styles.radioWrap}
          label="Choose replica set"
          subTitle={
            <Text variant="p" tag="span">
              <b>{(replicasetList && replicasetList.length) || 0}</b> total
              {filteredSearchableReplicasetList &&
                replicasetList &&
                filteredSearchableReplicasetList.length !== replicasetList.length && (
                  <>
                    , <b>{filteredSearchableReplicasetList.length}</b> filtered
                  </>
                )}
            </Text>
          }
          topRightControls={[
            <ReplicasetFilterInput
              key={0}
              className={cx(styles.filter, 'meta-test__Filter')}
              value={filter}
              setValue={setFilter}
              roles={knownRoles}
            />,
          ]}
          largeMargins
        >
          {filteredSearchableReplicasetList.length > 0 &&
            filteredSearchableReplicasetList.map(({ alias, servers, uuid, roles, master }) => (
              <React.Fragment key={uuid}>
                <RadioButton
                  onChange={handleChange}
                  className={styles.radio}
                  name="replicasetUuid"
                  value={uuid}
                  checked={uuid === values.replicasetUuid}
                >
                  {alias || uuid}
                </RadioButton>
                <Tooltip
                  className={styles.replicasetServersCount}
                  content={
                    <ul className={styles.replicasetServersTooltip}>
                      {(servers || []).map(({ alias, uuid }) => (
                        <Text key={`${uuid}~${alias ?? ''}`} className={styles.tooltipListItem} variant="p" tag="li">
                          {alias}
                          {master.uuid === uuid && <LeaderFlagSmall className={styles.tooltipLeaderFlag} />}
                        </Text>
                      ))}
                    </ul>
                  }
                >
                  <IconInfo />
                  <Text variant="basic" tag="span">
                    <b>{servers.length}</b>
                    {` total server${servers.length > 1 ? 's' : ''}`}
                  </Text>
                </Tooltip>
                <ReplicasetRoles className={styles.roles} roles={roles || []} />
              </React.Fragment>
            ))}
        </FormField>
      </div>
      <Modal.Footer
        className={styles.splash}
        controls={[
          <Button key="Cancel" type="button" onClick={onClose} size="l">
            Cancel
          </Button>,
          <Button
            key="Join"
            className="meta-test__JoinReplicaSetBtn"
            intent="primary"
            type="submit"
            text="Join replica set"
            size="l"
            loading={pending}
            disabled={!isValid}
          />,
        ]}
      />
    </form>
  );
};

export default withJoinReplicasetForm(JoinReplicasetForm);
