export type MemoryUsageRatios = {
  arena_used_ratio: string;
  quota_used_ratio: string;
  items_used_ratio: string;
};

export type FragmentationLevel = 'high' | 'medium' | 'low';

const parsePercents = (percentsString: string): number =>
  //! Note: Possible floating point math inaccuracy,
  // it doesn't matter much
  parseFloat(percentsString.replace(/[%\s]+$/, '')) / 100;

export const calculateMemoryFragmentationLevel = (statistics: MemoryUsageRatios): FragmentationLevel => {
  const arena_used_ratio = parsePercents(statistics.arena_used_ratio);
  const quota_used_ratio = parsePercents(statistics.quota_used_ratio);
  const items_used_ratio = parsePercents(statistics.items_used_ratio);

  if (items_used_ratio > 0.9 && arena_used_ratio > 0.9 && quota_used_ratio > 0.9) {
    return 'high';
  } else if (items_used_ratio > 0.6 && arena_used_ratio > 0.9 && quota_used_ratio > 0.9) {
    return 'medium';
  }
  return 'low';
};
