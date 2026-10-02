import test from 'node:test';
import assert from 'node:assert/strict';
import {formatPixExpiration} from '../supabase/functions/_shared/pix.js';
test('PIX expiration normalizes Postgres timestamp to provider ISO format',()=>{
 assert.equal(formatPixExpiration('2026-11-01T02:59:59+00:00'),'2026-11-01T02:59:59.000+00:00');
 assert.equal(formatPixExpiration('2026-10-31T23:59:59-03:00'),'2026-11-01T02:59:59.000+00:00');
 assert.throws(()=>formatPixExpiration('invalid'));
});
