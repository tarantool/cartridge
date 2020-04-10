import {
  calculateMemoryFragmentationLevel
} from './memoryStatistics';


describe('Memory fragmentation level by statistics', () => {

  const makeStat = ([arena_used_ratio, quota_used_ratio, items_used_ratio]) => (
    {
      arena_used_ratio,
      quota_used_ratio,
      items_used_ratio
    }
  );

  const testCases = [
    {
      describeLabel: 'High level cases',
      expectedValue: 'high',
      cases: [
        {
          itLabel: '91-91-91 %',
          values: ['91%', '91%', '91%']
        },
        {
          itLabel: 'should understand fractions: 90.00001 - 90.0001 - 90.001 %',
          values: ['90.00001%', '90.0001%', '90.001%']
        },
        {
          itLabel: '100-100-100 %',
          values: ['100%', '100%', '100%']
        },
      ]
    },
    {
      describeLabel: 'Medium level cases',
      expectedValue: 'medium',
      cases: [
        {
          itLabel: '91-91-61 % (bottom edge)',
          values: ['91%', '91%', '61%']
        },

      ]
    },
    {
      describeLabel: 'Low level cases',
      expectedValue: 'low',
      cases: [
        {
          itLabel: '90-90-60% (top edge)',
          values: ['90%', '90%', '60%']
        },
        {
          itLabel: '0-0-0% (bottom edge)',
          values: ['0%', '0%', '0%']
        },
        {
          itLabel: 'fragmentation is "low" if arena_used_ratio < 90%',
          values: ['80%', '100%', '100%']
        },
      ]
    },
  ];

  testCases.forEach(({ describeLabel, expectedValue, cases }) => {
    describe(describeLabel, () => {
      cases.forEach(({ itLabel, values }) => {
        it(itLabel, () => {
          const fragmentationLevel = calculateMemoryFragmentationLevel(
            makeStat(values)
          );
          expect(fragmentationLevel).toBe(expectedValue);
        });
      });
    });
  });

});
