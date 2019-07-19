// @flow
import * as React from 'react';
import { defaultMemoize } from 'reselect';

import CommonItemList from 'src/components/CommonItemList';
import HealthIndicator from 'src/components/HealthIndicator';
import ServerLabels from 'src/components/ServerLabels';

import './ServerList.css';
import { css, cx } from 'react-emotion';
import ServerListCellActions from './child/ServerListCellActions';
import ProgressBar from 'src/components/ProgressBar';
import type { Server } from 'src/generated/graphql-typing';

const styles = {
  statusBlock: css`
    display: flex;
  `,
  indicatorBlock: css`
    margin-right: 18px;  
  `,
  mismatchedRow: css`
    opacity: 0.3;
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

const prepareColumnProps = ({
  linked,
  clusterSelf,
  joinServer,
  createReplicaset,
  expelServer,
  onServerLabelClick,
  filterMatching
}) => {
  const columns = [
    {
      key: 'name',
      title: 'Name',
      renderText: record => {
        const aliasText = record.alias || 'No alias';

        let masterText, masterClassName = 'ServerList-master';
        if (record.master) {
          masterText = 'master';
          if (!record.activeMaster) {
            masterClassName = cx(masterClassName, 'ServerList-masterDown');
          }
        } else if (record.activeMaster) {
          masterText = 'active master';
        }

        return (
          <div className={styles.statusBlock}>
            <div className={styles.indicatorBlock}>
              <HealthIndicator state={record.status === 'healthy' ? 'good' : 'bad'} />
            </div>
            <div className="ServerList-name">
              <div>
                <span className="ServerList-alias">{aliasText}</span>
                <span className="ServerList-uri">{record.uri}</span>
                {masterText && <span className={masterClassName}>{masterText}</span>}
              </div>
              {record.message && <div className="ServerList-message">{record.message}</div>}
              <ServerLabels labels={record.labels} onLabelClick={onServerLabelClick} />
            </div>
          </div>
        );
      },
    },
    {
      key: 'uuid',
      title: 'UUID',
      width: '210px',
    },
    {
      key: 'status',
      title: 'Status',
      render: record => {
        return <span style={{ fontSize: '14px', color: '#5D5D5D' }}>{record.status}</span>
      }
    },
    {
      key: 'replicaset.uuid',
      title: 'Replicaset UUID',
      renderText: record => record.replicaset ? record.replicaset.uuid : null,
      width: '210px',
    },
    {
      key: 'message',
      title: 'Message',
    },
    {
      key: 'stat',
      title: 'Stat',
      render: record => {
        const { statistics } = record;
        if (!statistics) {
          return <span>No statistics</span>;
        }

        const { arenaUsed, quotaSize } = statistics;

        const usageText = `Memory usage: ${getReadableBytes(arenaUsed)} / ${getReadableBytes(quotaSize)}`;
        const percentage = Math.max(1, arenaUsed / quotaSize * 100);

        return (
          <React.Fragment>
            <div className="ServerList-stat">
              <span className="ServerList-statName">{usageText}</span>
              <ProgressBar percents={percentage} statusColors />
            </div>
          </React.Fragment>
        );
      },
    },
    {
      key: 'action',
      title: 'Actions',
      render: record => (
        <ServerListCellActions
          record={record}
          joinButton={clusterSelf.configured && !record.uuid}
          createButton={clusterSelf.configured ? !record.uuid : record.uri === clusterSelf.uri}
          instanceMenu={!!record.uuid}
          onJoin={joinServer}
          onCreate={createReplicaset}
          onExpel={expelServer}
        />
      ),
      align: linked ? 'right' : 'left',
      width: linked ? '200px' : '135px',
    },
  ];

  const removedColumns = ['uuid', 'replicaset.uuid', 'message'];

  if (linked === false) {
    removedColumns.push('stat');
  }
  else if (linked === true) {
    removedColumns.push('status', 'message');
  }

  return columns.filter(column => !removedColumns.includes(column.key));
};

const prepareDataSource = (dataSource, clusterSelf) => {
  if (clusterSelf.configure)
    return [...dataSource];
  return [...dataSource].sort((a, b) => {
    return a.uri === clusterSelf.uri ? -1 : (b.uri === clusterSelf.uri ? 1 : 0)
  });
}

type ServerListProps = {
  linked: ?boolean,
  clusterSelf: ?{
    uri: ?string,
  },
  dataSource: Server[],
  matchingServersCount: ?number,
  joinServer: () => void,
  expelServer: () => void,
  createReplicaset: () => void,
  onServerLabelClick: ?() => void
};

class ServerList extends React.PureComponent<ServerListProps> {
  static defaultProps = {
    linked: null,
  };

  render() {
    const { linked, matchingServersCount } = this.props;
    const skin = linked ? 'light' : 'enterprise';
    const shouldRenderHead = !linked;
    const columns = this.getColumnProps();
    const dataSource = this.getDataSource();

    return (
      <div className="ServerList">
        <CommonItemList
          rowKey="uri"
          skin={skin}
          shouldRenderHead={shouldRenderHead}
          columns={columns}
          dataSource={dataSource}
          rowClassName={({ filterMatching }) =>
            (matchingServersCount && !filterMatching && typeof filterMatching === 'boolean')
              ? styles.mismatchedRow : ''
          }
        />
      </div>
    );
  }

  getColumnProps = () => this.prepareColumnProps({ ...this.props });

  getDataSource = () => {
    const { dataSource } = this.props;
    return this.prepareDataSource(dataSource, this.props.clusterSelf);
  };

  prepareColumnProps = defaultMemoize(prepareColumnProps);

  prepareDataSource = defaultMemoize(prepareDataSource);
}

export default ServerList;
