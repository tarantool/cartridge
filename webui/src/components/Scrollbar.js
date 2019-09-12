import * as React from 'react';
import ReactScroll from 'react-scrollbars-custom';
import styled from 'react-emotion';

const ScrollWrapper = styled.div`
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

const wrapperProps = {
  renderer: props => {
    const { elementRef, style, ...rest } = props;

    return <div {...rest} style={{ ...style, right: 0 }} ref={elementRef} />;
  }
}

const scrollerProps = {
  renderer: props => {
    const { elementRef, style, ...rest } = props;

    return <div {...rest} style={{ ...style, marginRight: -20, paddingRight: 20 }} ref={elementRef} />;
  }
}

type ScrollbarProps = {
  children?: React.Node,
  className?: string,
  track?: string,
  thumb?: string
}

function Scrollbar({ children, className, track, thumb }: ScrollbarProps) {
  return (
    <ScrollWrapper className={className}>
      <ReactScroll
        track={track}
        thumb={thumb}
        wrapperProps={wrapperProps}
        scrollerProps={scrollerProps}
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
