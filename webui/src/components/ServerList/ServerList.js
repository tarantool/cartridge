import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import CommonItemList from 'src/components/CommonItemList';
import HealthIndicator from 'src/components/HealthIndicator';
import cn from 'src/misc/cn';

import './ServerList.css';
import { css } from 'react-emotion';
import ServerListCellActions from './child/ServerListCellActions';
import ProgressBar from 'src/components/ProgressBar';

const styles = {
  statusBlock: css`
    display: flex;
  `,
  indicatorBlock: css`
    margin-right: 18px;  
  `,
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

const prepareColumnProps = (linked, clusterSelf, consoleServer, joinServer, createReplicaset, expelServer) => {
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
            masterClassName = cn(masterClassName, 'ServerList-masterDown');
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
                {masterText
                  ? <span className={masterClassName}>{masterText}</span>
                  : null}
              </div>
              {record.message
                ? (
                  <div className="ServerList-message">
                    {record.message}
                  </div>
                )
                : null}

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
          consoleButton={false && record.status !== 'unconfigured'}
          joinButton={clusterSelf.configured && !record.uuid}
          createButton={clusterSelf.configured ? !record.uuid : record.uri === clusterSelf.uri}
          instanceMenu={!!record.uuid}
          onConsole={consoleServer}
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

const prepareDataSource = dataSource => [...dataSource];

class ServerList extends React.PureComponent {
  render() {
    const { linked } = this.props;
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
        />
      </div>
    );
  }

  getColumnProps = () => {
    const { linked, clusterSelf, consoleServer, joinServer, createReplicaset, expelServer } = this.props;
    return this.prepareColumnProps(linked, clusterSelf, consoleServer, joinServer, createReplicaset, expelServer);
  };

  getDataSource = () => {
    const { dataSource } = this.props;
    return this.prepareDataSource(dataSource);
  };

  prepareColumnProps = defaultMemoize(prepareColumnProps);

  prepareDataSource = defaultMemoize(prepareDataSource);
}

ServerList.propTypes = {
  linked: PropTypes.bool,
  clusterSelf: PropTypes.shape({
    uri: PropTypes.string,
  }),
  dataSource: PropTypes.arrayOf(PropTypes.shape({
    uuid: PropTypes.string,
    alias: PropTypes.string,
    uri: PropTypes.string.isRequired,
    status: PropTypes.string,
    message: PropTypes.string,
    replicaset: PropTypes.shape({
      uuid: PropTypes.string.isRequired,
    }),
    statistics: PropTypes.shape({
      quotaSize: PropTypes.number.isRequired,
      arenaUsed: PropTypes.number.isRequired,
    }),
  })).isRequired,
  consoleServer: PropTypes.func.isRequired,
  joinServer: PropTypes.func.isRequired,
  expelServer: PropTypes.func.isRequired,
  createReplicaset: PropTypes.func.isRequired,
};

ServerList.defaultProps = {
  linked: null,
};

export default ServerList;
