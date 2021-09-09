// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from '@emotion/css';
import { Button, IconCancel, IconOk } from '@tarantool.io/ui-kit';

import { ClusterIssuesModal } from 'src/components/ClusterIssuesModal';
import type { Issue } from 'src/generated/graphql-typing';
import type { State } from 'src/store/rootReducer';

const styles = {
  contrastIcon: css`
    fill: gray;
  `,
};

const IconOkContrast = ({ className, props }) => <IconOk className={cx(styles.contrastIcon, className)} {...props} />;

type ClusterIssuesButtonProps = {
  issues: Issue[],
};

type ClusterIssuesButtonState = {
  visible: boolean,
};

class ClusterIssuesButton extends React.Component<ClusterIssuesButtonProps, ClusterIssuesButtonState> {
  state = {
    visible: false,
  };

  showModal = () => this.setState({ visible: true });

  hideModal = () => this.setState({ visible: false });

  render() {
    const { issues } = this.props;
    const { visible } = this.state;

    return (
      <>
        <Button
          className="meta-test__ClusterIssuesButton"
          disabled={!issues.length}
          intent={issues.length ? 'primary' : 'base'}
          icon={issues.length ? IconCancel : IconOkContrast}
          onClick={this.showModal}
          text={`Issues: ${issues.length}`}
          size="l"
        />
        <ClusterIssuesModal visible={visible} onClose={this.hideModal} issues={issues} />
      </>
    );
  }
}

const mapStateToProps = ({ clusterPage: { issues } }: State) => ({ issues });

export default connect(mapStateToProps)(ClusterIssuesButton);
