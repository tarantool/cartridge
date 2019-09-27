import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';
import { css, cx } from 'emotion';
import { withRouter } from 'react-router-dom';
import {
  Button,
  Divider,
  HealthStatus,
  IconGear,
  Text,
  TiledList
} from '@tarantool.io/ui-kit';
import Tooltip from 'src/components/Tooltip';
import ReplicasetRoles from 'src/components/ReplicasetRoles';
import ReplicasetServerList from 'src/components/ReplicasetServerList';
import { addSearchParams } from 'src/misc/url';

const styles = {
  header: css`
    position: relative;
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    padding-right: 103px;
  `,
  aliasTooltip: css`
    flex-basis: 463px;
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
  statusGroup: css`
    display: flex;
    flex-basis: 530px;
    flex-shrink: 0;
    margin-bottom: 12px;
  `,
  status: css`
    display: flex;
    flex-shrink: 0;
    flex-basis: 193px;
    align-items: center;
    margin-left: -8px;
    margin-right: 12px;
  `,
  vshardTooltip: css`
    display: inline;
    font-weight: bold;
  `,
  vshardGroupTooltip: css`
    position: relative;
    margin-right: 17px;

    &::before {
      content: '';
      position: absolute;
      top: 0px;
      right: -8px;
      width: 1px;
      height: 18px;
      background-color: #e8e8e8;
    }
  `,
  vshard: css`
    flex-basis: 306px;
    margin-left: 12px;
    margin-right: 12px;
    color: rgba(0, 0, 0, 0.65);
  `,
  editBtn: css`
    position: absolute;
    top: 1px;
    right: 0;
    flex-shrink: 0;
  `,
  roles: css`
    margin-top: 0;
    margin-bottom: 12px;
  `,
  divider: css`
    margin-top: 16px;
  `
};

const prepareReplicasetList = dataSource => [...dataSource].sort((a, b) => b.uuid < a.uuid ? 1 : -1);

class ReplicasetList extends React.PureComponent {
  prepareReplicasetList = defaultMemoize(prepareReplicasetList);

  render() {
    const {
      className,
      clusterSelf,
      editReplicaset,
      joinServer,
      createReplicaset,
      onServerLabelClick
    } = this.props;

    const replicasetList = this.getReplicasetList();

    return (
      <TiledList
        className={className}
        corners='soft'
        itemKey='uuid'
        items={replicasetList}
        itemRender={replicaset => (
          <React.Fragment>
            <div className={styles.header}>
              <Tooltip className={styles.aliasTooltip} content={replicaset.alias}>
                <Text className={styles.alias} variant='h3'>{replicaset.alias}</Text>
              </Tooltip>
              <div className={styles.statusGroup}>
                <HealthStatus className={styles.status} message={replicaset.message} status={replicaset.status} />
                <Text className={styles.vshard} variant='p' tag='div' upperCase>
                  {(replicaset.vshard_group || replicaset.weight) && [
                    <Tooltip className={cx(styles.vshardTooltip, styles.vshardGroupTooltip)} content='Storage group'>
                      {replicaset.vshard_group}
                    </Tooltip>,
                    <Tooltip className={cx(styles.vshardTooltip)} content='Replica set weight'>
                      {replicaset.weight}
                    </Tooltip>,
                  ]}
                </Text>
              </div>
              <Button
                className={styles.editBtn}
                icon={IconGear}
                intent='secondary'
                onClick={() => this.handleEditReplicasetRequest(replicaset)}
                size='s'
                text='Edit'
              />
            </div>
            <ReplicasetRoles className={styles.roles} roles={replicaset.roles}/>
            <Divider className={styles.divider} />
            <ReplicasetServerList
              clusterSelf={clusterSelf}
              replicaset={replicaset}
              editReplicaset={editReplicaset}
              joinServer={joinServer}
              createReplicaset={createReplicaset}
              onServerLabelClick={onServerLabelClick}
            />
          </React.Fragment>
        )}
      />
    );
  }

  getReplicasetList = () => {
    const { dataSource } = this.props;
    return this.prepareReplicasetList(dataSource);
  };

  handleEditReplicasetRequest = (replicaset: Replicaset) => {
    const { history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { r: replicaset.uuid })
    });
  };
}

ReplicasetList.propTypes = {
  clusterSelf: PropTypes.any,
  dataSource: PropTypes.arrayOf(PropTypes.shape({
    uuid: PropTypes.string
  })).isRequired,
  editReplicaset: PropTypes.func.isRequired,
  joinServer: PropTypes.func.isRequired,
  createReplicaset: PropTypes.func.isRequired,
  onServerLabelClick: PropTypes.func
};

export default withRouter(ReplicasetList);
