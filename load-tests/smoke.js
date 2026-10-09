// Quick sanity check before every recording: 1 VU, ~10 s, exercises every gateway route.
// Run:  k6 run load-tests/smoke.js        (BASE_URL defaults to the kind NodePort on localhost:8080)
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  vus: 1,
  duration: '10s',
  thresholds: { http_req_failed: ['rate<0.01'], http_req_duration: ['p(95)<500'] },
};

export default function () {
  check(http.get(`${BASE}/readyz`), { 'readyz 200': (r) => r.status === 200 });
  check(http.get(`${BASE}/api/products?limit=5`), { 'list 200': (r) => r.status === 200 });
  check(http.get(`${BASE}/api/products/1`), { 'get 200': (r) => r.status === 200 });
  check(http.get(`${BASE}/api/stress?ms=10`), { 'stress 200': (r) => r.status === 200 });
  sleep(0.5);
}
