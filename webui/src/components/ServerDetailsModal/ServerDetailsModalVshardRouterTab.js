import React from 'react';
import { connect } from 'react-redux';
import { css } from '@emotion/css';
import { Text, colors } from '@tarantool.io/ui-kit';

// import CollapsibleJSONRenderer from './CollapsibleJSONRenderer';

const styles = {
  wrap: css`
    padding: 20px 0;
  `,
  subtitle: css`
    margin-bottom: 7px;
  `,
  listItem: css`
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    padding: 8px 20px;

    &:nth-child(2n) {
      background-color: #fafafa;
    }
  `,
  leftCol: css`
    display: flex;
    flex-direction: column;
    max-width: 50%;
  `,
  rightCol: css`
    max-width: 50%;
  `,
  subColumnContent: css`
    width: 100%;
  `,
  description: css`
    color: ${colors.dark40};
  `,
};

const renderers = (value) => (
  <div className={styles.rightCol}>
    <Text variant="basic">{value instanceof Array ? `[${value.join(', ')}]` : value}</Text>
  </div>
);

const ServerDetailsModalStatTab = ({ descriptions = {}, paramsArr = [] }) => {
  return (
    <div className={styles.wrap}>
      {paramsArr.map(({ name, params }, index1) => (
        <div key={index1}>
          <Text className={styles.subtitle} variant="h5">
            vshard group: {name}
          </Text>
          <div>
            {params.map(({ name, value }, index2) => (
              <div key={index2} className={styles.listItem}>
                <div className={styles.leftCol}>
                  <Text variant="basic">{name}</Text>
                  {descriptions[name] ? (
                    <Text variant="basic" className={styles.description}>
                      {descriptions[name]}
                    </Text>
                  ) : null}
                </div>
                {renderers(value)}
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
};

const mapStateToProps = ({ clusterInstancePage: { boxinfo, descriptions } }, { sectionName }) => {
  const section = (boxinfo && boxinfo[sectionName]) || [];

  return {
    descriptions: descriptions[sectionName],
    paramsArr: Object.entries(section).map(([, sec]) => {
      return {
        name: sec.vshard_group,
        params: Object.entries(sec)
          .filter(([name]) => name !== 'vshard_group')
          .map(([name, value]) => ({ name, value })),
      };
    }),
  };
};

export default connect(mapStateToProps)(ServerDetailsModalStatTab);
