// @flow
// TODO: move to uikit
import * as React from 'react';
import { css } from 'react-emotion';
import Tooltip from 'src/components/Tooltip';
import Dropdown from 'src/components/Dropdown';
import { IconBucket, IconChip, IconLink } from 'src/components/Icon';
import ServerLabels, { type Label } from 'src/components/ServerLabels';
import LeaderFlag from 'src/components/LeaderFlag';
import ProgressBar from 'src/components/ProgressBar';
import Text from 'src/components/Text';
import store from 'src/store/instance'
import HealthStatus from 'src/components/HealthStatus';
import { showExpelModal } from '../store/actions/clusterPage.actions';
import { withRouter } from 'react-router-dom'

const styles = {
  row: css`
    display: flex;
    align-items: baseline;
    margin-bottom: 4px;
  `,
  heading: css`
    flex-basis: 480px;
    flex-grow: 1;
    margin-right: 12px;
  `,
  leaderFlag: css`
    position: absolute;
    top: 0;
    left: 3px;
  `,
  iconMargin: css`
    margin-right: 8px;
  `,
  uriWrap: css`
    display: flex;
    align-items: center;
  `,
  uriIcon: css`
    margin-right: 4px;
  `,
  memProgress: css`
    width: 183px;
    margin-left: 24px;
  `,
  configureBtn: css`
    margin-left: 8px;
  `,
  status: css`
    flex-basis: 153px;
    margin-right: 12px;
    margin-left: 12px;
  `,
  stats: css`
    position: relative;
    display: flex;
    flex-basis: 351px;
    align-items: flex-start;
    margin-right: 12px;
    margin-left: 12px;

    & > *:first-child {
      position: relative;
      margin-right: 17px;
    }

    & > *:first-child::before {
      content: '';
      position: absolute;
      top: 0px;
      right: -8px;
      width: 1px;
      height: 18px;
      background-color: #e8e8e8;
    }
  `
};

const byteUnits = ['kB', 'MB', 'GB', 'TB', 'PB'];

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
  labels?: ?Array<?Label>,
  master?: boolean,
  serverActions?: ServerAction[]
};

type ReplicasetServerListItemProps = {
  ...$Exact<Server>,
  onServerLabelClick?: (MouseEvent) => void,
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
      statistics,
      status,
      uri,
      alias,
      message,
      labels,
      master,
      serverActions,
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
          {master && (
            <LeaderFlag className={styles.leaderFlag} />
          )}
          <div className={styles.heading}>
            <Text variant='h4'>{alias}</Text>
            <div className={styles.uriWrap}>
              <IconLink className={styles.uriIcon} />
              <Text variant='h5' tag='span'>{uri}</Text>
            </div>
          </div>
          <HealthStatus status={status} message={message} />
          <div className={styles.stats}>
            <div>
              <IconBucket className={styles.iconMargin} />
              <Tooltip content={<span>total bucket: <b>{(statistics && statistics.bucketsCount) || 0}</b></span>}>
                <span>Bucket:<b>{(statistics && statistics.bucketsCount) || 0}</b></span>
              </Tooltip>
            </div>
            <div>
              <div>
                <IconChip className={styles.iconMargin} />
                <span>{usageText}</span>
              </div>
              <ProgressBar
                className={styles.memProgress}
                percents={percentage}
                statusColors
              />
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
                onClick: () =>{
                  store.dispatch(showExpelModal(uri))
                },
                color: 'rgba(245, 34, 45, 0.65)'
              }
            ]}
            className={styles.configureBtn}
            size={'s'}
          />
        </div>
        <ServerLabels
          labels={labels}
          onLabelClick={onServerLabelClick}
          highlightingOnHover={tagsHighlightingClassName}
        />
      </React.Fragment>
    )
  }
}

export default withRouter(ReplicasetServerListItem);
