import React from 'react';
import { connect } from 'react-redux';
import { setVisibleBootstrapVshardModal } from '../../store/actions/clusterPage.actions';
import Card from 'src/components/Card';
import { css } from 'react-emotion'

const styles = {
  button: css`
    width: 170px;
    text-align: center;
    background-color: #FF272C;
    height: 40px;
    line-height: 40px;
    color: #FFF;
    border-radius: 6px;
    box-shadow: none;
    border: none;
    margin-top: 24px;
  `
};

class BootstrapPanel extends React.Component {
  render() {
    const { can_bootstrap_vshard, vshard_bucket_count, requesting } = this.props;

    if (!can_bootstrap_vshard)
      return null;

    return (
      <Card title="Tarantool vshard" loading={requesting}>
        <div>
          The application is configured to store <b>{vshard_bucket_count}</b> buckets but they are not in place yet.
        </div>
        <div>Bootstrap vshard to render storages operable.</div>
        <button className={styles.button} onClick={() => {this.showModal()}}>
          Bootstrap vshard
        </button>
      </Card>
    );
  }

  showModal = () => {
    this.props.dispatch(setVisibleBootstrapVshardModal(true))
  };
}


export default connect(({ app, ui }) => {
  return {
    can_bootstrap_vshard: (app.clusterSelf && app.clusterSelf.can_bootstrap_vshard) || false,
    vshard_bucket_count: (app.clusterSelf && app.clusterSelf.vshard_bucket_count) || 0,
    requesting: ui.requestingBootstrapVshard
  }
})(
  BootstrapPanel
);
