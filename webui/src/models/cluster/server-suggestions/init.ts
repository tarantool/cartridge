import { forward } from 'effector';

import graphql from 'src/api/graphql';
import { app } from 'src/models';
import { getClusterCompressionQuery } from 'src/store/request/queries.graphql';

import { clusterPageCloseEvent } from '../page';
import * as selectors from './selectors';
import {
  $serverSuggestions,
  $serverSuggestionsModalError,
  $serverSuggestionsModalVisible,
  serverSuggestionsEvent,
  serverSuggestionsFx,
  serverSuggestionsModalCloseEvent,
  serverSuggestionsModalOpenEvent,
} from '.';

const { trueL, passResultOnEvent, passErrorMessageOnEvent } = app.utils;

forward({
  from: serverSuggestionsEvent,
  to: serverSuggestionsFx,
});

// stores
$serverSuggestionsModalVisible
  .on(serverSuggestionsModalOpenEvent, trueL)
  .reset(serverSuggestionsModalCloseEvent)
  .reset(clusterPageCloseEvent);

$serverSuggestions
  .on(serverSuggestionsFx.doneData, passResultOnEvent)
  .reset(serverSuggestionsFx)
  .reset(serverSuggestionsModalOpenEvent)
  .reset(serverSuggestionsModalCloseEvent)
  .reset(clusterPageCloseEvent);

$serverSuggestionsModalError
  .on(serverSuggestionsFx.failData, passErrorMessageOnEvent)
  .reset(serverSuggestionsFx)
  .reset(serverSuggestionsModalOpenEvent)
  .reset(serverSuggestionsModalCloseEvent)
  .reset(clusterPageCloseEvent);

// effects
serverSuggestionsFx.use(() => graphql.fetch(getClusterCompressionQuery).then(selectors.clusterCompressionInfo));
