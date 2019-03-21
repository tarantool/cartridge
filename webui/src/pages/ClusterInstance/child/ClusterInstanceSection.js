import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';

const styles = {
  listItem: css`
    display: flex;
    justify-content: space-between;
    margin-bottom: 12px;
  `,
  rightCol: css`
    white-space: pre;
  `,
  key: css`
    font-size: 20px;
  `,
  description: css`
    margin: 0;
    font-size: 14px;
  `,
  structuredValue: css`
    font-size: 14px;
  `,
  value: css`
    font-size: 20px;
  `,
};

const renderString = value => (
  <span className={cx(styles.rightCol, styles.value)}>
    {value instanceof Array ? value.join(', ') : value}
  </span>
);

const renderJSON = value => (
  <span className={cx(styles.rightCol, styles.structuredValue)}>
    {JSON.stringify(value, null, 2)}
  </span>
);

const ClusterInstanceSection = ({ descriptions = {}, params = [] }) => {
  return (
    <div className={styles.list}>
      {params.map(({ name, value }) => (
        <div className={styles.listItem}>
          <div className={styles.leftCol}>
            <span className={styles.key}>{name}</span>
            {!!descriptions[name] && <p className={styles.description}>{descriptions[name]}</p>}
          </div>
          {value instanceof Array ? renderJSON(value) : renderString(value)}
        </div>
      ))}
    </div>
  );
};

const mapStateToProps = (
  {
    clusterInstancePage: {
      boxinfo,
      descriptions
    }
  },
  { sectionName }
) => {
  const section = boxinfo[sectionName];

  return {
    descriptions: descriptions[sectionName],
    params: Object.keys(section)
      .map(key => ({
        name: key,
        value: section[key]
      })),
  }
};

export default connect(mapStateToProps)(ClusterInstanceSection);

