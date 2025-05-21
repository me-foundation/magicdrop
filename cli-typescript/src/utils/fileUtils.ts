import fs from 'fs';
import path from 'path';
import { COLLECTION_DIR } from './constants';
import { Collection } from './types';

export class Store<T> {
  public root: string;
  public storeDir: string;
  public data?: T;
  private readonly: boolean = false;

  constructor(
    dir: string,
    projectDirName: string,
    projectFileName?: string,
    readonly?: boolean,
    createDir: boolean = false,
  ) {
    const storeDir = path.join(dir, projectDirName);

    if (!fs.existsSync(storeDir) && createDir) {
      fs.mkdirSync(storeDir, { recursive: true });
    }

    this.storeDir = storeDir;
    this.root = path.join(storeDir, projectFileName || 'project.json');

    this.readonly = readonly ?? this.readonly;
  }

  get exists() {
    return fs.existsSync(this.root);
  }

  read(): T | undefined {
    try {
      this.data = JSON.parse(fs.readFileSync(this.root, 'utf-8'));
      return this.data;
    } catch (error: any) {
      throw new Error(error.message);
    }
  }

  write() {
    if (this.readonly) {
      throw new Error('Store is read only');
    }

    fs.writeFileSync(this.root, JSON.stringify(this.data, null, 2));
  }

  json(): T | undefined {
    return JSON.parse(fs.readFileSync(this.root, 'utf-8'));
  }
}

export const getProjectStore = (
  symbol: string,
  readonly = false,
  createDir = false,
) => {
  const store = new Store<Collection>(
    COLLECTION_DIR,
    path.join('projects', symbol),
    'project.json',
    readonly,
    createDir,
  );

  return store;
};
