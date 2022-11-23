import React, { memo, useCallback, useState } from 'react';
import { Button } from '@tarantool.io/ui-kit';

import type { Suggestion } from 'src/models';

import ClusterSuggestionsModal from '../ClusterSuggestionsModal';

export interface SuggestionsButtonProps {
  suggestions?: Suggestion[];
}

const SuggestionsButton = ({ suggestions }: SuggestionsButtonProps) => {
  const [visible, setVisible] = useState(false);

  const handleButtonClick = useCallback(() => setVisible(true), []);
  const handleModalClose = useCallback(() => setVisible(false), []);

  if (typeof suggestions === 'undefined') {
    return null;
  }

  const length = suggestions.length;
  return (
    <>
      <Button
        className="meta-test__ClusterSuggestionsButton"
        disabled={length === 0}
        intent={length > 0 ? 'primary' : 'base'}
        onClick={handleButtonClick}
        text={`Suggestions: ${length}`}
        size="l"
      />
      <ClusterSuggestionsModal visible={visible} onClose={handleModalClose} suggestions={suggestions} />
    </>
  );
};

export default memo(SuggestionsButton);
