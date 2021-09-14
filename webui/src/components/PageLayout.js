// @flow
import React from 'react';
import { PageLayout as PageLayoutKit } from '@tarantool.io/ui-kit';
import type { PageLayoutProps } from '@tarantool.io/ui-kit';

import DemoInfo from './DemoInfo';

export const PageLayout = (props: PageLayoutProps) => <PageLayoutKit {...props} aboveComponent={DemoInfo} />;
