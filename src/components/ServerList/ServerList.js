import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import CommonItemList from 'src/components/CommonItemList';
import cn from 'src/misc/cn';

import './ServerList.css';

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

const prepareColumnProps = (linked, clusterSelf, consoleServer, joinServer, createReplicaset, expellServer) => {
  const columns = [
    {
      key: 'indicator',
      render: record => {
        const indicatorClassName = cn(
          'ServerList-indicator',
          record.status !== 'healthy' && 'ServerList-indicator--error',
        );
        return <span className={indicatorClassName} />;
      },
      width: '6px', // magic: SERVER_INDICATOR_WIDTH
    },
    {
      key: 'name',
      title: 'Name',
      renderText: record => {
        const aliasText = record.alias || 'No alias';
        const uriText = record.uri;
        return (
          <span className="ServerList-name">
            <b className="ServerList-alias">{aliasText}</b>
            <span className="ServerList-uri">{uriText}</span>
            {record.message
              ? (
                <React.Fragment>
                  <br />
                  <span className="ServerList-message">{record.message}</span>
                </React.Fragment>
              )
              : null}
          </span>
        );
      },
    },
    {
      key: 'uuid',
      title: 'UUID',
      width: '21em',
    },
    {
      key: 'status',
      title: 'Status',
    },
    {
      key: 'replicaset.uuid',
      title: 'Replicaset UUID',
      renderText: record => record.replicaset ? record.replicaset.uuid : null,
      width: '21em',
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

        let className;
        switch (Math.floor(percentage / 33)) {
          case 0:
            className = 'ServerList-statBar ServerList-statBar--success';
            break;
          case 1:
            className = 'ServerList-statBar ServerList-statBar--warning';
            break;
          default:
            className = 'ServerList-statBar ServerList-statBar--error';
        }


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
        const consoleButtonVisible = record.status !== 'unconfigured';
        const handleConsoleClick = () => consoleServer(record);
        const joinButtonsVisible = !record.uuid;
        const handleJoinClick = () => joinServer(record);
        const handleCreateClick = () => createReplicaset(record);
        const expellButtonVisible = !!record.uuid;
        const handleExpellClick = () => expellServer(record);

        return (
          <div className="ServerList-actionButtons">
            {consoleButtonVisible
              ? (
                <button
                  type="button"
                  className="btn btn-link btn-sm"
                  onClick={handleConsoleClick}
                >
                  Console
                </button>
              )
              : null}
            {joinButtonsVisible
              ? (
                <button
                  type="button"
                  className="btn btn-link btn-sm"
                  onClick={handleJoinClick}
                >
                  Join
                </button>
              )
              : null}
            {joinButtonsVisible
              ? (
                <button
                  type="button"
                  className="btn btn-link btn-sm"
                  onClick={handleCreateClick}
                >
                  Create
                </button>
              )
              : null}
            {expellButtonVisible
              ? (
                <button
                  type="button"
                  className="btn btn-link btn-sm"
                  onClick={handleExpellClick}
                >
                  Expell
                </button>
              )
              : null}
          </div>
        );
      },
      align: 'center',
      width: '20em',
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

class ServerList extends React.PureComponent {
  constructor(props) {
    super(props);

    this.prepareColumnProps = defaultMemoize(prepareColumnProps);
  }

  render() {
    const { linked, dataSource } = this.props;
    const columns = this.getColumnProps();
    const shouldRenderHead = ! linked;
    const skin = linked ? 'light' : null;

    return (
      <div className="ServerList">
        <CommonItemList
          rowKey="uri"
          skin={skin}
          shouldRenderHead={shouldRenderHead}
          columns={columns}
          dataSource={dataSource} />
      </div>
    );
  }

  getColumnProps = () => {
    const { linked, clusterSelf, consoleServer, joinServer, createReplicaset, expellServer } = this.props;
    return this.prepareColumnProps(linked, clusterSelf, consoleServer, joinServer, createReplicaset, expellServer);
  };
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
  expellServer: PropTypes.func.isRequired,
  createReplicaset: PropTypes.func.isRequired,
};

ServerList.defaultProps = {
  linked: null,
};

export default ServerList;
