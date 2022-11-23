import { combine } from 'effector';

import { app } from 'src/models';

import type { GetCompressionClusterCompressionCompressionInfo, Suggestion } from './types';

export type STATE = 'initial' | 'pending' | 'error' | 'content';

// events
export const serverSuggestionsModalOpenEvent = app.domain.createEvent('server suggestions modal open event');
export const serverSuggestionsModalCloseEvent = app.domain.createEvent('server suggestions modal close event');
export const serverSuggestionsEvent = app.domain.createEvent('server suggestions event');

// stores
export const $serverSuggestionsModalVisible = app.domain.createStore(false);
export const $serverSuggestionsModalError = app.domain.createStore<string | null>(null);
export const $serverSuggestions = app.domain.createStore<GetCompressionClusterCompressionCompressionInfo | null>(null);

// effects
export const serverSuggestionsFx = app.domain.createEffect<void, GetCompressionClusterCompressionCompressionInfo>(
  'suggestions'
);

// computed
export const $suggestions = combine($serverSuggestions, (info) => {
  if (!info) {
    return null;
  }

  return info.reduce((acc: Suggestion[], item) => {
    item.instance_compression_info.forEach((info) => {
      if (info.fields_be_compressed.length > 0) {
        acc.push({
          type: 'compression',
          meta: {
            instanceId: item.instance_id,
            spaceName: info.space_name,
            fields: info.fields_be_compressed.map(({ field_name, compression_percentage }) => ({
              name: field_name,
              compressionPercentage: compression_percentage,
            })),
          },
        });
      }
    });

    return acc;
  }, []);
});

export const $serverSuggestionsModal = combine({
  data: $suggestions,
  visible: $serverSuggestionsModalVisible,
  error: $serverSuggestionsModalError,
  pending: serverSuggestionsFx.pending,
  state: combine(
    serverSuggestionsFx.pending,
    $serverSuggestionsModalError,
    $suggestions,
    (pending, error, data): STATE => {
      switch (true) {
        default:
          return 'initial';
        case pending:
          return 'pending';
        case Boolean(error):
          return 'error';
        case Boolean(data):
          return 'content';
      }
    }
  ),
});
