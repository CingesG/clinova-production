import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { join } from 'path';
import { allowBrowserOrigin, strictProductionBrowserCors, resolveBrowserOriginAllowlist } from './common/cors-origins';
import { AppModule } from './modules/app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.use(
    helmet({
      // Allow web app origin (e.g. :3164) to render uploaded images from :4000.
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );
  app.useStaticAssets(join(process.cwd(), 'uploads'), {
    prefix: '/uploads',
    setHeaders: (res) => {
      // Flutter web (canvas/html renderer) needs explicit CORS on image assets.
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    },
  });

  if (strictProductionBrowserCors() && resolveBrowserOriginAllowlist().length === 0) {
    throw new Error(
      'Production REST CORS: FRONTEND_URL эсвэл CORS_ORIGIN (тусдаад нэмэх,) заавал. Жишээ: FRONTEND_URL=https://clinova.vercel.app',
    );
  }

  app.enableCors({
    origin: (origin, cb) => {
      cb(null, allowBrowserOrigin(origin ?? undefined));
    },
    credentials: true,
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  const port = Number(process.env.PORT ?? 4000);
  await app.listen(port, '0.0.0.0');
}

void bootstrap();
