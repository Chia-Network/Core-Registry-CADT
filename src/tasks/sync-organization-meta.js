import { SimpleIntervalJob, Task } from 'toad-scheduler';
import { Organization } from '../models';
import { CONFIG } from '../user-config';
import {
  assertDataLayerAvailable,
  assertWalletIsSynced,
} from '../utils/data-assertions';
import { logger } from '../logger.js';

import dotenv from 'dotenv';

dotenv.config();

const task = new Task('sync-organization-meta', async () => {
  try {
    await assertDataLayerAvailable();
    await assertWalletIsSynced();

    if (!CONFIG().CADT.USE_SIMULATOR) {
      logger.task('Syncing subscribed organizations');
      await Organization.syncOrganizationMeta();
    }
  } catch (error) {
    logger.error(
      `Retrying in ${
        CONFIG().CADT?.TASKS?.ORGANIZATION_META_SYNC_TASK_INTERVAL || 300
      } seconds`,
      error,
    );
  }
});

const job = new SimpleIntervalJob(
  {
    seconds: CONFIG().CADT?.TASKS?.ORGANIZATION_META_SYNC_TASK_INTERVAL || 300,
    runImmediately: true,
  },
  task,
  { id: 'sync-organization-meta', preventOverrun: true },
);

export default job;
