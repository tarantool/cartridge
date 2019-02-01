import React from "react";
import PropTypes from "prop-types";
import 'src/styles/spin.scss';

export default class Spin extends React.Component {
  static propTypes = {
    enable: PropTypes.bool,
  };

  static defaultProps = {
    enable: false,
  };

  render() {
    const { children, enable } = this.props;
    return (
      <div className="cluster-spin">
        {enable && this.renderSpin()}
        <div className={`cluster-spin__container ${enable ? 'cluster-spin__container_blur' :''}`}>{children}</div>
      </div>
    );
  }

  renderSpin(){
    return <div className={'cluster-spin__spin'}>
      <div className="cluster-spin__spin-animation">
        <div className="cluster-spin__rect"></div>
        <div className="cluster-spin__rect cluster-spin__rect_rect2"></div>
        <div className="cluster-spin__rect cluster-spin__rect_rect3"></div>
        <div className="cluster-spin__rect cluster-spin__rect_rect4"></div>
        <div className="cluster-spin__rect cluster-spin__rect_rect5"></div>
      </div>
    </div>;
  }
}
