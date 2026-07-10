import assert from 'node:assert/strict';
import test from 'node:test';

import {
  cancelOrderSchema,
  createAddressSchema,
  createOrderSchema,
  loginSchema,
  validate,
} from '../src/validation.js';

test('login validation requires an email and password', () => {
  assert.deepEqual(validate(loginSchema, {
    email: 'buyer@example.com',
    password: 'secret',
  }), {
    email: 'buyer@example.com',
    password: 'secret',
  });

  assert.throws(
    () => validate(loginSchema, { email: 'bad', password: '' }),
    /Validation failed/,
  );
});

test('checkout validation requires at least one item', () => {
  assert.throws(
    () => validate(createOrderSchema, {
      customerEmail: 'buyer@example.com',
      customerName: 'Buyer',
      shopId: 'shop_1',
      items: [],
    }),
    /Validation failed/,
  );
});

test('customer address validation accepts saved delivery addresses', () => {
  const address = validate(createAddressSchema, {
    label: 'Home',
    city: 'Beirut',
    line1: 'Mar Mikhael, Building 12',
  });

  assert.equal(address.label, 'Home');
  assert.equal(address.city, 'Beirut');
  assert.equal(address.line1, 'Mar Mikhael, Building 12');
});

test('cancel order validation accepts an optional reason', () => {
  assert.deepEqual(validate(cancelOrderSchema, {
    reason: 'Ordered by mistake',
  }), {
    reason: 'Ordered by mistake',
  });
});
