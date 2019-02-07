import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';
import * as R from 'ramda';

import CommonItemList from 'src/components/CommonItemList';
import cn from 'src/misc/cn';

import './ServerList.css';
import {css} from 'react-emotion';

const styles = {
  button: css`
    color: #FF272C;
    display: inline-block;
    padding: 0;
    margin: 0 30px 0 0;
    background: none;
    border: none;
    cursor: pointer;
    font-size: 12px;
    text-decoration: none;
    :last-child{
      margin: 0;
    }
    :hover{
      text-decoration: underline;
    }
  `,
  buttonContainer: css`
    margin-right: 45px;
    display: flex;
  `,
  statusBlock: css`
    display: flex;
  `,
  indicatorBlock: css`
    margin-right: 18px;  
  `,
  nameBlock: css`
  
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
          if ( ! record.activeMaster) {
            masterClassName = cn(masterClassName, 'ServerList-masterDown');
          }
        } else if (record.activeMaster) {
          masterText = 'active master';
        }

        return (
          <div className={styles.statusBlock}>
            <div className={styles.indicatorBlock}><span className="ServerList-indicator" /></div>

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
        return <span style={{fontSize: '14px', color: '#5D5D5D'}}>{record.status}</span>
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
        if ( ! statistics) {
          return <span>No statistics</span>;
        }

        const { arenaUsed, quotaSize } = statistics;

        const usageText = `Memory usage: ${getReadableBytes(arenaUsed)} / ${getReadableBytes(quotaSize)}`;
        const percentage = Math.max(1, statistics.arenaUsed / statistics.quotaSize * 100);
        const style = { width: '100%', paddingLeft: `${percentage}%` };

        const defineStatus = R.cond([
          [R.lt(66), R.always('error')],
          [R.lt(33), R.always('warning')],
          [R.T, R.always('success')]
        ]);

        const className = `ServerList-statBar ServerList-statBar--${defineStatus(percentage)}`;

        return (
          <div className="ServerList-stat">
            <span className="ServerList-statName">{usageText}</span>
            <span style={style} className={className} />
          </div>
        );
      },
    },
    {
      key: 'action',
      title: 'Actions',
      render: record => {
        const consoleButtonVisible = false && record.status !== 'unconfigured';
        const handleConsoleClick = () => consoleServer(record);
        const joinButtonVisible = clusterSelf.configured && !record.uuid;
        const handleJoinClick = () => joinServer(record);
        const createButtonVisible = clusterSelf.configured ? !record.uuid : record.uri === clusterSelf.uri;
        const handleCreateClick = () => createReplicaset(record);
        const expelButtonVisible = !!record.uuid;
        const handleExpelClick = () => expelServer(record);

        const buttonClassName = `${styles.button}`;

        return (
          <div className={styles.buttonContainer}>
            {consoleButtonVisible
              ? (
                <button
                  type="button"
                  className={buttonClassName}
                  onClick={handleConsoleClick}
                >
                  Console
                </button>
              )
              : null}
            {joinButtonVisible
              ? (
                <button
                  type="button"
                  className={buttonClassName}
                  onClick={handleJoinClick}
                >
                  Join
                </button>
              )
              : null}
            {createButtonVisible
              ? (
                <button
                  type="button"
                  className={buttonClassName}
                  onClick={handleCreateClick}
                >
                  Create
                </button>
              )
              : null}
            {expelButtonVisible
              ? (
                <button
                  type="button"
                  className={buttonClassName}
                  onClick={handleExpelClick}
                >
                  Expel
                </button>
              )
              : null}
          </div>
        );
      },
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

  return columns.filter(column => ! removedColumns.includes(column.key));
};

const getRowCalssName = record => {
  return record.status !== 'healthy' ? 'ServerList-row--error' : 'ServerList-row--success';
};

const prepareDataSource = dataSource => {
  // return dataSource.sort((a, b) => (b.master - a.master));
  return dataSource.sort((a, b) => {
    return b.master !== a.master
      ? b.master - a.master
      : a.alias === b.alias
        ? a.uri > b.uri ? 1 : -1
        : a.alias > b.alias ? 1 : -1;
  });
};

class ServerList extends React.PureComponent {
  render() {
    const { linked } = this.props;
    const skin = linked ? 'light' : 'enterprise';
    const shouldRenderHead = ! linked;
    const columns = this.getColumnProps();
    const dataSource = this.getDataSource();

    return (
      <div className="ServerList">
        <CommonItemList
          rowKey="uri"
          rowClassName={getRowCalssName}
          skin={skin}
          shouldRenderHead={shouldRenderHead}
          columns={columns}
          dataSource={dataSource} />
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
