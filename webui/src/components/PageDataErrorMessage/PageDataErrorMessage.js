import React from 'react';
import { css } from 'emotion';
import { isGraphqlErrorResponse, getGraphqlErrorMessage } from 'src/api/graphql';

const styles = {
  outer: css`
    padding-bottom: 50px;
  `
};

class PageDataErrorMessage extends React.PureComponent {
  render() {
    const { error } = this.props;

    return (
      <div className={styles.outer}>
        {isGraphqlErrorResponse(error)
          ? getGraphqlErrorMessage(error)
          : 'Server error: ' + JSON.stringify(error)}
      </div>
    );
  }
}

export default PageDataErrorMessage;
