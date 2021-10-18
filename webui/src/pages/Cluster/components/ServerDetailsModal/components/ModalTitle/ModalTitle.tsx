import React, { memo } from 'react';
import { cx } from '@emotion/css';

import { Label } from 'src/components/Label';
import { LeaderLabel } from 'src/components/LeaderLabel';
import type { Maybe } from 'src/models';

import { styles } from './ModalTitle.styles';

export interface ModalTitleProps {
  isMaster: boolean;
  disabled?: Maybe<boolean>;
  alias?: Maybe<string>;
  uuid: string;
  status: string;
  ro?: boolean;
}

const ModalTitle = ({ isMaster, disabled, alias, uuid, status, ro }: ModalTitleProps) => {
  return (
    <>
      <span className={styles.headingWidthLimit}>{alias || uuid}</span>
      {isMaster && (
        <LeaderLabel className={styles.flag} state={status !== 'healthy' ? 'bad' : ro === false ? 'good' : 'warning'} />
      )}
      {disabled && <Label className={cx(styles.flag, { [styles.flagMarginBetween]: isMaster })}>Disabled</Label>}
    </>
  );
};

export default memo(ModalTitle);
