// @flow
import { combine, createEvent, createStore } from 'effector';

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export const createField = (name: string, initialValue?: string | null = '', disabled?: boolean = false) => {
  const change = createEvent<SyntheticInputEvent<HTMLInputElement>>(`change ${name} field`);
  const blur = createEvent<SyntheticInputEvent<HTMLInputElement>>(`blur ${name} field`);
  const touch = createEvent<void>(`touch ${name} field`);
  const reset = createEvent<void>(`reset ${name} field`);

  const $value = createStore<string | null>(initialValue);
  // const $error = createStore<string | null>(null);
  const $touched = createStore<boolean>(false);
  const $visited = createStore<boolean>(false);

  const $field = combine({
    value: $value,
    touched: $touched,
    visited: $visited,
  });

  $value.on(change, (_, e: SyntheticInputEvent<HTMLInputElement>) => e.target.value).reset(reset);

  $touched
    .on(change, () => true)
    .on(touch, () => true)
    .reset(reset);

  $visited.on(blur, () => true).reset(reset);

  // $error
  //   .reset(reset);

  return {
    name,
    initialValue,
    change,
    blur,
    touch,
    reset,
    $field,
    $value,
    $touched,
    // active: false,
    // $error
  };
};
