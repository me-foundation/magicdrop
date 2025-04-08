// @ts-check

import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import eslintPluginPrettier from 'eslint-plugin-prettier/recommended';

export default tseslint.config({
  files: ['**/*.ts'],
  extends: [
    eslint.configs.recommended,
    tseslint.configs.recommended,
    eslintPluginPrettier,
  ],
  rules: {
    'captialized-comments': ['error', 'always'],
    semi: ['error', 'always'],
    quotes: ['error', 'single'],
    'no-unused-vars': ['error', { argsIgnorePattern: '^_', vars: 'all' }],
  },
});
