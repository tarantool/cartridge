import React from 'react';
import { useEvent, useStore } from 'effector-react';
import { Button } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import ClusterSuggestionsModal from '../ClusterSuggestionsModal';

const SuggestionsButton = () => {
  const modal = useStore(cluster.serverSuggestions.$serverSuggestionsModal);
  const handleClick = useEvent(cluster.serverSuggestions.serverSuggestionsModalOpenEvent);
  return (
    <>
      <Button
        className="meta-test__ClusterSuggestionsButton"
        intent="base"
        onClick={handleClick}
        text="Suggestions"
        size="l"
        loading={modal.pending}
      />
      <ClusterSuggestionsModal />
    </>
  );
};

export default SuggestionsButton;
