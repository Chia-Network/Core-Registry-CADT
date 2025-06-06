import { SimpleIntervalJob, Task } from 'toad-scheduler';
import { Meta, Organization } from '../models';
import {
  assertDataLayerAvailable,
  assertWalletIsSynced,
} from '../utils/data-assertions';
import { logger } from '../logger';
import { CONFIG } from '../user-config';
import { getMirrorUrl } from '../utils/datalayer-utils';
import dotenv from 'dotenv';

dotenv.config();
// This task checks if there are any mirrors that have not been properly mirrored and then mirrors them if not

const task = new Task('mirror-check', async () => {
  try {
    logger.trace('Mirror processing: Mirror check task invoked');
    await assertDataLayerAvailable();
    logger.trace('Mirror processing: Data layer is available');
    await assertWalletIsSynced();
    logger.trace('Mirror processing: Wallet is synced');

    // Default AUTO_MIRROR_EXTERNAL_STORES to true if it is null or undefined
    const shouldMirror = CONFIG().CADT.AUTO_MIRROR_EXTERNAL_STORES ?? true;
    logger.trace(`Mirror processing: Should mirror: ${shouldMirror}`);
    logger.trace(
      `Mirror processing: Use simulator: ${CONFIG().CADT.USE_SIMULATOR}`,
    );

    if (!CONFIG().CADT.USE_SIMULATOR && shouldMirror) {
      logger.trace('Mirror processing: Running mirror check');
      await runMirrorCheck();
    } else {
      logger.trace(
        'Mirror processing: Skipping mirror check due to configuration',
      );
    }
  } catch (error) {
    logger.error(
      `Mirror processing: Retrying in ${
        CONFIG().CADT.TASKS.MIRROR_CHECK_TASK_INTERVAL || 300
      } seconds`,
      error,
    );
  }
});

const job = new SimpleIntervalJob(
  {
    seconds: CONFIG().CADT.TASKS?.MIRROR_CHECK_TASK_INTERVAL || 300,
    runImmediately: true,
  },
  task,
  { id: 'mirror-check', preventOverrun: true },
);

const runMirrorCheck = async () => {
  logger.trace('Mirror processing: Starting runMirrorCheck');
  const mirrorUrl = await getMirrorUrl();
  logger.trace(`Mirror processing: Got mirror URL: ${mirrorUrl}`);

  if (!mirrorUrl) {
    logger.info(
      'Mirror processing: DATALAYER_FILE_SERVER_URL not set, skipping mirror announcements',
    );
    return;
  }

  // get governance info if governance node
  const governanceOrgUidResult = await Meta.findOne({
    where: { metaKey: 'governanceBodyId' },
    attributes: ['metaValue'],
    raw: true,
  });
  logger.trace(
    `Mirror processing: Found governance org UID: ${governanceOrgUidResult?.metaValue}`,
  );

  const governanceRegistryIdResult = await Meta.findOne({
    where: { metaKey: 'mainGoveranceBodyId' },
    attributes: ['metaValue'],
    raw: true,
  });
  logger.trace(
    `Mirror processing: Found governance registry ID: ${governanceRegistryIdResult?.metaValue}`,
  );

  if (
    governanceOrgUidResult?.metaValue &&
    governanceRegistryIdResult?.metaValue
  ) {
    logger.trace('Mirror processing: Adding governance mirrors');
    // add governance mirrors if instance is governance
    // There is logic within the addMirror function to check if the mirror already exists
    await Organization.addMirror(
      governanceOrgUidResult?.metaValue,
      mirrorUrl,
      true,
    );
    logger.trace('Mirror processing: Added governance org mirror');
    await Organization.addMirror(
      governanceRegistryIdResult?.metaValue,
      mirrorUrl,
      true,
    );
    logger.trace('Mirror processing: Added governance registry mirror');
  }

  const organizations = await Organization.getOrgsMap();
  const orgCount = Object.keys(organizations).length;
  logger.trace(`Mirror processing: Found ${orgCount} organizations`);

  for (const [orgUid, orgData] of Object.entries(organizations)) {
    if (orgData.subscribed) {
      logger.trace(
        `Mirror processing: Processing subscribed organization: ${orgData.name} (${orgUid})`,
      );
      await Organization.addMirror(orgUid, mirrorUrl, true);
      logger.trace(
        `Mirror processing: Added org UID mirror for ${orgData.name} (${orgUid})`,
      );
      await Organization.addMirror(
        orgData.dataModelVersionStoreId,
        mirrorUrl,
        true,
      );
      logger.trace(
        `Mirror processing: Added data model version store mirror for ${orgData.name} (${orgUid})`,
      );
      await Organization.addMirror(orgData.registryId, mirrorUrl, true);
      logger.trace(
        `Mirror processing: Added registry ID mirror for ${orgData.name} (${orgUid})`,
      );
    }
  }
  logger.trace('Mirror processing: Completed runMirrorCheck');
};

export default job;
