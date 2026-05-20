/**
 * REST (Express) ба Socket.IO нь продакшн дээр ижил вэб домэйноор нэвтрэх тохируулгыг хуваана.
 */

const LOCALHOST_ORIGIN_RES = [
  /^http:\/\/localhost(?::\d+)?$/i,
  /^http:\/\/127\.0\.0\.1(?::\d+)?$/i,
];

/** NODE_ENV=production үед локал/ngrok-т зөвхөн ALLOW_LEGACY_DEV_CORS=true бол зөвшөөрнө */
export function strictProductionBrowserCors(): boolean {
  const nodeEnv = (process.env.NODE_ENV ?? '').toLowerCase();
  if (nodeEnv !== 'production') return false;
  return process.env.ALLOW_LEGACY_DEV_CORS !== 'true';
}

/** Production canonical frontend: https://www.clinova.uk (apex redirects via Vercel). */
const CLINOVA_PRODUCTION_BROWSER_ORIGINS = ['https://www.clinova.uk'] as const;

/** FRONTEND_URL + CORS_ORIGIN (товхоолсон) жагсаалт */
export function resolveBrowserOriginAllowlist(): string[] {
  const corsRaw = process.env.CORS_ORIGIN?.split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const frontendUrl = process.env.FRONTEND_URL?.trim();
  const set = new Set<string>();
  if (frontendUrl) set.add(frontendUrl);
  for (const o of corsRaw ?? []) set.add(o);
  for (const o of CLINOVA_PRODUCTION_BROWSER_ORIGINS) set.add(o);
  return [...set];
}

/** Express `origin` callback-д ашиглана */
export function allowBrowserOrigin(origin: string | undefined): boolean {
  if (!origin) return true;
  const staticAllowed = new Set(resolveBrowserOriginAllowlist());
  if (staticAllowed.has(origin)) return true;
  if (strictProductionBrowserCors()) return false;

  if (LOCALHOST_ORIGIN_RES.some((re) => re.test(origin))) return true;

  const ngrokAllowed =
    process.env.ALLOW_NGROK === 'true'
      ? [/^https?:\/\/[a-z0-9-]+\.ngrok(-free)?\.app$/i]
      : [];
  if (ngrokAllowed.some((re) => re.test(origin))) return true;

  const tryCloudflareBlocked = process.env.ALLOW_TRYCLOUDFLARE === 'false';
  if (!tryCloudflareBlocked && /^https:\/\/[a-z0-9-]+\.trycloudflare\.com$/i.test(origin)) {
    return true;
  }

  return false;
}

/** Socket.IO `WebSocketGateway` cors тохируулга (файлыг уншиж байх үед байна) */
export function socketIoBrowserCorsOptions(): {
  origin: boolean | string[];
  credentials: boolean;
} {
  const strict = strictProductionBrowserCors();
  const list = resolveBrowserOriginAllowlist();

  if (strict && list.length === 0) {
    throw new Error(
      'Production Socket.IO CORS: FRONTEND_URL эсвэл CORS_ORIGIN заавал (жишээ FRONTEND_URL=https://your-app.vercel.app)',
    );
  }

  if (!strict || list.length === 0) {
    return { origin: true, credentials: true };
  }

  return { origin: list, credentials: true };
}
