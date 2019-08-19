// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'react-emotion';
import { defaultMemoize } from 'reselect';
import Button from 'src/components/Button';
import Checkbox from 'src/components/Checkbox';
import DotIndicator from 'src/components/DotIndicator';
import TiledList from 'src/components/TiledList';
import Text from 'src/components/Text';
import { IconGear, IconLink } from 'src/components/Icon';
import type { Server } from 'src/generated/graphql-typing';

const styles = {
  row: css`
    display: flex;
    align-items: baseline;
  `,
  checkBox: css`
    flex-shrink: 0;
    align-self: center;
    margin-right: 16px;
  `,
  heading: css`
    flex-basis: 480px;
    flex-grow: 1;
    margin-right: 12px;
  `,
  status: css`
    display: flex;
    flex-basis: 441px;
    align-items: center;
    margin-right: 12px;
    margin-left: 12px;
  `,
  configureBtn: css`
    margin-left: 12px;
  `,
  uriWrap: css`
    display: flex;
    align-items: center;
  `,
  uriIcon: css`
    margin-right: 4px;
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
  },
  dataSource: Server[],
  onServerConfigure: (Server) => void
};

class UnconfiguredServerList extends React.PureComponent<UnconfiguredServerListProps> {
  render() {
    const dataSource = this.getDataSource();

    return (
      <TiledList
        itemClassName={cx(styles.row, this.props.className)}
        itemKey="uri"
        items={dataSource}
        itemRender={item => (
          <React.Fragment>
            <Checkbox
              className={styles.checkBox}
              checked={false}
              disabled
            />
            <div className={styles.heading}>
              <Text variant='h4' tag='span'>{item.alias}</Text>
              <div className={styles.uriWrap}>
                <IconLink className={styles.uriIcon} />
                <Text variant='h5' tag='span'>{item.uri}</Text>
              </div>
            </div>
            <Text className={styles.status} variant='h5' tag='span'>
              <DotIndicator state={item.status === 'healthy' ? 'good' : 'bad'} />
              {item.message}
            </Text>
            <Button
              className={styles.configureBtn}
              icon={IconGear}
              intent='secondary'
              onClick={() => this.props.onServerConfigure(item)}
              size='s'
              text='Configure'
            />
          </React.Fragment>
        )}
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
