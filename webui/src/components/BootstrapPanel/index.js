import React from "react";
import {connect} from 'react-redux';
import {setVisibleBootstrapVshardModal} from '../../store/actions/clusterPage.actions';
import Spin from "../Spin";

class BootstrapPanel extends React.Component {
  render() {
    const { can_bootstrap_vshard, vshard_bucket_count, requesting } = this.props;

    if (!can_bootstrap_vshard)
      return null;

    return (

        <div className="tr-card tr-card-margin">
          <Spin enable={requesting}>
            <div className="tr-card-head">
              <div className="tr-card-header">
                Tarantool vshard
              </div>
            </div>
            <div className="tr-card-content">
              <p>The application is configured to store <b>{vshard_bucket_count}</b> buckets but they are not in place yet.</p>
              <p>Bootstrap vshard to render storages operable.</p>
              <button className="btn btn-primary"
                      onClick={() => {this.showModal()}}
              >
                Bootstrap vshard
              </button>
            </div>
          </Spin>
        </div>

    );
  }

  showModal = () => {
    this.props.dispatch(setVisibleBootstrapVshardModal(true))
  };
}


export default connect(({app, ui}) => {
  return {
    can_bootstrap_vshard: (app.clusterSelf && app.clusterSelf.can_bootstrap_vshard) || false,
    vshard_bucket_count: (app.clusterSelf && app.clusterSelf.vshard_bucket_count) || 0,
    requesting: ui.requestingBootstrapVshard,
  }
})(
  BootstrapPanel
);
