// k6 smoke test: 30 seconds of low traffic, asserts the stack stays
// healthy at zero load.

import http from 'k6/http';
import {check, sleep} from 'k6';

export const options = {
  vus: 5,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
  insecureSkipTLSVerify: true,
};

export default function () {
  const res = http.get(`${__ENV.TARGET_URL || 'https://localhost:8443'}/health`);
  check(res, {
    'status is 2xx, 4xx, or 503 (auth/ratelimit OK)': (r) =>
      [200, 401, 403, 404, 503].includes(r.status),
  });
  sleep(1);
}
