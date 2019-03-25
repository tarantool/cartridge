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

const fieldsDisplayTypes = {
  replication_info: 'json'
};

const renderers = {
  string: value => (
    <span className={cx(styles.rightCol, styles.value)}>
      {value instanceof Array ? `[${value.join(', ')}]` : value}
    </span>
  ),
  json: value => (
    <span className={cx(styles.rightCol, styles.structuredValue)}>
      {JSON.stringify(value, null, 2)}
    </span>
  )
};

const ClusterInstanceSection = ({ descriptions = {}, params = [] }) => {
  return (
    <div className={styles.list}>
      {params.map(({ name, value, displayAs = 'string' }) => (
        <div className={styles.listItem}>
          <div className={styles.leftCol}>
            <span className={styles.key}>{name}</span>
            {!!descriptions[name] && <p className={styles.description}>{descriptions[name]}</p>}
          </div>
          {renderers[displayAs](value)}
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
      .map(key => {
        const param = {
          name: key,
          value: section[key]
        };

        if (fieldsDisplayTypes[key]) {
          param.displayAs = fieldsDisplayTypes[key];
        }

        return param;
      }),
  }
};

export default connect(mapStateToProps)(ClusterInstanceSection);

