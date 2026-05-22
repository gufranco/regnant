// k6 sustained load test. Asserts SLO targets:
//   p50 < 50ms, p95 < 200ms, error rate < 0.1%.

import http from 'k6/http';
import {check, sleep} from 'k6';

export const options = {
  scenarios: {
    sustained: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        {duration: '30s', target: 20},
        {duration: '2m', target: 50},
        {duration: '2m', target: 100},
        {duration: '30s', target: 0},
      ],
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    'http_req_failed{scenario:sustained}': ['rate<0.001'],
    'http_req_duration{scenario:sustained}': ['p(50)<50', 'p(95)<200', 'p(99)<500'],
  },
  insecureSkipTLSVerify: true,
};

const TARGETS = [
  '/issues',
  '/pages',
  '/repos',
  '/health',
];

export default function () {
  const base = __ENV.TARGET_URL || 'https://localhost:8443';
  const path = TARGETS[Math.floor(Math.random() * TARGETS.length)];
  const res = http.get(`${base}${path}`, {
    headers: {
      'x-ab-key': `vu-${__VU}`,
    },
  });
  check(res, {
    'status is acceptable': (r) => r.status < 500 || r.status === 503,
  });
  sleep(Math.random() * 0.5);
}
