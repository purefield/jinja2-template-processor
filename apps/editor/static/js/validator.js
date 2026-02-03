/**
 * Clusterfile Editor v2.0 - Validation Module
 *
 * AJV-based JSON Schema validation with custom formats.
 */
(function() {
'use strict';

let ajvInstance = null;
let validateFn = null;

/**
 * Custom format validators
 */
const customFormats = {
  ipv4: {
    validate: (value) => {
      if (typeof value !== 'string') return false;
      const parts = value.split('.');
      if (parts.length !== 4) return false;
      return parts.every(part => {
        const num = parseInt(part, 10);
        return !isNaN(num) && num >= 0 && num <= 255 && String(num) === part;
      });
    }
  },

  cidr: {
    validate: (value) => {
      if (typeof value !== 'string') return false;
      const parts = value.split('/');
      if (parts.length !== 2) return false;

      // Validate IP part
      const ipParts = parts[0].split('.');
      if (ipParts.length !== 4) return false;
      const ipValid = ipParts.every(part => {
        const num = parseInt(part, 10);
        return !isNaN(num) && num >= 0 && num <= 255 && String(num) === part;
      });
      if (!ipValid) return false;

      // Validate prefix
      const prefix = parseInt(parts[1], 10);
      return !isNaN(prefix) && prefix >= 0 && prefix <= 32;
    }
  },

  uri: {
    validate: (value) => {
      if (typeof value !== 'string') return false;
      try {
        new URL(value);
        return true;
      } catch {
        return false;
      }
    }
  },

  fqdn: {
    validate: (value) => {
      if (typeof value !== 'string') return false;
      // FQDN pattern: labels separated by dots, each label alphanumeric with hyphens
      const pattern = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
      return pattern.test(value) && value.length <= 253;
    }
  },

  mac: {
    validate: (value) => {
      if (typeof value !== 'string') return false;
      // MAC address pattern: XX:XX:XX:XX:XX:XX
      const pattern = /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/;
      return pattern.test(value);
    }
  }
};

/**
 * Initialize AJV validator with schema
 */
function initValidator(schema) {
  console.log('initValidator called, window.ajv7:', typeof window.ajv7);

  if (!window.ajv7) {
    console.error('AJV not loaded - window.ajv7 is undefined');
    return false;
  }

  try {
    // Create AJV instance (ajv7 is the global name for AJV 8.x)
    // Note: AJV 8 doesn't fully support draft 2020-12, so we use draft-07 mode
    ajvInstance = new window.ajv7({
      allErrors: true,
      verbose: true,
      strict: false,
      validateFormats: true,
      validateSchema: false  // Don't validate schema against meta-schema (draft compatibility)
    });
    console.log('AJV instance created');

    // Add custom formats
    for (const [name, format] of Object.entries(customFormats)) {
      ajvInstance.addFormat(name, format);
      console.log('Added format:', name);
    }

    // Remove $schema to avoid draft version conflicts
    const schemaToCompile = { ...schema };
    delete schemaToCompile.$schema;
    console.log('Schema prepared for compilation, keys:', Object.keys(schemaToCompile));

    // Compile schema
    validateFn = ajvInstance.compile(schemaToCompile);
    console.log('Schema compiled successfully, validateFn:', typeof validateFn);

    return true;
  } catch (e) {
    console.error('Failed to initialize validator:', e);
    console.error('Error details:', e.message, e.stack);
    return false;
  }
}

/**
 * Validate a document against the schema
 */
function validateDocument(data) {
  if (!validateFn) {
    console.warn('validateDocument called but validateFn is not initialized');
    return { valid: true, errors: [] };
  }

  const valid = validateFn(data);
  console.log('Validation result:', { valid, errorCount: validateFn.errors?.length || 0 });

  if (valid) {
    return { valid: true, errors: [] };
  }

  // Transform errors to a more readable format
  const errors = (validateFn.errors || []).map(error => {
    const path = error.instancePath
      ? error.instancePath.replace(/^\//, '').replace(/\//g, '.')
      : '';

    let message = error.message || 'Invalid value';

    // Enhance error messages
    switch (error.keyword) {
      case 'required':
        message = `Missing required field: ${error.params.missingProperty}`;
        break;
      case 'type':
        message = `Expected ${error.params.type}, got ${typeof error.data}`;
        break;
      case 'enum':
        message = `Must be one of: ${error.params.allowedValues.join(', ')}`;
        break;
      case 'pattern':
        message = `Does not match pattern: ${error.params.pattern}`;
        break;
      case 'format':
        message = `Invalid ${error.params.format} format`;
        break;
      case 'minimum':
        message = `Must be >= ${error.params.limit}`;
        break;
      case 'maximum':
        message = `Must be <= ${error.params.limit}`;
        break;
      case 'minLength':
        message = `Must be at least ${error.params.limit} characters`;
        break;
      case 'maxLength':
        message = `Must be at most ${error.params.limit} characters`;
        break;
      case 'additionalProperties':
        if (error.params.additionalProperty) {
          message = `Unknown property: ${error.params.additionalProperty}`;
        }
        break;
    }

    return {
      path: path || (error.params?.missingProperty ? error.params.missingProperty : ''),
      message,
      keyword: error.keyword,
      schemaPath: error.schemaPath,
      data: error.data
    };
  });

  // Deduplicate errors
  const uniqueErrors = [];
  const seen = new Set();
  for (const error of errors) {
    const key = `${error.path}:${error.message}`;
    if (!seen.has(key)) {
      seen.add(key);
      uniqueErrors.push(error);
    }
  }

  return { valid: false, errors: uniqueErrors };
}

/**
 * Validate a single field value
 */
function validateField(value, fieldSchema) {
  if (!fieldSchema) {
    return { valid: true, error: null };
  }

  // Check required (empty values)
  if (value === undefined || value === null || value === '') {
    // Don't report error for optional empty fields
    return { valid: true, error: null };
  }

  // Check type
  if (fieldSchema.type) {
    const expectedType = fieldSchema.type;
    let actualType = typeof value;
    if (actualType === 'number' && Number.isInteger(value)) {
      actualType = 'integer';
    }

    if (expectedType !== actualType) {
      // Allow string values that can be coerced
      if (expectedType === 'integer' || expectedType === 'number') {
        const num = Number(value);
        if (isNaN(num)) {
          return { valid: false, error: `Expected ${expectedType}` };
        }
      } else if (expectedType === 'boolean') {
        if (value !== 'true' && value !== 'false') {
          return { valid: false, error: 'Expected boolean' };
        }
      }
    }
  }

  // Check enum
  if (fieldSchema.enum && !fieldSchema.enum.includes(value)) {
    return { valid: false, error: `Must be one of: ${fieldSchema.enum.join(', ')}` };
  }

  // Check pattern
  if (fieldSchema.pattern) {
    const regex = new RegExp(fieldSchema.pattern);
    if (!regex.test(value)) {
      return { valid: false, error: 'Invalid format' };
    }
  }

  // Check format
  if (fieldSchema.format && customFormats[fieldSchema.format]) {
    if (!customFormats[fieldSchema.format].validate(value)) {
      return { valid: false, error: `Invalid ${fieldSchema.format} format` };
    }
  }

  // Check min/max
  if (fieldSchema.minimum !== undefined) {
    const num = Number(value);
    if (!isNaN(num) && num < fieldSchema.minimum) {
      return { valid: false, error: `Must be >= ${fieldSchema.minimum}` };
    }
  }
  if (fieldSchema.maximum !== undefined) {
    const num = Number(value);
    if (!isNaN(num) && num > fieldSchema.maximum) {
      return { valid: false, error: `Must be <= ${fieldSchema.maximum}` };
    }
  }

  // Check string length
  if (fieldSchema.minLength !== undefined && value.length < fieldSchema.minLength) {
    return { valid: false, error: `Must be at least ${fieldSchema.minLength} characters` };
  }
  if (fieldSchema.maxLength !== undefined && value.length > fieldSchema.maxLength) {
    return { valid: false, error: `Must be at most ${fieldSchema.maxLength} characters` };
  }

  return { valid: true, error: null };
}

/**
 * Get validation errors for a specific path
 */
function getErrorsForPath(errors, path) {
  return errors.filter(e => e.path === path || e.path.startsWith(path + '.'));
}

/**
 * Check if a path has validation errors
 */
function hasErrorsForPath(errors, path) {
  return getErrorsForPath(errors, path).length > 0;
}

/**
 * Test validation with sample invalid data (for debugging)
 */
function testValidation() {
  console.log('=== Validation Test ===');
  console.log('validateFn exists:', !!validateFn);

  // Test with empty object (should fail - missing required fields)
  const emptyResult = validateDocument({});
  console.log('Empty object validation:', emptyResult);

  // Test with invalid IP
  const invalidIp = validateDocument({
    account: {},
    cluster: {},
    network: { domain: 'test.com', primary: { gateway: 'not-an-ip' } },
    hosts: {}
  });
  console.log('Invalid IP validation:', invalidIp);

  // Test with valid minimal doc
  const validResult = validateDocument({
    account: {},
    cluster: {},
    network: { domain: 'example.com' },
    hosts: {}
  });
  console.log('Valid minimal doc validation:', validResult);

  return { emptyResult, invalidIp, validResult };
}

// Export for use in other modules
window.EditorValidator = {
  initValidator,
  validateDocument,
  validateField,
  getErrorsForPath,
  hasErrorsForPath,
  customFormats,
  testValidation
};

})(); // End IIFE
