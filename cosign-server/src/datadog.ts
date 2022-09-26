const ddUrl = 'https://http-intake.logs.datadoghq.com/api/v2/logs';

type LogStatus = 'success' | 'error' | 'warn' | 'info';

export function dd(
  event: FetchEvent,
  data: Record<string, any>,
  status?: LogStatus,
) {
  if (DATADOG_SK.length === 0) {
    return;
  }

  const hostname = event.request.headers.get('host') || '';
  event.waitUntil(
    fetch(ddUrl, {
      method: 'POST',
      body: JSON.stringify({
        ddsource: 'cloudflare',
        ddtags: 'site:' + hostname,
        hostname: hostname,
        service: 'erc721m-cosign-server',
        message: JSON.stringify(data),
        status: status ?? 'success',
      }),
      headers: new Headers({
        'Content-Type': 'application/json',
        'DD-API-KEY': DATADOG_SK,
      }),
    }),
  );
}
