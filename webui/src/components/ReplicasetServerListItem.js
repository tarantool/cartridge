// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'react-emotion';
import ServerLabels, { type Label } from 'src/components/ServerLabels';
import store from 'src/store/instance';
import {
  Button,
  Dropdown,
  DropdownItem,
  HealthStatus,
  IconBucket,
  IconChip,
  IconChipWarning,
  IconChipDanger,
  IconGeoPin,
  IconMore,
  LeaderFlag,
  ProgressBar,
  Text,
  Tooltip,
  UriLabel
} from '@tarantool.io/ui-kit';
import {
  calculateMemoryFragmentationLevel,
  type MemoryUsageRatios
} from 'src/misc/memoryStatistics';
import { showExpelModal } from '../store/actions/clusterPage.actions';
import { withRouter, Link } from 'react-router-dom';

const styles = {
  row: css`
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    padding-right: 40px;
    margin-bottom: -8px;
  `,
  heading: css`
    flex-basis: 430px;
    flex-grow: 1;
    flex-shrink: 0;
    margin-right: 24px;
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
    margin-right: 8px;
  `,
  iconMarginSmall: css`
    margin-right: 4px;
  `,
  statusGroup: css`
    display: flex;
    flex-basis: 576px;
    flex-shrink: 0;
    align-items: flex-start;
    margin-bottom: 8px;
  `,
  memStats: css`
    width: 229px;
  `,
  memProgress: css`
    width: auto;
    margin-left: 24px;
  `,
  configureBtn: css`
    position: absolute;
    top: 12px;
    right: 16px;
  `,
  status: css`
    flex-basis: 193px;
    flex-shrink: 0;
    margin-top: 1px;
    margin-right: 24px;
    margin-left: -8px;
  `,
  stats: css`
    position: relative;
    display: flex;
    flex-basis: 351px;
    flex-shrink: 0;
    align-items: stretch;
  `,
  bucketsCount: css`
    flex-shrink: 0;
    width: 120px;
    margin-right: 16px;
  `,
  tags: css`
    margin-top: 8px;
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
  tagsHighlightingClassName?: string,
  totalBucketsCount?: number
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
      selfURI,
      statistics,
      status,
      uri,
      alias,
      message,
      labels,
      master,
      onServerLabelClick,
      tagsHighlightingClassName,
      totalBucketsCount,
      history,
      uuid
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
          {(master || activeMaster) && <LeaderFlag className={styles.leaderFlag} fail={status !== 'healthy'} />}
          <div className={styles.heading}>
            <Text variant='h4' className={styles.alias}>
              <Link className={styles.aliasLink} to={`/cluster/dashboard/instance/${uuid}`}>
                {alias}
              </Link>
            </Text>
            <UriLabel 
              uri={uri} 
              icon={selfURI && uri === selfURI && IconGeoPin} 
              className={selfURI && uri === selfURI && 'meta-test__youAreHereIcon'}
            />
          </div>
          <div className={styles.statusGroup}>
            <HealthStatus className={styles.status} status={status} message={message} />
            <div className={styles.stats}>
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
                        <IconBucket className={styles.iconMarginSmall} />
                        <Text variant='h5' tag='span'>
                          Buckets: <b>{(statistics && statistics.bucketsCount) || '-'}</b>
                        </Text>
                      </Tooltip>
                    )
                    : <div className={styles.bucketsCount} />
                  }
                  <div className={styles.memStats}>
                    <div>
                      <MemoryIcon {...statistics} />
                      <Text variant='h5' tag='span'>{usageText}</Text>
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
        <Dropdown
          items={[
            <DropdownItem
              onClick={() => history.push(`/cluster/dashboard/instance/${uuid}`)}
            >
              Server details
            </DropdownItem>,
            <DropdownItem
              className={css`color: rgba(245, 34, 45, 0.65);`}
              onClick={() => store.dispatch(showExpelModal(uri))}
            >
              Expel server
            </DropdownItem>
          ]}
          className={cx(styles.configureBtn, 'meta-test__ReplicasetServerListItem__dropdownBtn')}
        >
          <Button
            icon={IconMore}
            size='s'
            intent='iconic'
          />
        </Dropdown>
        <ServerLabels
          className={styles.tags}
          labels={(labels || [])}
          onLabelClick={onServerLabelClick}
          highlightingOnHover={tagsHighlightingClassName}
        />
      </React.Fragment>
    )
  }
}


const MemoryIcon = (statistics: $PropertyType<Server, 'statistics'>) => {
  if (statistics) {
    const fragmentationLevel = calculateMemoryFragmentationLevel(statistics);
    switch (fragmentationLevel) {
      case 'high':
        return (
          <Tooltip tag='span' content="Warning: Your memory is highly fragmented">
            <IconChipDanger className={styles.iconMargin} />
          </Tooltip>
        );
      case 'medium':
        return (
          <Tooltip tag='span' content="Warning: Your memory is fragmented">
            <IconChipWarning className={styles.iconMargin} />
          </Tooltip>
        );
    }
  }
  return <IconChip className={styles.iconMargin} />;
};


export default withRouter(ReplicasetServerListItem);
