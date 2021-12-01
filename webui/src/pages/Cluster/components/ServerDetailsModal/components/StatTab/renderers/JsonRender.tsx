/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useCallback, useState } from 'react';
import { css } from '@emotion/css';
// @ts-ignore
import { Button, CodeBlock, IconChevron } from '@tarantool.io/ui-kit';

const styles = {
  collapse: css`
    position: relative;
    align-self: stretch;
    max-width: 50%;
    margin-top: 6px;
    margin-bottom: 6px;

    input {
      display: none;
    }
  `,
  opened: css`
    padding-right: 0;
    white-space: pre;
    text-overflow: initial;
  `,
  collapseButton: css`
    position: absolute;
    top: 0;
    right: 0;
  `,
  contentWrap: css`
    width: 100%;
  `,
};

export interface JsonRenderProps {
  value: unknown;
}

export const JsonRenderIconUp = memo(({ className }: { className?: string }) => (
  <IconChevron className={className} direction="up" />
));

export const JsonRenderIconDown = memo(({ className }: { className?: string }) => (
  <IconChevron className={className} direction="down" />
));

export const JsonRender = ({ value }) => {
  const [opened, setOpened] = useState(false);

  const handleCollapseClick = useCallback(() => setOpened((value) => !value), []);

  return (
    <>
      <div className={styles.collapse}>
        <Button
          className={styles.collapseButton}
          onClick={handleCollapseClick}
          size="m"
          intent="plain"
          title="Expand"
          icon={opened ? JsonRenderIconUp : JsonRenderIconDown}
        />
      </div>
      {opened && (
        <div className={styles.contentWrap}>{!!value && <CodeBlock text={JSON.stringify(value, null, 2)} />}</div>
      )}
    </>
  );
};
