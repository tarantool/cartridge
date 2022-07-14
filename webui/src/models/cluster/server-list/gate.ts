import { createGate } from 'effector-react';

export type FilterGateType = {
  rolesFilter: string;
  ratingFilter: string;
  // Record: () => void;
  // Read: () => void;
};

export const FilterGate = createGate<FilterGateType>({});
