// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'react-emotion';
import Tooltip from 'src/components/Tooltip';
import Dropdown from 'src/components/Dropdown';
import ServerLabels, { type Label } from 'src/components/ServerLabels';
import store from 'src/store/instance'
import {
  HealthStatus,
  IconBucket,
  IconChip,
  LeaderFlag,
  ProgressBar,
  Text,
  UriLabel
} from '@tarantool.io/ui-kit';
import { showExpelModal } from '../store/actions/clusterPage.actions';
import { withRouter } from 'react-router-dom'

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
  uriIcon: css`
    margin-right: 4px;
  `,
  uri: css`
    color: rgba(0, 0, 0, 0.65);
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

const byteUnits = ['Kb', 'Mb', 'Gb', 'Tb', 'Pb'];

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
  statistics?: {
    arenaUsed: number,
    bucketsCount: number,
    quotaSize: number
  },
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
  tagsHighlightingClassName?: string
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
      statistics,
      status,
      uri,
      alias,
      message,
      labels,
      master,
      onServerLabelClick,
      tagsHighlightingClassName,
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
            <Text variant='h4' className={styles.alias}>{alias}</Text>
            <UriLabel uri={uri} />
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
                        content={<span>total bucket: <b>{(statistics && statistics.bucketsCount) || '-'}</b></span>}
                      >
                        <IconBucket className={styles.iconMarginSmall} />
                        <Text variant='h5' tag='span'>
                          Bucket: <b>{(statistics && statistics.bucketsCount) || '-'}</b>
                        </Text>
                      </Tooltip>
                    )
                    : <div className={styles.bucketsCount} />
                  }
                  <div className={styles.memStats}>
                    <div>
                      <IconChip className={styles.iconMargin} />
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
            {
              text: 'Detail server',
              onClick: () => {
                history.push(`/cluster/dashboard/instance/${uuid}`)
              }
            },
            {
              text: 'Expel server',
              onClick: () => {
                store.dispatch(showExpelModal(uri))
              },
              color: 'rgba(245, 34, 45, 0.65)'
            }
          ]}
          className={cx(styles.configureBtn, 'ReplicasetServerListItem__dropdownBtn')}
          size={'s'}
        />
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

export default withRouter(ReplicasetServerListItem);
