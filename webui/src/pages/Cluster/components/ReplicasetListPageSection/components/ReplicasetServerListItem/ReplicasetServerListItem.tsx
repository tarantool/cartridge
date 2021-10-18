/* eslint-disable import/no-duplicates */
/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { cx } from '@emotion/css';
import isEqual from 'lodash/isEqual';
// @ts-ignore
import { FlatListItem, HealthStatus, IconBucket, LeaderFlag, ProgressBar, Tooltip } from '@tarantool.io/ui-kit';
// @ts-ignore
import { Text, UriLabel } from '@tarantool.io/ui-kit';

import { app, cluster } from 'src/models';
import type { Maybe } from 'src/models';

import ServerDropdown from '../../../ServerDropdown';
import MemoryIcon from '../MemoryIcon';

import { styles } from './ReplicasetServerListItem.styles';

const { getReadableBytes } = app.utils;

export interface ReplicasetServerListItemStatistic {
  arenaUsed: number;
  quotaSize: number;
  bucketsCount?: Maybe<number>;
  arena_used_ratio: string;
  quota_used_ratio: string;
  items_used_ratio: string;
}

export interface ReplicasetServerListItemServer {
  message: string;
  uri: string;
  uuid: string;
  status: string;
  alias?: Maybe<string>;
  disabled?: Maybe<boolean>;
}

export interface ReplicasetServerListItemServerAdditional {
  master: boolean;
  activeMaster: boolean;
  replicasetUUID: string;
  selfURI?: string;
  totalBucketsCount?: number;
  ro?: boolean;
  statistics?: Maybe<ReplicasetServerListItemStatistic>;
}

export interface ReplicasetServerListItemProps {
  server: ReplicasetServerListItemServer;
  additional: ReplicasetServerListItemServerAdditional;
  showFailoverPromote: boolean;
  className?: string;
}

const ReplicasetServerListItem = (props: ReplicasetServerListItemProps) => {
  const {
    server: { uuid, uri, alias, status, disabled = false, message },
    additional: { master, activeMaster, selfURI, totalBucketsCount, ro, statistics },
    showFailoverPromote,
    className,
  } = props;

  const [usageText, percentage] = useMemo((): [string, number] => {
    if (!statistics) {
      return ['', 1];
    }

    return [
      `Memory usage: ${getReadableBytes(statistics.arenaUsed)} / ${getReadableBytes(statistics.quotaSize)}`,
      Math.max(1, (statistics.arenaUsed / statistics.quotaSize) * 100),
    ];
  }, [statistics]);

  return (
    <FlatListItem
      className={cx(styles.rowWrap, { [styles.disabledRowWrap]: disabled }, 'ServerLabelsHighlightingArea', className)}
    >
      <div className={cx(styles.row, { [styles.disabledRow]: disabled })}>
        {(master || activeMaster) && (
          <LeaderFlag
            className={cx(styles.leaderFlag, 'meta-test_leaderFlag')}
            state={status !== 'healthy' ? 'bad' : ro === false ? 'good' : 'warning'}
          />
        )}
        <div className={styles.heading}>
          <Text variant="h4" className={styles.alias}>
            <Link className={styles.aliasLink} to={cluster.page.paths.serverDetails({ uuid })}>
              {alias}
            </Link>
          </Text>
          <UriLabel
            uri={uri}
            weAreHere={selfURI && uri === selfURI}
            className={selfURI && uri === selfURI && 'meta-test__youAreHereIcon'}
          />
        </div>
        <div className={styles.statusGroup}>
          <HealthStatus className={styles.status} status={status} message={message} />
          <div className={cx(styles.stats, 'meta-test__bucketIcon')}>
            {statistics && (
              <React.Fragment>
                {typeof statistics.bucketsCount === 'number' ? (
                  <Tooltip
                    className={styles.bucketsCount}
                    content={
                      <>
                        {'Total buckets: '}
                        <b>{typeof totalBucketsCount === 'number' ? totalBucketsCount : '-'}</b>
                      </>
                    }
                  >
                    <IconBucket className={styles.iconMargin} />
                    <Text className={styles.statsText} variant="p" tag="span">
                      Buckets: <b>{(statistics && statistics.bucketsCount) || '-'}</b>
                    </Text>
                  </Tooltip>
                ) : (
                  <div className={styles.bucketsCount} />
                )}
                <div className={styles.memStats}>
                  <div>
                    {statistics && <MemoryIcon {...statistics} />}
                    <Text className={styles.statsText} variant="p" tag="span">
                      {usageText}
                    </Text>
                  </div>
                  <ProgressBar className={styles.memProgress} percents={percentage} statusColors />
                </div>
              </React.Fragment>
            )}
          </div>
        </div>
      </div>
      <ServerDropdown
        // activeMaster={activeMaster}
        className={styles.configureBtn}
        // disabled={Boolean(disabled)}
        // replicasetUUID={replicasetUUID}
        // uri={uri}
        uuid={uuid}
        showServerDetails
        showFailoverPromote={showFailoverPromote}
      />
    </FlatListItem>
  );
};

export default memo(ReplicasetServerListItem, (prevProps, nextProps) => {
  return (
    prevProps.className === nextProps.className &&
    prevProps.showFailoverPromote === nextProps.showFailoverPromote &&
    isEqual(prevProps.server, nextProps.server) &&
    isEqual(prevProps.additional, nextProps.additional)
  );
});
