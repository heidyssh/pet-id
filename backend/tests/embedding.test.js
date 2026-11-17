import assert from 'node:assert/strict';
import { similitudCoseno } from '../src/services/embedding.service.js';

assert.equal(similitudCoseno([1, 0], [1, 0]), 1);
assert.equal(similitudCoseno([1, 0], [0, 1]), 0);
assert.equal(similitudCoseno([1, 0], [-1, 0]), -1);
assert.equal(similitudCoseno([], []), null);
assert.equal(similitudCoseno([1], [1, 0]), null);

const aproximada = similitudCoseno([2, 2], [1, 1]);
assert.ok(Math.abs(aproximada - 1) < 1e-12);

console.log('Similitud coseno: OK');
