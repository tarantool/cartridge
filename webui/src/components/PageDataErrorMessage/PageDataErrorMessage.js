import React from 'react';

import { isGraphqlErrorResponse, getGraphqlErrorMessage } from 'src/api/graphql';

class PageDataErrorMessage extends React.PureComponent {
  render() {
    const { error } = this.props;

    return (
      <div className="page-outer pages-Users">
        <div className="page-inner">
          <div className="container">
            {isGraphqlErrorResponse(error)
              ? getGraphqlErrorMessage(error)
              : 'Server error: ' + JSON.stringify(error)}
          </div>
        </div>
      </div>
    );
  }
}

export default PageDataErrorMessage;
