/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { MouseEvent, memo, useCallback, useMemo, useState } from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { Button, HealthStatus, IconEdit, Text, TiledList, TiledListItem, Tooltip } from '@tarantool.io/ui-kit';

import * as models from 'src/models';
import type {
  GetClusterCluster,
  GetClusterClusterSelf,
  ServerListReplicaset,
  ServerListServerClusterIssue,
  ServerListServerStat,
} from 'src/models';

import ClusterIssuesModal from '../../../ClusterIssuesModal';
import ReplicasetRoles from '../../../ReplicasetRoles';
import ReplicasetServerList from '../ReplicasetServerList';

import { styles } from './ReplicasetList.styles';

const { isLike, compact } = models.app.utils;
const { replicasetConfigureModalOpenEvent } = models.cluster.replicasetConfigure;
const { selectors } = models.cluster.serverList;

export interface ReplicasetListProps {
  cluster: GetClusterCluster;
  clusterSelf: GetClusterClusterSelf;
  replicasetList: ServerListReplicaset[];
  issues: ServerListServerClusterIssue[];
  serverStat: ServerListServerStat[];
  failoverParamsMode?: string;
  className?: string;
}

const ReplicasetList = ({
  cluster,
  clusterSelf,
  replicasetList,
  issues,
  serverStat,
  failoverParamsMode,
  className,
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

  const handleEditButtonClick = useCallback((_: MouseEvent<HTMLButtonElement>, pass?: unknown) => {
    if (isLike<ServerListReplicaset>(pass)) {
      replicasetConfigureModalOpenEvent({ uuid: pass.uuid });
    }
  }, []);

  if (!clusterSelf) {
    return null;
  }

  return (
    <>
      <TiledList className={className} outer={false}>
        {replicasetListSorted.map((replicaset) => (
          <TiledListItem key={replicaset.uuid} corners="soft">
            <div className={styles.header} data-cy="meta-test__replicaSetSection">
              <Text className={styles.alias} variant="h3">
                {replicaset.alias}
              </Text>
              <div className={styles.statusGroup}>
                <div className={styles.statusWrap}>
                  {issuesReplicasetUuids.includes(replicaset.uuid) ? (
                    <Button
                      className={cx(styles.statusButton, 'meta-test__haveIssues')}
                      intent="plain"
                      size="s"
                      onClick={handleHealthStatusButtonClick}
                      pass={replicaset.uuid}
                    >
                      <HealthStatus
                        className={cx(styles.status, styles.statusWarning)}
                        message="have issues"
                        status="bad"
                      />
                    </Button>
                  ) : (
                    <HealthStatus className={styles.status} status={replicaset.status} />
                  )}
                </div>
                <Text className={styles.vshard} variant="p" tag="div" upperCase>
                  {(replicaset.vshard_group || replicaset.weight) && (
                    <>
                      <Tooltip className={styles.vshardTooltip} content="Storage group">
                        {replicaset.vshard_group}
                      </Tooltip>
                      <Tooltip className={styles.vshardTooltip} content="Replica set weight">
                        {replicaset.weight}
                      </Tooltip>
                    </>
                  )}
                  {replicaset.all_rw && (
                    <Tooltip
                      className={cx(styles.vshardTooltip, 'meta-test__ReplicasetList_allRw_enabled')}
                      content="All instances in the replicaset writeable"
                    >
                      all rw
                    </Tooltip>
                  )}
                </Text>
              </div>
              <Button
                className={styles.editBtn}
                icon={IconEdit}
                intent="secondary"
                onClick={handleEditButtonClick}
                text="Edit"
                data-cy="meta-test__editBtn"
                pass={replicaset}
              />
            </div>
            <ReplicasetRoles className={styles.roles} roles={replicaset.roles} />
            <div className={styles.divider} />
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
