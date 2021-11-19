/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo } from 'react';

export interface PageSectionSubTitleProps {
  count: number;
}

const PageSectionSubTitle = ({ count }: PageSectionSubTitleProps) => {
  return (
    <>
      <b>{count}</b>
      {` unconfigured server${count === 0 ? '' : 's'}`}
    </>
  );
};

export default memo(PageSectionSubTitle);
