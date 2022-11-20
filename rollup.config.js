import typescript from '@rollup/plugin-typescript';
import json from '@rollup/plugin-json';
import pkg from './package.json';

export default {
  input: 'src/index.ts',
  output: [
    { file: pkg.main, format: 'cjs', sourcemap: true },
    { file: pkg.module, format: 'es', sourcemap: true },
  ],
  plugins: [
    // copy({
    //   targets: [{ src: 'src/abis/**/*', dest: 'dist/abis' }],
    // }),
    json(),
    typescript({
      tsconfig: './tsconfig.build.json',
      outputToFilesystem: true,
    }),
  ],
};
