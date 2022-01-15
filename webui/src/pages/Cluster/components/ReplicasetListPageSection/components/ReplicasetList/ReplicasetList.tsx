/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { MouseEvent, memo, useCallback, useMemo, useState } from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { Button, IconEdit, Text, TiledList, TiledListItem, withTooltip } from '@tarantool.io/ui-kit';

import * as models from 'src/models';
import type {
  GetClusterCluster,
  GetClusterClusterSelf,
  ServerListClusterIssue,
  ServerListReplicaset,
  ServerListServerStat,
} from 'src/models';

import ClusterIssuesModal from '../../../ClusterIssuesModal';
import ReplicasetRoles from '../../../ReplicasetRoles';
import ReplicasetListStatus from '../ReplicasetListStatus';
import ReplicasetListTag from '../ReplicasetListTag';
import ReplicasetServerList from '../ReplicasetServerList';

import { styles } from './ReplicasetList.styles';

const { compact } = models.app.utils;
const { replicasetConfigureModalOpenEvent } = models.cluster.replicasetConfigure;
const { selectors } = models.cluster.serverList;

const ButtonWithTooltip = withTooltip(Button);

export interface ReplicasetListProps {
  cluster: GetClusterCluster;
  clusterSelf: GetClusterClusterSelf;
  replicasetList: ServerListReplicaset[];
  issues: ServerListClusterIssue[];
  serverStat: ServerListServerStat[];
  failoverParamsMode?: string;
}

const ReplicasetList = ({
  cluster,
  clusterSelf,
  replicasetList,
  issues,
  serverStat,
  failoverParamsMode,
}: ReplicasetListProps) => {
  const [issuedReplicasetUuid, setIssuedReplicasetUuid] = useState('');

  const replicasetListSorted = useMemo(() => selectors.sortReplicasetList(replicasetList), [replicasetList]);

  const issuesReplicasetUuids = useMemo(() => compact(issues.map(({ replicaset_uuid }) => replicaset_uuid)), [issues]);

  const issuesSelected = useMemo(
    () => issues.filter(({ replicaset_uuid }) => replicaset_uuid === issuedReplicasetUuid),
    [issues, issuedReplicasetUuid]
  );

  const handleClusterIssuesModalClick = useCallback(() => {
    setIssuedReplicasetUuid('');
  }, []);

  const handleHealthStatusButtonClick = useCallback((_: MouseEvent<HTMLButtonElement>, pass?: unknown) => {
    if (typeof pass === 'string') {
      setIssuedReplicasetUuid(pass);
    }
  }, []);

  const handleEditButtonClick = useCallback((_: MouseEvent<HTMLButtonElement>, pass?: ServerListReplicaset) => {
    if (pass) {
      replicasetConfigureModalOpenEvent({ uuid: pass.uuid });
    }
  }, []);

  if (!clusterSelf) {
    return null;
  }

  return (
    <>
      <TiledList className={styles.root} outer={false}>
        {replicasetListSorted.map((replicaset) => (
          <TiledListItem key={replicaset.uuid} corners="soft" className={styles.row}>
            <div className={styles.replicaset}>
              <div className={styles.header} data-cy="meta-test__replicaSetSection">
                <Text className={styles.alias} variant="h3">
                  {replicaset.alias}
                </Text>
                <div className={cx(styles.div, styles.grow)} />
                <div className={styles.status}>
                  {issuesReplicasetUuids.includes(replicaset.uuid) ? (
                    <Button
                      className={cx(styles.statusButton, 'meta-test__haveIssues')}
                      intent="base"
                      size="s"
                      onClick={handleHealthStatusButtonClick}
                      pass={replicaset.uuid}
                    >
                      <ReplicasetListStatus status="bad" statusMessage="have issues" />
                    </Button>
                  ) : (
                    <ReplicasetListStatus status={replicaset.status} />
                  )}
                </div>
                <div className={styles.div} />
                <div className={styles.tags}>
                  {replicaset.vshard_group && (
                    <ReplicasetListTag title="Storage group">{replicaset.vshard_group}</ReplicasetListTag>
                  )}
                  {typeof replicaset.weight === 'number' && (
                    <ReplicasetListTag title="Replica set weight">{replicaset.weight}</ReplicasetListTag>
                  )}
                  {replicaset.all_rw && (
                    <ReplicasetListTag
                      className="meta-test__ReplicasetList_allRw_enabled"
                      title="All instances in the replicaset writeable"
                    >
                      all rw
                    </ReplicasetListTag>
                  )}
                </div>
                <div className={styles.div} />
                <ButtonWithTooltip
                  className={styles.editBtn}
                  icon={IconEdit}
                  intent="secondary"
                  onClick={handleEditButtonClick}
                  data-cy="meta-test__editBtn"
                  pass={replicaset}
                  tooltipContent="Edit replica set"
                />
              </div>
              <ReplicasetRoles className={styles.roles} roles={replicaset.roles} />
            </div>
            <ReplicasetServerList
              cluster={cluster}
              clusterSelf={clusterSelf}
              replicaset={replicaset}
              serverStat={serverStat}
              failoverParamsMode={failoverParamsMode}
            />
          </TiledListItem>
        ))}
      </TiledList>
      <ClusterIssuesModal
        visible={Boolean(issuedReplicasetUuid)}
        issues={issuesSelected}
        onClose={handleClusterIssuesModalClick}
      />
    </>
  );
};

export default memo(ReplicasetList);
