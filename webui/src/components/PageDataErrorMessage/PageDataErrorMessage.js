import React from 'react';
import { css } from '@emotion/css';
import { getErrorMessage, isNetworkError } from 'src/api';
import {
  SplashErrorNetwork,
  SplashErrorFatal
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
        {isNetworkError(error)
          ?
          <SplashErrorNetwork
            description={errorMessage}
          />
          :
          <SplashErrorFatal
            title={errorMessage}
            description=''
          />
        }
      </div>
    );
  }
}

export default PageDataErrorMessage;
