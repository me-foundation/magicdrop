import dotenv from 'dotenv';
import { mainMenu } from './cmds/mainMenu';
import path from 'path';

// load local env
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// load cmd root env
dotenv.config();

mainMenu();
