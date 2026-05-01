import { Controller, Get } from '@nestjs/common';

/** Public root so tunnel / browser checks on `/` don’t look like a broken API. */
@Controller()
export class HealthController {
  @Get()
  root() {
    return {
      ok: true,
      name: 'Clinova API',
      hint: 'Use the mobile/web app with this host as API_BASE_URL. Try GET /branches',
    };
  }

  @Get('health')
  health() {
    return { ok: true, ts: new Date().toISOString() };
  }
}
