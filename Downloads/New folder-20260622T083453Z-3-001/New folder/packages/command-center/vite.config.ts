import path from 'node:path';
import { fileURLToPath } from 'node:url';
import basicSsl from '@vitejs/plugin-basic-ssl';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(rootDir, '../..');

/** Single copy of Wallet Standard + Mysten SDK (prevents dApp.connect / split registry bugs). */
const MYSTEN_DEDUPE = [
  'react',
  'react-dom',
  '@mysten/sui',
  '@mysten/dapp-kit',
  '@mysten/wallet-standard',
  '@mysten/slush-wallet',
  '@wallet-standard/core',
  '@wallet-standard/app',
  '@wallet-standard/base',
  '@wallet-standard/features',
  '@wallet-standard/wallet',
];

/** HTTPS dev: npm run dev:https → vite --mode https --port 5174 */
function isHttpsDevMode(mode: string): boolean {
  return mode === 'https' || process.env.VITE_HTTPS_DEV === '1';
}

export default defineConfig(({ command, mode }) => {
  const httpsDev = isHttpsDevMode(mode);
  const devPort = httpsDev ? 5174 : 5173;

  return {
  plugins: [
    react(),
    ...(httpsDev && (command === 'serve' || command === 'preview') ? [basicSsl()] : []),
  ],
  resolve: {
    dedupe: MYSTEN_DEDUPE,
    alias: {
      deepmerge: path.resolve(rootDir, 'src/shims/deepmerge.ts'),
      '@mysten/sui': path.resolve(workspaceRoot, 'node_modules/@mysten/sui'),
      '@mysten/wallet-standard': path.resolve(workspaceRoot, 'node_modules/@mysten/wallet-standard'),
      '@wallet-standard/app': path.resolve(workspaceRoot, 'node_modules/@wallet-standard/app'),
      '@wallet-standard/core': path.resolve(workspaceRoot, 'node_modules/@wallet-standard/core'),
    },
  },
  optimizeDeps: {
    include: ['deepmerge', '@vanilla-extract/css'],
    // Never pre-bundle Mysten/wallet-standard — duplicates getWallets() singletons.
    exclude: [
      '@mysten/dapp-kit',
      '@mysten/wallet-standard',
      '@mysten/slush-wallet',
      '@wallet-standard/app',
      '@wallet-standard/core',
    ],
  },
  build: {
    commonjsOptions: {
      include: [/deepmerge/, /node_modules/],
    },
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('bootstrapWalletRegistry')) return 'wallets';
          if (id.includes('/src/wallets/')) return 'wallets';
          if (
            id.includes('node_modules/@mysten/dapp-kit')
            || id.includes('node_modules/@mysten/wallet-standard')
            || id.includes('node_modules/@mysten/slush-wallet')
            || id.includes('node_modules/@wallet-standard/')
          ) {
            return 'wallets';
          }
        },
      },
      input: {
        main: path.resolve(rootDir, 'index.html'),
        'wallet-test': path.resolve(rootDir, 'wallet-test.html'),
        'wallet-raw': path.resolve(rootDir, 'wallet-raw.html'),
        'wallet-slush-accounts': path.resolve(rootDir, 'wallet-slush-accounts.html'),
        'wallet-slush-inspector': path.resolve(rootDir, 'wallet-slush-inspector.html'),
        'wallet-navi-pattern': path.resolve(rootDir, 'wallet-navi-pattern.html'),
        'wallet-auth-audit': path.resolve(rootDir, 'wallet-auth-audit.html'),
      },
    },
  },
  server: {
    port: devPort,
    host: true,
    strictPort: true,
    fs: {
      allow: [rootDir, workspaceRoot],
    },
    proxy: {
      '/api/coingecko': {
        target: 'https://api.coingecko.com',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/coingecko/, '/api/v3'),
      },
      '/api/coingecko-pro': {
        target: 'https://pro-api.coingecko.com',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/coingecko-pro/, '/api/v3'),
      },
      '/api/deepbook': {
        target: 'https://deepbook-indexer.mainnet.mystenlabs.com',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/deepbook/, ''),
      },
      '/api/defillama': {
        target: 'https://yields.llama.fi',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/defillama/, ''),
      },
    },
  },
  preview: {
    port: devPort,
    strictPort: true,
    host: true,
    proxy: {
      '/api/coingecko': {
        target: 'https://api.coingecko.com',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/coingecko/, '/api/v3'),
      },
      '/api/coingecko-pro': {
        target: 'https://pro-api.coingecko.com',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/coingecko-pro/, '/api/v3'),
      },
      '/api/deepbook': {
        target: 'https://deepbook-indexer.mainnet.mystenlabs.com',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/deepbook/, ''),
      },
      '/api/defillama': {
        target: 'https://yields.llama.fi',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/defillama/, ''),
      },
    },
  },
};
});
