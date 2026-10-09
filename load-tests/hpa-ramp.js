// Main demo load: ramps traffic up so catalogue CPU crosses the HPA target (50% of request),
// holds it long enough to watch scale-out, then drops to a trickle to watch scale-in.
//
// Run:  k6 run load-tests/hpa-ramp.js
// Tunables (env):  BASE_URL, PEAK_VUS (default 25), STRESS_MS (CPU burned per heavy request, default 25),
//                  HOLD (peak duration, default 4m), COOLDOWN (trickle duration, default 4m)
//
// Request mix per iteration: ~60% list, ~20% get-by-id, ~20% CPU-heavy /api/stress.
// Think-time is short so a modest number of VUs produces sustained CPU pressure on a single 100m-request Pod.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const BASE = __ENV.BASE_URL || 'http://localhost:8080';
const PEAK = parseInt(__ENV.PEAK_VUS || '25');
const STRESS_MS = parseInt(__ENV.STRESS_MS || '25');
const HOLD = __ENV.HOLD || '4m';
const COOLDOWN = __ENV.COOLDOWN || '4m';

const errors = new Rate('app_errors');

export const options = {
  scenarios: {
    ramp: {
      executor: 'ramping-vus',
      startVUs: 0,
      gracefulRampDown: '15s',
      stages: [
        { duration: '30s', target: 5 },        // baseline: HPA should stay at min replicas
        { duration: '1m', target: PEAK },      // ramp up
        { duration: HOLD, target: PEAK },      // sustained peak: expect scale-out
        { duration: '30s', target: 2 },        // drop
        { duration: COOLDOWN, target: 2 },     // trickle: expect scale-in after the stabilization window
        { duration: '10s', target: 0 },
      ],
    },
  },
  thresholds: {
    app_errors: ['rate<0.02'],
    http_req_duration: ['p(95)<2000'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'max'],
};

export default function () {
  const dice = Math.random();
  let res;
  if (dice < 0.6) {
    res = http.get(`${BASE}/api/products?limit=20&offset=${Math.floor(Math.random() * 80)}`, { tags: { name: 'list' } });
  } else if (dice < 0.8) {
    res = http.get(`${BASE}/api/products/${1 + Math.floor(Math.random() * 100)}`, { tags: { name: 'get' } });
  } else {
    res = http.get(`${BASE}/api/stress?ms=${STRESS_MS}`, { tags: { name: 'stress' } });
  }
  errors.add(!check(res, { 'status 2xx': (r) => r.status >= 200 && r.status < 300 }));
  sleep(0.05 + Math.random() * 0.1);
}

// With SUMMARY_FILE set (scripts/run-loadtest.ps1) write the full JSON and print a compact text summary;
// otherwise k6 prints its normal end-of-test summary.
export function handleSummary(data) {
  const out = __ENV.SUMMARY_FILE;
  if (!out) return {};
  const m = data.metrics;
  const ms = (v) => (v === undefined ? 'n/a' : v.toFixed(0) + ' ms');
  const text = [
    '',
    'k6 summary',
    `  requests:        ${m.http_reqs.values.count} (${m.http_reqs.values.rate.toFixed(1)}/s)`,
    `  failed requests: ${(m.http_req_failed.values.rate * 100).toFixed(2)} %`,
    `  latency avg/p90/p95/max: ${ms(m.http_req_duration.values.avg)} / ${ms(m.http_req_duration.values['p(90)'])} / ${ms(m.http_req_duration.values['p(95)'])} / ${ms(m.http_req_duration.values.max)}`,
    `  peak VUs:        ${m.vus_max.values.max}`,
    '',
  ].join('\n');
  return { stdout: text, [out]: JSON.stringify(data, null, 2) };
}
