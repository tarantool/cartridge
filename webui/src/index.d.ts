import type { History } from 'history';

declare global {
  interface Window {
    __tarantool_variables?: {
      cartridge_refresh_interval?: string;
      cartridge_stat_period?: string;
      cartridge_hide_all_rw?: boolean;
    };
    tarantool_enterprise_core: {
      history: History;
      notify: (props: {
        title: string;
        message: string;
        details?: string | null | undefined;
        type: 'success' | 'error';
        timeout: number;
      }) => void;
      components: {
        AppTitle: ({ title: string }) => JSX.Element;
      };
    };
  }
}

declare module '@tarantool.io/ui-kit' {
  export interface TextProps {
    onClick?: (event: MouseEvent<HTMLElement>) => void;
  }
}
