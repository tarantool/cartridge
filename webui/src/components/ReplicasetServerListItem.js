// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'react-emotion';
import {
  HealthStatus,
  IconBucket,
  IconChip,
  IconChipWarning,
  IconChipDanger,
  LeaderFlag,
  ProgressBar,
  Text,
  Tooltip,
  UriLabel
} from '@tarantool.io/ui-kit';
import { withRouter, Link } from 'react-router-dom';
import { type MemoryUsageRatios } from 'src/misc/memoryStatistics';
import { getMemoryFragmentationLevel } from 'src/store/selectors/clusterPage';
import { ServerDropdown } from 'src/components/ServerDropdown';
import { type Label } from 'src/components/ServerLabels';

const styles = {
  row: css`
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    padding-right: 31px;
    margin-bottom: -8px;
  `,
  heading: css`
    flex-basis: 415px;
    flex-grow: 1;
    flex-shrink: 0;
    margin-right: 16px;
    margin-bottom: 8px;
    overflow: hidden;
  `,
  alias: css`
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  aliasLink: css`
    color: #000;

    &:hover,
    &:active {
      color: #000;
    }

    &:focus {
      color: #777;
    }
  `,
  leaderFlag: css`
    position: absolute;
    top: 0;
    left: 3px;
  `,
  iconMargin: css`
    margin-right: 4px;
  `,
  statusGroup: css`
    display: flex;
    flex-basis: 576px;
    flex-shrink: 0;
    flex-grow: 1;
    align-items: flex-start;
    margin-bottom: 8px;
  `,
  memStats: css`
    flex-shrink: 0;
    width: 246px;
  `,
  memStatsRow: css`
    display: flex;
    align-items: center;
  `,
  statsText: css`
    white-space: nowrap;
  `,
  memProgress: css`
    width: auto;
    margin-left: 20px;
  `,
  status: css`
    flex-basis: 193px;
    flex-shrink: 0;
    margin-top: 1px;
    margin-right: 16px;
    margin-left: -8px;
  `,
  stats: css`
    position: absolute;
    right: 46px;
    display: flex;
    flex-shrink: 0;
    align-items: stretch;
    margin-left: auto;
    width: 384px;
  `,
  bucketsCount: css`
    flex-shrink: 0;
    display: flex;
    align-items: center;
    width: 122px;
    margin-right: 16px;
  `,
  tags: css`
    margin-top: 8px;
  `,
  configureBtn: css`
    position: absolute;
    top: 12px;
    right: 12px;
  `
};

const byteUnits = ['KiB', 'MiB', 'GiB', 'TiB', 'PiB'];

const getReadableBytes = size => {
  let bytes = size;
  let i = -1;
  do {
    bytes = bytes / 1024;
    i++;
  }
  while (bytes > 1024);

  return Math.max(bytes, 0.1).toFixed(1) + ' ' + byteUnits[i];
};

type ServerAction = {
  onClick?: (MouseEvent) => void,
  color?: string,
  text?: string,
}

type Server = {
  selfURI?: string,
  statistics?: {
    arenaUsed: number,
    bucketsCount: number,
    quotaSize: number
  } & MemoryUsageRatios,
  status: string,
  uri: string,
  alias?: string,
  // disabled?: boolean,
  message: string,
  // priority?: number,
  labels?: ?Array<Label>,
  master?: boolean,
  serverActions?: ServerAction[],
  history: History,
  uuid: string,
};

type ReplicasetServerListItemProps = {
  ...$Exact<Server>,
  activeMaster?: boolean,
  onServerLabelClick?: (label: Label) => void,
  replicasetUUID: string,
  showFailoverPromote?: boolean,
  tagsHighlightingClassName?: string,
  totalBucketsCount?: number,
  ro?: boolean
};

type ReplicasetServerListItemState = {
  hovered: boolean
}

class ReplicasetServerListItem extends React.PureComponent<
  ReplicasetServerListItemProps,
  ReplicasetServerListItemState
  > {
  render() {
    const {
      activeMaster,
      replicasetUUID,
      selfURI,
      showFailoverPromote,
      statistics,
      status,
      uri,
      alias,
      message,
      master,
      totalBucketsCount,
      history,
      uuid,
      ro
    } = this.props;

    const usageText = statistics
      ? `Memory usage: ${getReadableBytes(statistics.arenaUsed)} / ${getReadableBytes(statistics.quotaSize)}`
      : '';
    const percentage = statistics
      ? Math.max(1, statistics.arenaUsed / statistics.quotaSize * 100)
      : 1;

    return (
      <React.Fragment>
        <div className={styles.row}>
          {(master || activeMaster) &&
            <LeaderFlag
              className={cx(styles.leaderFlag, 'meta-test_leaderFlag')}
              state={status !== 'healthy' ? 'bad' : ro === false ? 'good' : 'warning'}
            />
          }
          <div className={styles.heading}>
            <Text variant='h4' className={styles.alias}>
              <Link className={styles.aliasLink} to={`/cluster/dashboard/instance/${uuid}`}>
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
                  {typeof statistics.bucketsCount === 'number'
                    ? (
                      <Tooltip
                        className={styles.bucketsCount}
                        content={(
                          <React.Fragment>
                            {'Total buckets: '}
                            <b>{typeof totalBucketsCount === 'number' ? totalBucketsCount : '-'}</b>
                          </React.Fragment>
                        )}
                      >
                        <IconBucket className={styles.iconMargin} />
                        <Text className={styles.statsText} variant='p' tag='span'>
                          Buckets: <b>{(statistics && statistics.bucketsCount) || '-'}</b>
                        </Text>
                      </Tooltip>
                    )
                    : <div className={styles.bucketsCount} />
                  }
                  <div className={styles.memStats}>
                    <div>
                      <MemoryIcon {...statistics} className={styles.iconMargin} />
                      <Text className={styles.statsText} variant='p' tag='span'>{usageText}</Text>
                    </div>
                    <ProgressBar
                      className={styles.memProgress}
                      percents={percentage}
                      statusColors
                    />
                  </div>
                </React.Fragment>
              )}
            </div>
          </div>
        </div>
        <ServerDropdown
          activeMaster={activeMaster}
          className={styles.configureBtn}
          replicasetUUID={replicasetUUID}
          showFailoverPromote={showFailoverPromote}
          showServerDetails
          uri={uri}
          history={history}
          uuid={uuid}
        />
      </React.Fragment>
    )
  }
}


const MemoryIcon = (statistics: $PropertyType<Server, 'statistics'>) => {
  if (statistics) {
    const fragmentationLevel = getMemoryFragmentationLevel(statistics);
    switch (fragmentationLevel) {
      case 'high':
        return (
          <Tooltip tag='span' content="Running out of memory">
            <IconChipDanger className={styles.iconMargin} />
          </Tooltip>
        );
      case 'medium':
        return (
          <Tooltip tag='span' content="Memory is highly fragmented">
            <IconChipWarning className={styles.iconMargin} />
          </Tooltip>
        );
    }
  }
  return <IconChip className={styles.iconMargin} />;
};


export default withRouter(ReplicasetServerListItem);
