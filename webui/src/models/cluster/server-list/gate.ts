import { createGate } from 'effector-react';

export type FilterGateType = {
  rolesFilter: string;
  ratingFilter: string;
};

export const FilterGate = createGate<FilterGateType>({});
