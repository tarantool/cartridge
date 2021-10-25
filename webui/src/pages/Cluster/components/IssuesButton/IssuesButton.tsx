/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useCallback, useState } from 'react';
// @ts-ignore
import { Button, IconCancel } from '@tarantool.io/ui-kit';

import type { ServerListServerClusterIssue } from 'src/models';

import ClusterIssuesModal from '../ClusterIssuesModal';
import IconOkContrast from './components/IconOkContrast';

export interface IssuesButtonProps {
  issues?: ServerListServerClusterIssue[];
}

const IssuesButton = ({ issues }: IssuesButtonProps) => {
  const [visible, setVisible] = useState(false);

  const handleButtonClick = useCallback(() => setVisible(true), []);
  const handleModalClose = useCallback(() => setVisible(false), []);

  if (typeof issues === 'undefined') {
    return null;
  }

  const length = issues.length;
  return (
    <>
      <Button
        className="meta-test__ClusterIssuesButton"
        disabled={length === 0}
        intent={length > 0 ? 'primary' : 'base'}
        icon={length > 0 ? IconCancel : IconOkContrast}
        onClick={handleButtonClick}
        text={`Issues: ${length}`}
        size="l"
      />
      <ClusterIssuesModal visible={visible} onClose={handleModalClose} issues={issues} />
    </>
  );
};

export default memo(IssuesButton);
