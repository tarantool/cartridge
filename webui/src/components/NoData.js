import * as React from 'react';
import styled from 'react-emotion';
import { css } from 'emotion';
import { IconBoxNoData, Text } from '@tarantool.io/ui-kit';

const Container = styled.div`
  display: flex;
  flex-direction: column;
  align-items: center;
  top: 15%;
  left: 50%;
`

const textStyle = css`
  margin-top: 13px;
  font-style: normal;
  font-stretch: normal;
  color: rgba(0, 0, 0, 0.65);
`

type NoDataProps = {
    text?: string,
    className?: string,
};

function NoData({ text = 'No Data' }: NoDataProps) {
  return (
    <Container>
      <IconBoxNoData />
      <Text className={textStyle}>{text}</Text>
    </Container>
  )
};

export default NoData;
