import Joi from 'joi';

export const labelSchema = Joi.object({
  // orgUid - derived upon creation
  // warehouseProjectId - derived upon creation
  id: Joi.string().optional(),
  warehouseProjectId: Joi.string().optional(),
  label: Joi.string().required(),
  labelType: Joi.string().required(),
  creditingPeriodStartDate: Joi.date().required(),
  creditingPeriodEndDate: Joi.date()
    .min(Joi.ref('creditingPeriodStartDate'))
    .required(),
  validityPeriodStartDate: Joi.string().required(),
  validityPeriodEndDate: Joi.date()
    .min(Joi.ref('validityPeriodStartDate'))
    .required(),
  unitQuantity: Joi.number().integer().required(),
  labelLink: Joi.string().required(),
});
