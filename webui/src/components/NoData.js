import * as React from 'react';
import { css } from 'emotion';
import styled from 'react-emotion';
import { IconBoxNoData } from 'src/components/Icon/icons/IconBoxNoData';

const Container = styled.div`
  display: flex;
  flex-direction: column;
  align-items: center;
  top: 15%;
  left: 50%;
`

const Text = styled.span`
  margin-top: 13px;
  font-size: 14px;
  font-weight: normal;
  font-style: normal;
  font-stretch: normal;
  line-height: 1.57;
  letter-spacing: 0.28px;
  color: rgba(0, 0, 0, 0.65);
`

type NoDataProps = {
    text?: string,
    className?: string,
};

function NoData({ text = 'No Data', className }: NoDataProps) {
  return (
    <Container>
      <IconBoxNoData />
      <Text>{text}</Text>
    </Container>
  )
};

export default NoData;