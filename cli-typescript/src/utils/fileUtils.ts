import fs from 'fs';
import path from 'path';
import {
  COLLECTION_DIR,
  DEFAULT_COLLECTION_DIR,
  TOKEN_STANDARD,
} from './constants';
import { Collection } from './types';

export class Store {
  public root: string;
  public data?: Collection;
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

    this.root = path.join(storeDir, projectFileName || 'project.json');

    this.readonly = readonly ?? this.readonly;
  }

  get exists() {
    return fs.existsSync(this.root);
  }

  read(): Collection | undefined {
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

  json(): Collection | undefined {
    return JSON.parse(fs.readFileSync(this.root, 'utf-8'));
  }
}

export const getProjectStore = (
  collection: string,
  readonly = false,
  createDir = false,
) => {
  const store = new Store(
    COLLECTION_DIR,
    path.join('projects', collection),
    'project.json',
    readonly,
    createDir,
  );

  return store;
};

export const getTemplateStore = (tokenStandard: TOKEN_STANDARD) => {
  const store = new Store(
    DEFAULT_COLLECTION_DIR,
    'template',
    `${tokenStandard.toLowerCase()}_template.json`,
    true,
  );

  store.read();

  return store;
};
