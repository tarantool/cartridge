import React from 'react';
import { css } from '@emotion/css';
import { getErrorMessage, isNetworkError } from 'src/api';
import {
  SplashError
} from '@tarantool.io/ui-kit';

const style = css`
  display: flex;
  justify-content: center;
  height: calc(100vh - 145px);
`;

class PageDataErrorMessage extends React.PureComponent {
  render() {
    const { error } = this.props;
    const errorMessage = getErrorMessage(error);

    return (
      <div className={style}>
        <SplashError
          title={isNetworkError(error) ? 'Network problem' : errorMessage}
          description={isNetworkError(error) ?  errorMessage : ''}
        />
      </div>
    );
  }
}

export default PageDataErrorMessage;
