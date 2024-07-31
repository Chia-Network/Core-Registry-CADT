import { CONFIG } from '../user-config.js';
import { getDataModelVersion } from '../utils/helpers.js';
import { getChiaRoot } from 'chia-root-resolver';
import { APP_DATA_FOLDER_NAME } from '../constants.js';

const chiaRoot = getChiaRoot();

const persistanceFolder = `${chiaRoot}/${APP_DATA_FOLDER_NAME}/cadt/${getDataModelVersion()}`;

export default {
  local: {
    dialect: 'sqlite',
    storage: `${persistanceFolder}/data.sqlite3`,
    logging: false,
    dialectOptions: {
      busyTimeout: 10000,
    },
  },
  simulator: {
    dialect: 'sqlite',
    storage: `${persistanceFolder}/simulator.sqlite3`,
    logging: false,
  },
  test: {
    dialect: 'sqlite',
    storage: './test.sqlite3',
    logging: false,
  },
  mirrorTest: {
    dialect: 'sqlite',
    storage: './testMirror.sqlite3',
    logging: false,
  },
  mirror: {
    username: CONFIG().CADT.MIRROR_DB.DB_USERNAME || '',
    password: CONFIG().CADT.MIRROR_DB.DB_PASSWORD || '',
    database: CONFIG().CADT.MIRROR_DB.DB_NAME || '',
    host: CONFIG().CADT.MIRROR_DB.DB_HOST || '',
    dialect: 'mysql',
    logging: false,
  },
};
