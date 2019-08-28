// @flow
import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';
import { css } from 'emotion';
import { withRouter } from 'react-router-dom';
import Button from 'src/components/Button';
import Tooltip from 'src/components/Tooltip';
import Divider from 'src/components/Divider';
import DotIndicator from 'src/components/DotIndicator';
import { IconGear } from 'src/components/Icon';
import TiledList from 'src/components/TiledList';
import Text from 'src/components/Text';
import ReplicasetRoles from 'src/components/ReplicasetRoles';
import ReplicasetServerList from 'src/components/ReplicasetServerList';
import { addSearchParams } from 'src/misc/url';
import type { Replicaset } from 'src/generated/graphql-typing';

const styles = {
  header: css`
    display: flex;
    align-items: baseline;
  `,
  tooltip: css`
    flex: auto;
  `,
  alias: css`
    flex-basis: 512px;
    flex-grow: 1;
    margin-right: 12px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  status: css`
    display: flex;
    flex-basis: 153px;
    align-items: center;
    margin-left: 12px;
    margin-right: 12px;
  `,
  vshard: css`
    position: relative;
    flex-basis: 306px;
    margin-left: 12px;
    margin-right: 12px;

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
  `,
  editBtn: css`
    margin-left: 12px;
  `,
  divider: css`
    margin-top: 16px;
  `
};

const prepareReplicasetList = dataSource => [...dataSource].sort((a, b) => b.uuid < a.uuid ? 1 : -1);

class ReplicasetList extends React.PureComponent<> {
  prepareReplicasetList = defaultMemoize(prepareReplicasetList);

  render() {
    const {
      className,
      clusterSelf,
      editReplicaset,
      joinServer,
      expelServer,
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
              <Tooltip className={styles.tooltip} content={replicaset.alias}>
                <Text className={styles.alias} variant='h3'>{replicaset.alias}</Text>
              </Tooltip>
              <Text className={styles.status} variant='p' tag='span'>
                <DotIndicator state={replicaset.status === 'healthy' ? 'good' : 'bad'} />
                {replicaset.message || replicaset.status}
              </Text>
              <Text className={styles.vshard} variant='p' tag='span' upperCase>
                {(replicaset.vshard_group || replicaset.weight) && [
                  <b>{replicaset.vshard_group}</b>,
                  <b>{replicaset.weight}</b>
                ]}
              </Text>
              <Button
                className={styles.editBtn}
                icon={IconGear}
                intent='secondary'
                onClick={() => this.handleEditReplicasetRequest(replicaset)}
                size='s'
                text='Edit'
              />
            </div>
            <ReplicasetRoles roles={replicaset.roles}/>
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
