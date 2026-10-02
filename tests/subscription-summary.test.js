import test from 'node:test';
import assert from 'node:assert/strict';
import {subscriptionSummary as summary} from '../js/lib/subscription-summary.js';
const now=new Date('2026-10-02T12:00:00Z');
test('sidebar distinguishes trial, approaching due date, today and overdue',()=>{
 assert.equal(summary({status:'trial',current_period_end:'2026-11-01'},now).title,'Em período de teste');
 assert.equal(summary({status:'active',current_period_end:'2026-10-07'},now).tone,'warning');
 assert.equal(summary({status:'active',current_period_end:'2026-10-08'},now).tone,'ok');
 assert.equal(summary({status:'active',current_period_end:'2026-10-02'},now).detail,'Vence hoje');
 assert.match(summary({status:'active',current_period_end:'2026-10-01'},now).detail,/Vencido há 1 dia/);
 assert.equal(summary({status:'trial',current_period_end:'2026-10-01'},now).tone,'danger');
 assert.equal(summary({status:'active',current_period_end:'2026-10-02'},new Date('2026-10-03T01:00:00Z')).detail,'Vence hoje');
 assert.equal(summary(null,now).tone,'neutral');
});
