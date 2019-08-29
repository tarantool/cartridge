import * as React from 'react';
import { css } from 'emotion';
import styled from 'react-emotion';

const Wrapper = styled.div`
  position: relative;
  background: inherit;
`

const duration = 1;
const ballCounter = 8;
const ballSize = 5;
const spinnerSize = 30;

const styles = {
  shade: css`
    min-width: 100%;
    min-height: 100%;
    width: 100%;
    height: 100%;
    position: absolute;
    background: inherit;
    opacity: 0.7;
    z-index: 9;
  `,
  spinnerContainer: css`
    display: flex;
    flex-direction: column;
    align-items: center;
    position: absolute;
    left: calc(50% - ${spinnerSize / 2}px);
    top: calc(50% - ${spinnerSize / 2}px);
    z-index: 10;
  `,
  spinner: css`
    & {
      position: relative;
      display: inline-block;
      left: ${spinnerSize / ballSize * 2}px;
      width: ${spinnerSize}px;
      height: ${spinnerSize}px;
    }
    & div {
      position: absolute;
      width: ${ballSize}px;
      height: ${ballSize}px;
      background: #f5222c;
      border-radius: 50%;
      animation: spin ${duration}s linear infinite;
    }
    @keyframes spin {
      0% {
        transform: scale(0.2);
      }
      25%, 75% {
        transform: scale(1);
      }
      50% {
        transform: scale(1.8);
      }
    }
  `,
  text: css`
    margin-top: 15px;
    font-size: 16px;
    font-weight: 600;
    font-style: normal;
    font-stretch: normal;
    line-height: 1.5;
    letter-spacing: 1.32px;
    color: #f5222d;
  `
}

type LoadingProps = {
    loading: boolean,
    children?: React.Node,
    text?: string,
};

function SpinnerLoader({ loading = false, children, text = 'LOADING' }) {
  return (
    <Wrapper>
      {loading && (
        <>
          <div className={styles.spinnerContainer}>
            <div className={styles.spinner}>
              {Array(ballCounter).fill().map((element, index) => {
                const left = (spinnerSize / 2) *  (Math.sin(((360 / ballCounter) * index + 1) * (Math.PI / 180)));
                const top = (spinnerSize / 2) * (Math.cos(((360 / ballCounter) * index + 1) * (Math.PI / 180)));
                const animationDelay = `${duration / ballCounter * (index + 1)}s`;

                return (
                  <div
                    style={{ left, top, animationDelay }}
                  />
                )
              })}
            </div>
            <div className={styles.text}>{text}</div>
          </div>
          <div className={styles.shade} />
        </>
      )}
      {children}
    </Wrapper>
  );
};

export default SpinnerLoader;
