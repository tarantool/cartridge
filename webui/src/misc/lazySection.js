import React from 'react';

import { SectionLoadError } from 'src/components/SectionLoadError';

export const createLazySection = (dynamicImport, Fallback) => {
  return class LazySection extends React.Component {
    state = { hasError: false };

    static getDerivedStateFromError() {
      return { hasError: true };
    }

    resetError = () => this.setState({ hasError: false });

    render() {
      const { children, ...props } = this.props;

      const FallbackComponent = Fallback || SectionLoadError;

      return this.state.hasError ? (
        <FallbackComponent onClick={this.resetError} />
      ) : (
        React.createElement(React.lazy(dynamicImport), props, children)
      );
    }
  };
};
