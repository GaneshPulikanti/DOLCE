import React from 'react';

export class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('🔴 [ErrorBoundary] Caught React UI Error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="w-full min-h-screen bg-[#050505] text-white flex flex-col items-center justify-center p-6 text-center font-['Inter']">
          <div className="w-16 h-16 rounded-2xl bg-red-500/10 border border-red-500/20 text-red-400 flex items-center justify-center mb-4 text-2xl">
            ⚠️
          </div>
          <h2 className="text-xl font-bold text-white mb-2">Something went wrong</h2>
          <p className="text-xs text-white/60 max-w-md mb-6 leading-relaxed">
            {this.state.error?.message || 'An unexpected rendering error occurred.'}
          </p>
          <button
            onClick={() => {
              this.setState({ hasError: false, error: null });
              window.location.reload();
            }}
            className="px-6 py-2.5 rounded-full bg-white text-black text-xs font-bold hover:bg-white/90 transition-all shadow-lg"
          >
            Reload Application
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
