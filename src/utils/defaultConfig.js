export const defaultConfig = {
  GENERAL: {
    LOG_LEVEL: 'info',
  },
  CHIA: {
    DATALAYER_HOST: 'https://localhost:8562',
    WALLET_HOST: 'https://localhost:9256',
    CERTIFICATE_FOLDER_PATH: null,
    ALLOW_SELF_SIGNED_CERTIFICATES: true,
    DATALAYER_FILE_SERVER_URL: null,
    DEFAULT_FEE: 300000000,
    DEFAULT_COIN_AMOUNT: 300000000,
  },
  CADT: {
    PORT: 31310,
    API_KEY: null,
    BIND_ADDRESS: '127.0.0.1',
    USE_SIMULATOR: false,
    READ_ONLY: false,
    USE_DEVELOPMENT_MODE: false,
    IS_GOVERNANCE_BODY: false,
    AUTO_SUBSCRIBE_FILESTORE: false,
    AUTO_MIRROR_EXTERNAL_STORES: true,
    TASKS: {
      GOVERNANCE_SYNC_TASK_INTERVAL: 86400,
      ORGANIZATION_META_SYNC_TASK_INTERVAL: 300,
      PICKLIST_SYNC_TASK_INTERVAL: 30,
      MIRROR_CHECK_TASK_INTERVAL: 300,
      VALIDATE_ORGANIZATION_TABLE_TASK_INTERVAL: 1800,
    },
    /**
     * limits to prevent loop bound DOS attack
     */
    REQUEST_CONTENT_LIMITS: {
      STAGING: {
        EDIT_DATA_LEN: 200,
      },
      UNITS: {
        INCLUDE_COLUMNS_LEN: 200,
        MARKETPLACE_IDENTIFIERS_LEN: 200,
      },
      PROJECTS: {
        INCLUDE_COLUMNS_LEN: 200,
        PROJECT_IDS_LEN: 200,
      },
    },
    MIRROR_DB: {
      DB_USERNAME: null,
      DB_PASSWORD: null,
      DB_NAME: null,
      DB_HOST: null,
    },
    GOVERNANCE: {
      GOVERNANCE_BODY_ID:
        '23f6498e015ebcd7190c97df30c032de8deb5c8934fc1caa928bc310e2b8a57e',
    },
  },
};
