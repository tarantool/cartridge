/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo } from 'react';
import { css } from '@emotion/css';
// @ts-ignore
import { SplashError } from '@tarantool.io/ui-kit';

import { getErrorMessage, isNetworkError } from 'src/api';

const style = css`
  display: flex;
  justify-content: center;
  height: calc(100vh - 145px);
`;

export interface PageDataErrorMessageProps {
  error: Error;
}

const PageDataErrorMessage = ({ error }: PageDataErrorMessageProps) => {
  const errorMessage = getErrorMessage(error);

  return (
    <div className={style}>
      <SplashError
        title={isNetworkError(error) ? 'Network problem' : errorMessage}
        description={isNetworkError(error) ? errorMessage : ''}
      />
    </div>
  );
};

export default memo(PageDataErrorMessage);
