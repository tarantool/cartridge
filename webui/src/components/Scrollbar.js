import * as React from 'react';
import ReactScroll from 'react-scrollbars-custom';
import { css } from 'emotion';
import styled from 'react-emotion';

const ScrollWrapper = styled.div`
  width: 100%;
  height: 100%;
`

const Track = styled.div`
  width: 4px !important;
  background: ${({ track }) => track || '#e8e8e8'} !important;
  border-radius: 7px !important;
`

const Thumb = styled.div`
  background: ${({ thumb }) => thumb || '#cf1322'} !important;
`

const trackYProps = {
  renderer: props => {
    const { elementRef, style, ...rest } = props;

    return <Track {...rest} style={style} innerRef={elementRef} />;
  }
}

const thumbYProps = {
  renderer: props => {
    const { elementRef, style, ...rest } = props;

    return <Thumb {...rest} style={style} innerRef={elementRef} />;
  }
}

type ScrollbarProps = {
  children?: React.Node,
  track?: string,
  thumb?: string
}

function Scrollbar({ children, track, thumb }: ScrollbarProps) {
  return (
    <ScrollWrapper>
      <ReactScroll
        track={track}
        thumb={thumb}
        trackYProps={{ ...trackYProps, track }}
        thumbYProps={{ ...thumbYProps, thumb }}
        style={{ width: '100%', height: '100%' }}
      >
        {children}
      </ReactScroll>
    </ScrollWrapper>
  )
}

export default Scrollbar;