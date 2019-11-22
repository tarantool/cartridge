// @flow
import type { State } from 'src/store/rootReducer';

export const isValueChanged = (state: State) => state.schema.value !== state.schema.savedValue;
