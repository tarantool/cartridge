// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'react-emotion';
import { defaultMemoize } from 'reselect';
import {
  Button,
  HealthStatus,
  Text,
  TiledList,
  UriLabel
} from '@tarantool.io/ui-kit';
import type { Server } from 'src/generated/graphql-typing';

const styles = {
  row: css`
    position: relative;
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    padding-right: 159px;
    padding-bottom: 4px;
  `,
  checkBox: css`
    flex-shrink: 0;
    align-self: center;
    margin-right: 16px;
  `,
  heading: css`
    flex-basis: 458px;
    flex-grow: 1;
    flex-shrink: 0;
    margin-right: 16px;
    margin-bottom: 8px;
    overflow: hidden;
  `,
  status: css`
    display: flex;
    flex-basis: 505px;
    flex-shrink: 0;
    align-items: center;
    margin-bottom: 8px;
    margin-left: -8px;
  `,
  configureBtn: css`
    position: absolute;
    top: 12px;
    right: 16px;
  `,
  hiddenButton: css`
    visibility: hidden;
  `
};

const prepareDataSource = (dataSource, clusterSelf) => {
  if (clusterSelf.configure)
    return [...dataSource];
  return [...dataSource].sort((a, b) => {
    return a.uri === clusterSelf.uri ? -1 : (b.uri === clusterSelf.uri ? 1 : 0)
  });
}

type UnconfiguredServerListProps = {
  className?: string,
  clusterSelf: ?{
    uri: ?string,
    uuid: ?string,
  },
  dataSource: Server[],
  onServerConfigure: (Server) => void
};

class UnconfiguredServerList extends React.PureComponent<UnconfiguredServerListProps> {
  render() {
    const { uri, uuid } = (this.props.clusterSelf || {});
    const dataSource = this.getDataSource();

    return (
      <TiledList
        className='meta-test__UnconfiguredServerList'
        itemClassName={cx(styles.row, this.props.className)}
        itemKey="uri"
        items={dataSource}
        itemRender={item => (
          <React.Fragment>
            {/* <Checkbox
              className={styles.checkBox}
              checked={false}
              disabled
            /> */}
            <div className={styles.heading}>
              <Text variant='h4' tag='span'>{item.alias}</Text>
              <UriLabel
                uri={item.uri}
                weAreHere={uri && item.uri === uri}
                className={uri && item.uri === uri && 'meta-test__youAreHereIcon'}
              />
            </div>
            <HealthStatus
              className={styles.status}
              status={item.status}
              message={item.message}
            />
            <Button
              className={cx(styles.configureBtn,'meta-test__configureBtn',
                { [styles.hiddenButton]: !(uuid || (uri === item.uri)) } )}
              intent='secondary'
              onClick={() => this.props.onServerConfigure(item)}
              text='Configure'
            />
          </React.Fragment>
        )}
        outer={false}
      />
    );
  };

  getDataSource = () => {
    const { dataSource } = this.props;
    return this.prepareDataSource(dataSource, this.props.clusterSelf);
  };

  prepareDataSource = defaultMemoize(prepareDataSource);
}

export default UnconfiguredServerList;
