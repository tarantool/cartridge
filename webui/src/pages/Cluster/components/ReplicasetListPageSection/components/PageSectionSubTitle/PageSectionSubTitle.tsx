import React, { memo } from 'react';

export interface PageSectionSubTitleProps {
  filter: string;
  length: number;
  configured: number;
  total: number;
  unhealthy: number;
}

const PageSectionSubTitle = ({ filter, length, total, unhealthy, configured }: PageSectionSubTitleProps) => {
  return (
    <>
      {filter ? (
        <>
          <b>
            {length}
            {` selected | `}
          </b>
        </>
      ) : null}
      <b>{total}</b>
      {` total | `}
      <b>{unhealthy}</b>
      {` unhealthy | `}
      <b>{configured}</b>
      {` server${configured === 1 ? '' : 's'}`}
    </>
  );
};

export default memo(PageSectionSubTitle);
