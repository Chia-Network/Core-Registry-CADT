'use strict';

import Sequelize from 'sequelize';
const { Model } = Sequelize;

import { sequelizeMirror, safeMirrorDbHandler } from '../../database';
import ModelTypes from './statistics.modeltypes.cjs';

class StatisticsMirror extends Model {}

safeMirrorDbHandler(() => {
  StatisticsMirror.init(ModelTypes, {
    sequelize: sequelizeMirror,
    modelName: 'statistics',
    freezeTableName: true,
    timezone: '+00:00',
    define: {
      charset: 'utf8mb4',
      collate: 'utf8mb4_general_ci',
    },
    dialectOptions: {
      charset: 'utf8mb4',
      dateStrings: true,
      typeCast: true,
    },
  });
});

export { StatisticsMirror };
