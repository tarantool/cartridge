// @flow
import { css } from '@emotion/css';
import { colors } from '@tarantool.io/ui-kit';

export const styles = {
  row: css`
    position: relative;
    display: flex;
    flex-wrap: nowrap;
    justify-content: flex-start;
    align-items: center;
    height: 38px;
    padding-right: 11px;
    user-select: none;
    cursor: pointer;

    &:hover {
      background-color: ${colors.dark10};
    }

    .FileTreeElement__btns {
      display: none;
    }

    &:hover > .FileTreeElement__btns {
      display: flex;
    }
  `,
  newRow: css`
    padding-right: 8px;
  `,
  active: css`
    background-color: ${colors.dark10};
  `,
  fileName: css`
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  iconChevron: css`
    margin: 4px;
    fill: ${colors.dark65};
  `,
  iconChevronHidden: css`
    visibility: hidden;
  `,
  fileIcon: css`
    margin: 4px;
  `,
  buttonsPanel: css`
    position: absolute;
    top: calc(50% - 12px);
    right: 8px;
    display: flex;
    flex-wrap: nowrap;
  `,
  fileActionBtn: css`
    margin-left: 4px;
  `,
};
