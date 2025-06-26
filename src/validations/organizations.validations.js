import Joi from 'joi';

export const newOrganizationWithIconSchema = Joi.object({
  name: Joi.string().required(),
  prefix: Joi.string()
    .optional()
    .pattern(/^[a-zA-Z0-9]+$/)
    .max(20)
    .messages({
      'string.pattern.base':
        'Prefix must contain only alphanumeric characters (a-z, A-Z, 0-9)',
      'string.max': 'Prefix must be 20 characters or less',
    }),
  icon: Joi.string().required(),
});

export const editOrganizationSchema = Joi.object({
  name: Joi.string().optional(),
  prefix: Joi.string()
    .optional()
    .pattern(/^[a-zA-Z0-9]+$/)
    .max(20)
    .messages({
      'string.pattern.base':
        'Prefix must contain only alphanumeric characters (a-z, A-Z, 0-9)',
      'string.max': 'Prefix must be 20 characters or less',
    }),
});

export const importOrganizationSchema = Joi.object({
  orgUid: Joi.string().required(),
  isHome: Joi.bool().optional(),
});

export const unsubscribeOrganizationSchema = Joi.object({
  orgUid: Joi.string().required(),
});

export const subscribeOrganizationSchema = Joi.object({
  orgUid: Joi.string().required(),
});

export const resyncOrganizationSchema = Joi.object({
  orgUid: Joi.string().required(),
});

export const removeMirrorSchema = Joi.object({
  orgUid: Joi.string().required(),
  storeId: Joi.string().required(),
});

export const addMirrorSchema = Joi.object({
  storeId: Joi.string().required(),
  url: Joi.string().required(),
});

export const getMetaDataSchema = Joi.object({
  orgUid: Joi.string().required(),
});
