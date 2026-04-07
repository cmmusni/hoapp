// Vercel Edge Middleware — Prerendering for search engine bots
// Detects crawler user agents and proxies to Prerender.io for static HTML.
// Set PRERENDER_TOKEN in Vercel Environment Variables.
//
// Docs: https://docs.prerender.io/docs/vercel

const BOT_AGENTS = [
  'googlebot',
  'bingbot',
  'yandex',
  'baiduspider',
  'facebookexternalhit',
  'twitterbot',
  'rogerbot',
  'linkedinbot',
  'embedly',
  'quora link preview',
  'showyoubot',
  'outbrain',
  'pinterest/0.',
  'developers.google.com/+/web/snippet',
  'slackbot',
  'vkshare',
  'w3c_validator',
  'redditbot',
  'applebot',
  'whatsapp',
  'flipboard',
  'tumblr',
  'bitlybot',
  'skypeuripreview',
  'nuzzel',
  'discordbot',
  'google page speed',
  'qwantify',
  'pinterestbot',
  'bitrix link preview',
  'xing-contenttabreceiver',
  'chrome-lighthouse',
  'telegrambot',
  'duckduckbot',
];

const PRERENDER_URL = 'https://service.prerender.io/';

export default async function middleware(request) {
  const userAgent = (request.headers.get('user-agent') || '').toLowerCase();
  const url = new URL(request.url);

  // Skip prerendering for static assets, API routes, and non-page resources
  const path = url.pathname;
  if (
    path.startsWith('/assets/') ||
    path.startsWith('/icons/') ||
    path.startsWith('/api/') ||
    path.endsWith('.js') ||
    path.endsWith('.css') ||
    path.endsWith('.png') ||
    path.endsWith('.jpg') ||
    path.endsWith('.ico') ||
    path.endsWith('.json') ||
    path.endsWith('.xml') ||
    path.endsWith('.txt') ||
    path.endsWith('.wasm') ||
    path.endsWith('.map')
  ) {
    return;
  }

  // Check if this is a bot/crawler request
  const isBot = BOT_AGENTS.some((bot) => userAgent.includes(bot));

  // Also check for _escaped_fragment_ (legacy bot signal)
  const hasEscapedFragment = url.searchParams.has('_escaped_fragment_');

  if (isBot || hasEscapedFragment) {
    const prerenderToken = process.env.PRERENDER_TOKEN;
    if (!prerenderToken) {
      // No token configured, fall through to normal rendering
      return;
    }

    const prerenderUrl = `${PRERENDER_URL}${url.toString()}`;

    try {
      const response = await fetch(prerenderUrl, {
        headers: {
          'X-Prerender-Token': prerenderToken,
        },
        redirect: 'follow',
      });

      const body = await response.text();

      return new Response(body, {
        status: response.status,
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'X-Prerendered': 'true',
          'Cache-Control': 'public, max-age=3600, s-maxage=86400',
        },
      });
    } catch (e) {
      // If prerender fails, fall through to normal SPA rendering
      return;
    }
  }

  // Not a bot — proceed with normal SPA rendering
  return;
}

export const config = {
  matcher: '/((?!_next|_vercel|api).*)',
};
