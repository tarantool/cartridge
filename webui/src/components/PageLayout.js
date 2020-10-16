// @flow
import * as React from 'react';
import {
  PageLayout as PageLayoutKit,
  type PageLayoutProps
} from '@tarantool.io/ui-kit';
import DemoInfo from './DemoInfo';

export const PageLayout = (props: PageLayoutProps) => (
  <PageLayoutKit
    {...props}
    aboveComponent={DemoInfo}
  />
);
