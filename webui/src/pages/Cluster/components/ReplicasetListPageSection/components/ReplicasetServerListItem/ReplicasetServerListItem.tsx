/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { cx } from '@emotion/css';
import isEqual from 'lodash/isEqual';
// @ts-ignore
import { LeaderFlag, Text, Tooltip, UriLabel } from '@tarantool.io/ui-kit';

import { LabelInput } from 'src/generated/graphql-typing-ts';
import { cluster } from 'src/models';
import type { Maybe } from 'src/models';

import ServerDropdown from '../../../ServerDropdown';
import { NonElectableFlag } from '../NonElectableFlag';
import ReplicasetListBuckets from '../ReplicasetListBuckets';
import ReplicasetListMemStat from '../ReplicasetListMemStat';
import ReplicasetListStatus from '../ReplicasetListStatus';
import ReplicasetListTag from '../ReplicasetListTag';

import { styles } from './ReplicasetServerListItem.styles';

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
  electable?: Maybe<boolean>;
  labels?: LabelInput[];
}

export interface ReplicasetServerListItemServerAdditional {
  master: boolean;
  activeMaster: boolean;
  replicasetUUID: string;
  selfURI?: string;
  vshardGroupBucketsCount?: number;
  ro?: boolean;
  statistics?: Maybe<ReplicasetServerListItemStatistic>;
  filterMatching?: boolean;
}

export interface ReplicasetServerListItemProps {
  server: ReplicasetServerListItemServer;
  additional: ReplicasetServerListItemServerAdditional;
  showFailoverPromote: boolean;
}

const ReplicasetServerListItem = (props: ReplicasetServerListItemProps) => {
  const {
    server: { uuid, uri, alias, status, disabled = false, electable = true, message, labels },
    additional: { master, activeMaster, selfURI, vshardGroupBucketsCount, ro, statistics, filterMatching },
    showFailoverPromote,
  } = props;

  const labelsParse = useMemo(() => {
    return labels?.map((label, index) => {
      if (label?.name && label?.value) {
        return (
          <ReplicasetListTag className={styles.serverLabel} key={`${index}/${label.name}`} title={label.name}>
            {label.value}
          </ReplicasetListTag>
        );
      }
      return null;
    });
  }, [labels]);

  return (
    <div
      className={cx(
        styles.root,
        {
          [styles.disabledRowWrap]: disabled,
        },
        'ServerLabelsHighlightingArea'
      )}
      data-component="ReplicasetServerListItem"
      data-value-disabled={disabled ? 'true' : 'false'}
      data-value-status={status}
      data-value-message={message}
    >
      <div
        className={cx(styles.row, {
          [styles.disabledRow]: disabled,
          [styles.filterIsNotMatching]: filterMatching === false,
        })}
      >
        {(master || activeMaster) && (
          <LeaderFlag
            className={cx(styles.leaderFlag, 'meta-test_leaderFlag')}
            state={status !== 'healthy' ? 'bad' : ro === false ? 'good' : 'warning'}
          />
        )}
        {!electable && <NonElectableFlag className={cx(styles.nonElectableFlag, 'meta-test_nonElectableFlag')} />}
        <div className={cx(styles.sign, alias && styles.signWithAlias)}>
          {selfURI && uri === selfURI && (
            <Tooltip content="WebUI operates here">
              <UriLabel weAreHere className="meta-test__youAreHereIcon" />
            </Tooltip>
          )}
        </div>
        <div className={styles.head}>
          <div className={styles.aliasWrp}>
            {alias && (
              <Text variant="h4" className={styles.alias}>
                <Link className={styles.aliasLink} to={cluster.page.paths.serverDetails({ uuid })}>
                  {alias}
                </Link>
              </Text>
            )}
          </div>
          <div className={styles.labelWrp}>
            <UriLabel uri={uri} className={styles.label} />
          </div>
          {labels?.length ? <div className={styles.wrapSL}>{labelsParse}</div> : null}
        </div>
        <div className={cx(styles.div, styles.grow)} />
        <div className={styles.status}>
          <ReplicasetListStatus status={status} message={message} />
        </div>
        <div className={styles.div} />
        <div className={styles.buckets}>
          <ReplicasetListBuckets count={statistics?.bucketsCount} total={vshardGroupBucketsCount} />
        </div>
        <div className={styles.div} />
        <div className={styles.mem}>{statistics && <ReplicasetListMemStat {...statistics} />}</div>
        <div className={styles.div} />
        <ServerDropdown
          className={cx(styles.configureBtn, 'no-opacity')}
          uuid={uuid}
          showServerDetails
          showFailoverPromote={showFailoverPromote}
        />
      </div>
    </div>
  );
};

export default memo(ReplicasetServerListItem, (prevProps, nextProps) => {
  return (
    prevProps.showFailoverPromote === nextProps.showFailoverPromote &&
    isEqual(prevProps.server, nextProps.server) &&
    isEqual(prevProps.additional, nextProps.additional)
  );
});
