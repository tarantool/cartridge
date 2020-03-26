// @flow
import * as React from 'react';
import { cx, css } from 'emotion';
import { connect } from 'react-redux';
import {
  Button,
  IconCancel,
  IconOk
} from '@tarantool.io/ui-kit';
import { ClusterIssuesModal } from 'src/components/ClusterIssuesModal';
import type { State } from 'src/store/rootReducer';
import type { ClusterIssue } from 'src/store/reducers/clusterPage.reducer'

const styles = {
  contrastIcon: css`fill: gray;`
}

const IconOkContrast = ({ className, props }) => <IconOk className={cx(styles.contrastIcon, className)} {...props} />

type ClusterIssuesButtonProps = {
  issues: ClusterIssue[]
}

type ClusterIssuesButtonState = {
  visible: boolean
}

class ClusterIssuesButton extends React.Component<ClusterIssuesButtonProps, ClusterIssuesButtonState> {
  state = {
    visible: false
  };

  showModal = () => this.setState({ visible: true });

  hideModal = () => this.setState({ visible: false });

  render() {
    const { issues } = this.props;
    const { visible } = this.state;

    return (
      <>
        <Button
          className='meta-test__ClusterIssuesButton'
          disabled={!issues.length}
          intent='secondary'
          icon={issues.length ? IconCancel : IconOkContrast}
          onClick={this.showModal}
          text={`Issues: ${issues.length}`}
        />
        <ClusterIssuesModal
          visible={visible}
          onClose={this.hideModal}
          issues={issues}
        />
      </>
    );
  }
};

const mapStateToProps = ({ clusterPage: { issues } }: State) => ({ issues });

export default connect(mapStateToProps)(ClusterIssuesButton);
