import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DepartmentStatus } from '@prisma/client';
import OpenAI from 'openai';

import { PrismaService } from '../common/prisma.service';
import { AppointmentService } from '../appointment/appointment.service';

export type UrgencyLevel = 'LOW' | 'MEDIUM' | 'HIGH' | 'EMERGENCY';

export interface TriageInput {
  symptoms: string;
  age?: string;
  gender?: string;
  duration?: string;
  severity?: string;
}

export type AgentReplyType =
  | 'HEALTH_QA'
  | 'TRIAGE'
  | 'APP_HELP'
  | 'BOOKING_HELP'
  | 'CHAT_HELP'
  | 'EMERGENCY'
  | 'GENERAL';

export interface AgentContextInput {
  userId?: string;
  language?: string;
  currentScreen?: string;
  conversationId?: string;
  history?: Array<{ role: string; content: string }>;
}

export interface ClinovaAgentAction {
  label: string;
  route: string;
  params: Record<string, unknown>;
}

export interface ClinovaAgentResponse {
  type: AgentReplyType;
  answer: string;
  urgency: UrgencyLevel | 'NONE';
  recommendedDepartment: string | null;
  recommendedDoctors: Array<Record<string, unknown>>;
  actions: ClinovaAgentAction[];
  safetyDisclaimer: string;
}

/** Symptom keywords (MN + EN) → department name substring used in DB seed. */
const DEPT_RULES: Array<{ re: RegExp; deptIncludes: string }> = [
  {
    re: /чих|хоолой|сонсгол|ear|ears|throat|\bent\b|chi[h]?|hooloi|sons(g|h)ol/i,
    deptIncludes: 'ENT',
  },
  {
    re: /шүд|шүдний|tooth|teeth|dental|dentistry|cavity|shud|shudnii/i,
    deptIncludes: 'Dentistry',
  },
  {
    re: /хүүхэд|child|kid|baby|pediatr|huuhed|huuhdiin/i,
    deptIncludes: 'Pediatrics',
  },
  {
    re: /арьс|skin|rash|itch|дермат|dermat|arisan|tuuralt|zagathna/i,
    deptIncludes: 'Dermatology',
  },
  {
    re: /зүрх|heart|chest pain|cardio|angina|blood pressure|zurh|daralt/i,
    deptIncludes: 'Cardiology',
  },
  {
    re: /жирэмсэн|pregn|gynec|women|obstetr|jiremsen|emegtei/i,
    deptIncludes: 'Gynecology',
  },
  {
    re: /толгой|headache|migrain|neuro|нүд|tolgoi|tolgoi(o|u)?vd|nud/i,
    deptIncludes: 'Neurology',
  },
  {
    re: /халуун|fever|cold|flu|cough|internal|stomach|бээрэх|хэвлий|abdomen|haluur|hani|hevlii|gedes/i,
    deptIncludes: 'Internal Medicine',
  },
  {
    re: /гэмтэл|fracture|trauma|injury|broken|хугцаа|gemtel|hugarsan/i,
    deptIncludes: 'Trauma',
  },
  {
    re: /мэс засал|surgery|surgical|операц|mes zasal|hagalgaa/i,
    deptIncludes: 'Surgery',
  },
  {
    re: /сэтгэл|түргэн|тэвдэх|anxiety|panic|depress|setgel|tugsh|sandrah/i,
    deptIncludes: 'Internal Medicine',
  },
];

const EMERGENCY_RULES: RegExp[] = [
  /цээж.*өвд|хүчтэй.*цээж|chest\s*pain|crushing\s*chest|tseej.*ovd|tseej.*uwd/i,
  /амьсгал\s*давчда|амьсгал\s*хүнд|shortness\s*of\s*breath|can'?t\s*breathe|suffocat|amsgal.*davch|amsgal.*hund/i,
  /ухаан\s*алд|баларч|loss\s*of\s*consciousness|unresponsive|faint(ing)?|uhaan.*ald|balar/i,
  /хүчтэй\s*цус|цус\s*алда|severe\s*bleed|hemorrhag|tsus.*ald/i,
  /сувдай|инсульт|stroke|face\s*drooping|slurred\s*speech|harvalt|hel.*egtej/i,
  /харшил.*амь|anaphylaxis|throat\s*swell.*shut|harshil.*hund/i,
  /толгой\s*хүчтэй\s*гэмтэл|severe\s*head\s*injury|tolgoi.*gemtel/i,
  /жирэмсэн.*өвд|pregnancy.*bleed|eclampsia|jiremsen.*tsus/i,
  /хүүхэд.*чичиргэ|seizure|convulsion|huuhed.*tatalt/i,
  /халуур.*удаан|infant.*fever|huuhed.*haluur/i,
];

const HIGH_URGENCY_RULES: RegExp[] = [
  /халуур|fever|haluur/i,
  /цус\s*алд|bleed|tsus.*ald/i,
  /өвдөлт.*хүчтэй|severe\s*pain|huchtei.*ovd/i,
  /бүдүүн|bloody\s*stool/i,
];

const SYMPTOM_INTENT_RULES: RegExp[] = [
  /өвд|өвдө|өвдөлт|толгой|халуур|ханиа|арьс|тууралт|амьсгал|цээж|гэдэс|хэвлий|зүрх|шүд|жирэмс|ухаан/i,
  /ovd|uwd|uvd|tolgoi|haluur|hani|arisan|tuuralt|amsgal|tseej|gedes|hevlii|zurh|shud|jirems|uhaan/i,
  /pain|ache|fever|cough|rash|breath|chest|stomach|abdomen|heart|tooth|pregnan|dizz|faint/i,
];

@Injectable()
export class AiAgentService {
  private readonly logger = new Logger(AiAgentService.name);
  private readonly client?: OpenAI;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly appointments: AppointmentService,
  ) {
    const apiKey = this.config.get<string>('OPENAI_API_KEY');
    if (apiKey) {
      this.client = new OpenAI({ apiKey });
    }
  }

  async runTriage(input: TriageInput) {
    const text = this.composeSymptomText(input);
    const searchable = this.toSearchableText(text);
    const emergencyHit = EMERGENCY_RULES.some((re) => re.test(searchable));
    if (emergencyHit) {
      return this.emergencyPayload(text);
    }

    let llmPart: {
      urgency?: UrgencyLevel;
      summary?: string;
      recommendedDepartment?: string;
      recommendedSpecialty?: string;
      nextSteps?: string[];
      safetyWarnings?: string[];
    } = {};

    if (this.client) {
      try {
        const completion = await this.client.chat.completions.create({
          model: this.config.get<string>('OPENAI_MODEL') ?? 'gpt-4o-mini',
          response_format: { type: 'json_object' },
          messages: [
            {
              role: 'system',
              content: `You are Clinova triage (NOT a doctor). Output ONLY valid JSON with keys:
urgency: one of LOW, MEDIUM, HIGH, EMERGENCY
summary: one short paragraph in Mongolian, tentative language only ("байж болзошгүй", "эмчид үзүүлэхийг зөвлөж байна"), NEVER definitive diagnosis or drug dosages
recommendedDepartment: one of ENT, Dentistry, Pediatrics, Dermatology, Cardiology, Gynecology, Neurology, Internal Medicine, Trauma, Surgery, General
recommendedSpecialty: short MN label for specialty
nextSteps: array of 2-4 short strings in Mongolian (actions like chat, book, ER)
safetyWarnings: array of 0-2 short MN warnings
Rules: If chest pain, breathing trouble, LOC, stroke signs, severe bleeding → EMERGENCY. No "you have X disease".`,
            },
            { role: 'user', content: text },
          ],
        });
        const raw = completion.choices[0]?.message?.content?.trim();
        if (raw) {
          llmPart = JSON.parse(raw) as typeof llmPart;
        }
      } catch (e) {
        this.logger.warn(`OpenAI triage failed: ${e}`);
      }
    }

    const departments = await this.prisma.department.findMany({
      where: { status: DepartmentStatus.ACTIVE },
      select: { id: true, name: true },
      orderBy: { name: 'asc' },
    });

    if (departments.length === 0) {
      return {
        urgency: 'MEDIUM' as UrgencyLevel,
        summary:
          llmPart.summary ??
          'Системд идэвхтэй тасаг бүртгэгдээгүй байна. Эмнэлэгт холбогдоно уу.',
        recommendedDepartment: '—',
        recommendedSpecialty: llmPart.recommendedSpecialty ?? '—',
        nextSteps: llmPart.nextSteps ?? ['Эмнэлэгт холбогдох'],
        safetyWarnings: llmPart.safetyWarnings ?? [
          'Энэ нь эмчийн онош биш.',
        ],
        suggestedDoctors: [],
      };
    }

    const deptHint = llmPart.recommendedDepartment?.trim();
    const dept = this.pickDepartment(departments, searchable, deptHint);
    if (!dept) {
      return {
        urgency: (llmPart.urgency ?? 'MEDIUM') as UrgencyLevel,
        summary: llmPart.summary ?? 'Тасаг сонгож чадсангүй.',
        recommendedDepartment: '—',
        recommendedSpecialty: llmPart.recommendedSpecialty ?? '—',
        nextSteps: llmPart.nextSteps ?? ['Цаг захиалах хуудаснаас сонгоно уу'],
        safetyWarnings: llmPart.safetyWarnings ?? [
          'Энэ нь эмчийн онош биш. Хүнд шинж илэрвэл яаралтай тусламж авна уу.',
        ],
        suggestedDoctors: [],
      };
    }

    const ruleUrgency = this.urgencyFromRules(searchable);
    const urgency = (llmPart.urgency ?? ruleUrgency) as UrgencyLevel;

    const suggestedDoctors = await this.buildSuggestedDoctors(dept, searchable);

    const nextSteps = this.mergeNextSteps(
      llmPart.nextSteps,
      urgency,
      suggestedDoctors.length > 0,
    );

    const safetyWarnings = [
      ...(llmPart.safetyWarnings ?? []),
      'Энэ нь эмчийн онош биш. Амьсгал давчдах, цээж хүчтэй өвдөх, ухаан балартах, хүчтэй цус алдах зэрэг шинж илэрвэл яаралтай тусламж (102, 103) авна уу.',
    ];

    const summary =
      llmPart.summary ??
      `Ийм шинж тэмдэг нь ${dept.name} тасгийн чиглэлээр үзлэг хийлгэхэд тохиромжтой байж болзошгүй. Эмчид үзүүлж баталгаажуулахыг зөвлөж байна.`;

    return {
      urgency,
      summary,
      recommendedDepartment: dept.name,
      recommendedSpecialty:
        llmPart.recommendedSpecialty ?? dept.name ?? 'Ерөнхий',
      nextSteps,
      safetyWarnings,
      suggestedDoctors,
      booking:
        suggestedDoctors[0]?.booking ??
        ({
          branchId: null,
          departmentId: dept.id,
          doctorId: null,
          serviceId: null,
        } as Record<string, string | null>),
    };
  }

  /** @deprecated use runTriage */
  async triageAndRecommend(symptomText: string) {
    return this.runTriage({ symptoms: symptomText });
  }

  private readonly agentDisclaimer =
    'Энэ нь эмчийн онош биш. Шинж тэмдэг хүндэрвэл эмчид хандана уу.';

  async runAgent(
    message: string,
    ctx?: AgentContextInput,
  ): Promise<ClinovaAgentResponse> {
    const text = message.trim();
    if (!text) {
      return this.agentShell(
        'GENERAL',
        'Асуултаа бичээд илгээнэ үү.',
        'NONE',
        [],
      );
    }

    const combined = this.mergeConversation(text, ctx);
    const searchableText = this.toSearchableText(text);
    const searchableCombined = this.toSearchableText(combined);

    if (
      EMERGENCY_RULES.some((re) => re.test(searchableText)) ||
      EMERGENCY_RULES.some((re) => re.test(searchableCombined))
    ) {
      return this.buildEmergencyAgentResponse();
    }

    if (/баярлалаа|thanks|thank\s*you|^ok$|^сайн$/i.test(text) && text.length < 48) {
      return this.agentShell(
        'GENERAL',
        'Танд амжилт хүсэж байна. Өөр асуулт байвал бичнэ үү.',
        'NONE',
        [],
      );
    }

    if (this.isAppNavigationQuestion(text, combined)) {
      return this.buildAppHelpResponse(text);
    }

    if (this.isBookingHelperQuestion(text, combined)) {
      return this.buildBookingHelpResponse();
    }

    if (this.isChatHelperQuestion(text, combined)) {
      return this.buildChatHelpResponse();
    }

    // Agent-like behavior: short symptom phrases trigger clarifying follow-up first.
    if (this.isLikelySymptom(text) && this.needsSymptomClarification(text, combined)) {
      return this.buildSymptomClarificationResponse(text);
    }

    const health = this.ruleBasedHealthQa(text, combined);
    if (health) {
      return {
        type: 'HEALTH_QA',
        answer: health,
        urgency: 'NONE',
        recommendedDepartment: null,
        recommendedDoctors: [],
        actions: [
          { label: 'Эмчтэй чатлах', route: '/chat-landing', params: {} },
          { label: 'Цаг захиалах', route: '/appointments-landing', params: {} },
        ],
        safetyDisclaimer: this.agentDisclaimer,
      };
    }

    if (this.client) {
      const llm = await this.llmAgentTurn(text, combined, ctx?.language);
      if (llm) return llm;
    }

    const triage = await this.runTriage({ symptoms: combined });
    return this.triageToAgentResponse(triage);
  }

  private needsSymptomClarification(text: string, combined: string): boolean {
    const s = this.toSearchableText(text);
    const c = this.toSearchableText(combined);
    const hasDuration =
      /өдөр|хоног|сар|жил|tsag|udur|honog|sar|jil|day|days|week|weeks|month/i.test(
        s,
      );
    const hasSeverity =
      /хөнгөн|дунд|хүчтэй|mild|moderate|severe|ih|baga|huchtei/i.test(s);
    const hasAge =
      /нас|nastai|yo|year old|\b\d{1,2}\s*(нас|yo|y\/o|years?)/i.test(c);
    const shortSymptomOnly = text.trim().split(/\s+/).length <= 4;
    return shortSymptomOnly || !hasDuration || !hasSeverity || !hasAge;
  }

  private buildSymptomClarificationResponse(message: string): ClinovaAgentResponse {
    const cleaned = message.trim();
    return {
      type: 'TRIAGE',
      urgency: 'NONE',
      answer:
        `Ойлголоо, "${cleaned}" гэж байна. Туслахын тулд 3 зүйл тодруулъя:\n` +
        '1) Хэдий хугацаанд үргэлжилж байна?\n' +
        '2) Хүчтэй байдал (хөнгөн/дунд/хүчтэй)?\n' +
        '3) Нас (ойролцоогоор)?\n' +
        'Эдгээрийг хэлбэл яг тохирох тасаг, эмч, дараагийн алхмыг санал болгоё.',
      recommendedDepartment: null,
      recommendedDoctors: [],
      actions: [
        {
          label: 'Эмчтэй чатлах',
          route: '/chat-landing',
          params: {},
        },
        {
          label: 'Шууд цаг авах',
          route: '/appointments-landing',
          params: {},
        },
      ],
      safetyDisclaimer: this.agentDisclaimer,
    };
  }

  private mergeConversation(message: string, ctx?: AgentContextInput): string {
    const hist = ctx?.history?.slice(-10) ?? [];
    if (hist.length === 0) return message;
    const lines = hist.map((h) => `${h.role}: ${h.content}`);
    lines.push(`user: ${message}`);
    return lines.join('\n');
  }

  /**
   * Makes matching robust for:
   * - Cyrillic Mongolian
   * - Latin Mongolian typing (e.g. "tolgoi uvduj baina")
   * - mixed punctuation / spacing / minor typing variation
   */
  private toSearchableText(input: string): string {
    const raw = input.toLowerCase();
    const compact = raw
      .replace(/[^\p{L}\p{N}\s]/gu, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    const cyrToLat: Record<string, string> = {
      а: 'a',
      б: 'b',
      в: 'v',
      г: 'g',
      д: 'd',
      е: 'e',
      ё: 'yo',
      ж: 'j',
      з: 'z',
      и: 'i',
      й: 'i',
      к: 'k',
      л: 'l',
      м: 'm',
      н: 'n',
      о: 'o',
      ө: 'o',
      п: 'p',
      р: 'r',
      с: 's',
      т: 't',
      у: 'u',
      ү: 'u',
      ф: 'f',
      х: 'h',
      ц: 'ts',
      ч: 'ch',
      ш: 'sh',
      щ: 'sh',
      ъ: '',
      ы: 'i',
      ь: '',
      э: 'e',
      ю: 'yu',
      я: 'ya',
    };

    const translit = compact
      .split('')
      .map((ch) => cyrToLat[ch] ?? ch)
      .join('')
      .replace(/\s+/g, ' ')
      .trim();

    const latinNormalized = translit
      .replace(/ph/g, 'f')
      .replace(/kh/g, 'h')
      .replace(/aa+/g, 'a')
      .replace(/ee+/g, 'e')
      .replace(/ii+/g, 'i')
      .replace(/oo+/g, 'o')
      .replace(/uu+/g, 'u')
      .replace(/vv+/g, 'v')
      .replace(/ts/g, 'c')
      .replace(/\s+/g, ' ')
      .trim();

    // Keep multiple views so regex can hit either script/style.
    return `${compact}\n${translit}\n${latinNormalized}`;
  }

  private agentShell(
    type: AgentReplyType,
    answer: string,
    urgency: UrgencyLevel | 'NONE',
    actions: ClinovaAgentAction[],
    doctors: Array<Record<string, unknown>> = [],
    dept: string | null = null,
  ): ClinovaAgentResponse {
    return {
      type,
      answer,
      urgency,
      recommendedDepartment: dept,
      recommendedDoctors: doctors,
      actions,
      safetyDisclaimer: this.agentDisclaimer,
    };
  }

  private buildEmergencyAgentResponse(): ClinovaAgentResponse {
    return {
      type: 'EMERGENCY',
      answer:
        'Энэ шинж тэмдэг яаралтай тусламж шаардлагатай байж болзошгүй. Яаралтай тусламж руу холбогдоно уу.',
      urgency: 'EMERGENCY',
      recommendedDepartment: null,
      recommendedDoctors: [],
      actions: [
        {
          label: 'Яаралтай тусламж авах',
          route: 'emergency:tel',
          params: { number: '102' },
        },
        { label: 'Эмчтэй чат (яаралтай бус)', route: '/chat-landing', params: {} },
      ],
      safetyDisclaimer: this.agentDisclaimer,
    };
  }

  private isAppNavigationQuestion(text: string, combined: string): boolean {
    const blob = this.toSearchableText(`${text}\n${combined}`);
    return (
      /цаг\s*яаж|haana.*tsag|haana.*chat|захиалах\s*заавар|how\s*to\s*book|booking\s*help|чат\s*хаана|where.*chat|профайл|profile|засах|zasah|миний\s*цаг|minii\s*tsag|цаг\s*харагдах|home\s*screen|нүүр/i.test(
        blob,
      ) && !this.isLikelySymptom(text)
    );
  }

  private isBookingHelperQuestion(text: string, combined: string): boolean {
    const blob = this.toSearchableText(`${text}\n${combined}`);
    return /салбар\s*сонгох|огноо\s*сонгох|цаг\s*бэлтгэх|booking\s*help|prepare\s*appointment|яаж\s*бүртгүүл/i.test(
      blob,
    );
  }

  private isChatHelperQuestion(text: string, combined: string): boolean {
    const blob = this.toSearchableText(`${text}\n${combined}`);
    return (
      /эмчтэй\s*чат\s*яаж|чатлах\s*заавар|doctor\s*chat\s*how|start\s*chat/i.test(
        blob,
      ) && !this.isLikelySymptom(text)
    );
  }

  private isLikelySymptom(text: string): boolean {
    const blob = this.toSearchableText(text);
    return SYMPTOM_INTENT_RULES.some((re) => re.test(blob));
  }

  private buildAppHelpResponse(trigger: string): ClinovaAgentResponse {
    const t = trigger.toLowerCase();
    let answer =
      'Clinova апп дээр доод цэснээс **Нүүр**, **Цаг**, **Эмчтэй чат**, **Профайл** руу шилжинэ. Цаг авахын тулд «Цаг» дээр дарж, салбар → тасаг → эмч → цаг сонгоно.';

    if (/чат|chat/i.test(t)) {
      answer =
        '**Эмчтэй чат**: доод цэснээс «Эмчтэй чат» дээр дарна. Эмч сонгож, мессеж бичнэ. Яаралтай бус зөвлөгөөнд тохиромжтой.';
    } else if (/профайл|profile|засах/i.test(t)) {
      answer =
        '**Профайл**: доод баруун «Профайл» таб дээр дарж хувийн мэдээллээ засварлана.';
    } else if (/миний\s*цаг|цаг\s*харагдах|upcoming/i.test(t)) {
      answer =
        'Захиалсан цагууд **Нүүр** дэлгэцийн доод хэсэг эсвэл **Цаг** хэсгээс харагдана. Дэлгэрэнгүйг профайл болон захиалгын түүхээс шалгана уу.';
    } else if (/цаг\s*яаж|booking|захиал/i.test(t)) {
      answer =
        '**Цаг авах**: «Цаг» → эхлээд үзүүлэх салбар, дараа нь тасаг, эмч, боломжтой цаг сонгоно. Шаардлагатай бол шалтгаанаа бичнэ.';
    }

    return {
      type: 'APP_HELP',
      answer,
      urgency: 'NONE',
      recommendedDepartment: null,
      recommendedDoctors: [],
      actions: [
        { label: 'Цаг захиалах', route: '/appointments-landing', params: {} },
        { label: 'Эмчтэй чат', route: '/chat-landing', params: {} },
        { label: 'Профайл', route: '/profile', params: {} },
      ],
      safetyDisclaimer: this.agentDisclaimer,
    };
  }

  private buildBookingHelpResponse(): ClinovaAgentResponse {
    return {
      type: 'BOOKING_HELP',
      answer:
        'Цаг авахын өмнө дараахыг бэлдээрэй: (1) Аль салбарт очиж үзүүлэх вэ? (2) Ямар тасаг/чиглэл вэ? (3) Хэзээ боломжтой вэ? (4) Ямар шинж, шалтгаанаар ирэх вэ? Бэлэн бол доорх товчоор захиалгын алхмууд руу орно.',
      urgency: 'NONE',
      recommendedDepartment: null,
      recommendedDoctors: [],
      actions: [
        { label: 'Цаг авах', route: '/appointments-landing', params: {} },
        { label: 'Шууд цаг сонгох', route: '/appointments/book', params: {} },
      ],
      safetyDisclaimer: this.agentDisclaimer,
    };
  }

  private buildChatHelpResponse(): ClinovaAgentResponse {
    return {
      type: 'CHAT_HELP',
      answer:
        'Эмчтэй чат нь эмчээс текстээр зөвлөгөө авахад зориулагдсан. Доод цэснээс «Эмчтэй чат» руу орж эмч сонгоно. Яаралтай тусламж шаардлагатай бол 102 руу залгана уу.',
      urgency: 'NONE',
      recommendedDepartment: null,
      recommendedDoctors: [],
      actions: [
        { label: 'Эмчтэй чат нээх', route: '/doctor-chat', params: {} },
        { label: 'Чат танилцуулга', route: '/chat-landing', params: {} },
      ],
      safetyDisclaimer: this.agentDisclaimer,
    };
  }

  private ruleBasedHealthQa(text: string, combined: string): string | null {
    const blob = this.toSearchableText(`${text}\n${combined}`);
    if (
      !/юу\s*анхаарах|яах\s*вэ|ямар\s*шинж|яагаад|what\s*to\s*do|how\s*to|signs\s*of|why\s*(is|does)/i.test(
        blob,
      ) &&
      this.isLikelySymptom(text)
    ) {
      return null;
    }

    if (/толгой\s*өвд|tolgoi.*(ovd|uwd|uvd)|headache/i.test(blob)) {
      return `Толгой өвдөхөд ихэнхдээ хангалттай ус уух, амрах, гэрлээ багасгах зэрэг тусалдаг. Хүчтэй өвдөлт, үзэгдэл өөрчлөгдөх, хүзүү дулдуйтвал эмчид яаралтай хандана уу.`;
    }
    if (/хүүхэд.*халуур|huuhed.*haluur|child.*fever|infant.*fever/i.test(blob)) {
      return `Хүүхэд халуурсан тохиолдолд хангалттай ус уулгаж, хувцас хөнгөн зөв өмсгөж, эмчийн заавраар л эм өгнө. Ухаан баларч, амьсгал хүндрэх, тууралттой халуурах зэрэг нь яаралтай үзлэг шаардаж болзошгүй.`;
    }
    if (/даралт.*ихсэх|daralt.*ihs|hypertension|blood\s*pressure.*sign/i.test(blob)) {
      return `Ихэвчлэн даралт ихсэхэд толгой өвдөх, толгой эргэх, нүдний доод хэсэг дарагдах мэт мэдрэмж гарч болно. Онош тавих, эмийн тунг тохируулах нь зөвхөн эмчийн үүрэг.`;
    }
    if (/ус\s*уух|us.*uuh|hydrat/i.test(blob)) {
      return `Хангалттай ус уух нь бодисын солилцоо, халуурсан үед дулааны зохицуулалтад тусалдаг. Өдөрт ойролцоогоор 1.5–2 л ус зорилтот боловч нөхцөлөөс хамаарна.`;
    }

    return null;
  }

  private async llmAgentTurn(
    text: string,
    combined: string,
    language?: string,
  ): Promise<ClinovaAgentResponse | null> {
    if (!this.client) return null;
    const lang = language === 'en' ? 'English' : 'Mongolian';
    try {
      const completion = await this.client.chat.completions.create({
        model: this.config.get<string>('OPENAI_MODEL') ?? 'gpt-4o-mini',
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: `You are Clinova healthcare assistant. Language: ${lang}.
Classify and answer. NEVER final diagnosis, NEVER medication doses. Use cautious phrasing.
Return ONLY JSON:
{
 "type":"HEALTH_QA"|"GENERAL"|"TRIAGE",
 "answer":"string",
 "urgency":"NONE"|"LOW"|"MEDIUM"|"HIGH"|"EMERGENCY",
 "recommendedDepartment": string or null,
 "recommendedSpecialty": string or null
}
If unsure use type GENERAL and short safe answer.`,
          },
          {
            role: 'user',
            content: `${combined.slice(0, 4500)}\n\n[normalized]\n${this
              .toSearchableText(combined)
              .slice(0, 1500)}`,
          },
        ],
      });
      const raw = completion.choices[0]?.message?.content?.trim();
      if (!raw) return null;
      const parsed = JSON.parse(raw) as {
        type?: string;
        answer?: string;
        urgency?: string;
        recommendedDepartment?: string | null;
      };
      const type = (parsed.type ?? 'GENERAL').toUpperCase();
      const allowed: AgentReplyType[] = [
        'HEALTH_QA',
        'GENERAL',
        'TRIAGE',
      ];
      const replyType = allowed.includes(type as AgentReplyType)
        ? (type as AgentReplyType)
        : 'GENERAL';
      const urgency = (parsed.urgency ?? 'NONE').toUpperCase();
      const u =
        urgency === 'LOW' ||
        urgency === 'MEDIUM' ||
        urgency === 'HIGH' ||
        urgency === 'EMERGENCY' ||
        urgency === 'NONE'
          ? urgency
          : 'NONE';

      if (replyType === 'TRIAGE' || u === 'HIGH' || u === 'EMERGENCY') {
        return null;
      }

      return {
        type: replyType,
        answer:
          parsed.answer ??
          'Уучлаарай, одоогоор дэлгэрэнгүй хариулж чадсангүй. Эмчид хандана уу.',
        urgency: u as UrgencyLevel | 'NONE',
        recommendedDepartment: parsed.recommendedDepartment ?? null,
        recommendedDoctors: [],
        actions: [
          { label: 'Эмчтэй чатлах', route: '/chat-landing', params: {} },
          { label: 'Цаг захиалах', route: '/appointments-landing', params: {} },
        ],
        safetyDisclaimer: this.agentDisclaimer,
      };
    } catch (e) {
      this.logger.warn(`llmAgentTurn: ${e}`);
      return null;
    }
  }

  private triageToAgentResponse(
    triage: Record<string, unknown>,
  ): ClinovaAgentResponse {
    const urgency = String(triage.urgency ?? 'MEDIUM').toUpperCase();
    if (
      urgency === 'EMERGENCY' ||
      triage.recommendedDepartment === 'Яаралтай тусламж'
    ) {
      return this.buildEmergencyAgentResponse();
    }

    const doctors = Array.isArray(triage.suggestedDoctors)
      ? (triage.suggestedDoctors as Array<Record<string, unknown>>)
      : [];
    const summary = String(triage.summary ?? '');
    const dept =
      triage.recommendedDepartment != null
        ? String(triage.recommendedDepartment)
        : null;
    const nextSteps = Array.isArray(triage.nextSteps)
      ? (triage.nextSteps as string[])
      : [];
    const answer = [summary, ...nextSteps.map((s) => `• ${s}`)]
      .filter((s) => s.length > 0)
      .join('\n');

    const actions: ClinovaAgentAction[] = [
      { label: 'Цаг захиалах', route: '/appointments-landing', params: {} },
      { label: 'Эмчтэй чатлах', route: '/chat-landing', params: {} },
    ];

    const first = doctors[0];
    const booking = first?.booking as Record<string, unknown> | undefined;
    if (booking && typeof booking === 'object') {
      const params: Record<string, unknown> = {};
      for (const k of ['branchId', 'departmentId', 'serviceId', 'doctorId']) {
        const v = booking[k];
        if (v != null && String(v) !== '' && String(v) !== 'null') {
          params[k] = v;
        }
      }
      if (Object.keys(params).length > 0) {
        actions.unshift({
          label: 'Цаг авах',
          route: '/appointments/book',
          params,
        });
      }
    }

    const docId = first?.id;
    if (docId != null && String(docId).length > 0) {
      actions.splice(2, 0, {
        label: 'Сонгосон эмчтэй чатлах',
        route: '/doctor-chat',
        params: { doctorId: String(docId) },
      });
    }

    const warn = Array.isArray(triage.safetyWarnings)
      ? (triage.safetyWarnings as string[]).join(' ')
      : '';

    return {
      type: 'TRIAGE',
      answer,
      urgency: urgency as UrgencyLevel,
      recommendedDepartment: dept,
      recommendedDoctors: doctors,
      actions,
      safetyDisclaimer: `${this.agentDisclaimer} ${warn}`.trim(),
    };
  }

  private composeSymptomText(input: TriageInput): string {
    const parts = [
      input.symptoms,
      input.duration ? `Хугацаа: ${input.duration}` : '',
      input.severity ? `Хүчтэй байдал: ${input.severity}` : '',
      input.age ? `Нас: ${input.age}` : '',
      input.gender ? `Хүйс: ${input.gender}` : '',
    ].filter((p) => p && p.trim().length > 0);
    return parts.join('\n');
  }

  private emergencyPayload(text: string) {
    return {
      urgency: 'EMERGENCY' as UrgencyLevel,
      summary:
        'Таны оруулсан шинж тэмдэг нь яаралтай тусламж шаардаж болзошгүй түвшинд хамаарах боломжтой. Дуудлагаар эсвэл ойрын эмнэлэгт нэн даруй хандана уу.',
      recommendedDepartment: 'Яаралтай тусламж',
      recommendedSpecialty: 'Emergency',
      nextSteps: [
        'Яаралтай тусламжийн утас 102 / 103 залгах',
        'Боломжтой бол ойрын эмнэлэгт очих',
        'Clinova цаг захиалга нь яаралтай тусламжийн орныг орлодоггүй',
      ],
      safetyWarnings: [
        'Энэ нь эмчийн онош биш. Амь насанд аюултай шинж илэрвэл зайлшгүй яаралтай тусламж авна уу.',
      ],
      suggestedDoctors: [],
      booking: null,
    };
  }

  private urgencyFromRules(text: string): UrgencyLevel {
    if (EMERGENCY_RULES.some((re) => re.test(text))) return 'EMERGENCY';
    if (HIGH_URGENCY_RULES.some((re) => re.test(text))) return 'HIGH';
    if (/дуутай|бага|хөнгөн|mild|slight/i.test(text)) return 'LOW';
    return 'MEDIUM';
  }

  private pickDepartment(
    departments: { id: string; name: string }[],
    text: string,
    llmHint?: string,
  ) {
    if (llmHint && llmHint.toLowerCase() !== 'general') {
      const h = llmHint.toLowerCase();
      const byHint = departments.find(
        (d) =>
          d.name.toLowerCase().includes(h) || h.includes(d.name.toLowerCase()),
      );
      if (byHint) return byHint;
    }

    for (const rule of DEPT_RULES) {
      if (rule.re.test(text)) {
        const d = departments.find((x) =>
          x.name.toLowerCase().includes(rule.deptIncludes.toLowerCase()),
        );
        if (d) return d;
      }
    }

    const internal = departments.find((d) =>
      d.name.toLowerCase().includes('internal'),
    );
    if (internal) return internal;

    return departments[0] ?? null;
  }

  private mergeNextSteps(
    fromLlm: string[] | undefined,
    urgency: UrgencyLevel,
    hasDoctors: boolean,
  ): string[] {
    const base = [...(fromLlm ?? [])];
    if (urgency === 'HIGH' || urgency === 'EMERGENCY') {
      base.unshift('Яаралтай тусламжийн шугамтай холбогдох');
    }
    if (hasDoctors) {
      if (!base.some((s) => s.includes('цаг') || s.includes('захиал'))) {
        base.push('Доорх эмчээс цаг авах');
      }
      if (!base.some((s) => s.includes('чат'))) {
        base.push('Эмчтэй чатлах');
      }
    }
    return base.slice(0, 6);
  }

  private async buildSuggestedDoctors(
    dept: { id: string; name: string },
    symptomText: string,
  ) {
    const doctors = await this.prisma.doctorProfile.findMany({
      where: { active: true, departmentId: dept.id },
      take: 8,
      orderBy: [{ experienceYears: 'desc' }, { createdAt: 'asc' }],
      include: {
        user: { select: { firstName: true, lastName: true } },
        branch: { select: { id: true, name: true } },
        department: { select: { id: true, name: true } },
        services: { take: 2, select: { serviceId: true } },
      },
    });

    if (doctors.length === 0) {
      const fallback = await this.prisma.doctorProfile.findMany({
        where: { active: true },
        take: 4,
        orderBy: [{ experienceYears: 'desc' }],
        include: {
          user: { select: { firstName: true, lastName: true } },
          branch: { select: { id: true, name: true } },
          department: { select: { id: true, name: true } },
          services: { take: 2, select: { serviceId: true } },
        },
      });
      return this.mapDoctorsToSuggestions(fallback, symptomText);
    }

    return this.mapDoctorsToSuggestions(doctors, symptomText);
  }

  private async mapDoctorsToSuggestions(
    doctors: Array<{
      id: string;
      branchId: string;
      departmentId: string;
      experienceYears: number;
      user: { firstName: string | null; lastName: string | null };
      branch: { id: string; name: string };
      department: { id: string; name: string };
      services: { serviceId: string }[];
    }>,
    _symptomText: string,
  ) {
    const out: Array<Record<string, unknown>> = [];
    for (const doctor of doctors) {
      let serviceId: string | null = doctor.services[0]?.serviceId ?? null;
      if (!serviceId) {
        const svc = await this.prisma.service.findFirst({
          where: {
            branchId: doctor.branchId,
            departmentId: doctor.departmentId,
          },
          select: { id: true },
        });
        serviceId = svc?.id ?? null;
      }

      let nextAvailableSlot: string | null = null;
      if (serviceId) {
        try {
          const base = new Date();
          base.setDate(base.getDate() + 1);
          base.setHours(0, 0, 0, 0);
          for (let i = 0; i < 14; i++) {
            const d = new Date(base);
            d.setDate(d.getDate() + i);
            const dateStr = d.toISOString().slice(0, 10);
            const slots = await this.appointments.getAvailableSlots({
              date: dateStr,
              doctorId: doctor.id,
              serviceId,
              branchId: doctor.branchId,
              departmentId: doctor.departmentId,
            });
            if (slots.length > 0) {
              nextAvailableSlot = String(slots[0].startsAt);
              break;
            }
          }
        } catch (e) {
          this.logger.warn(`Slot lookup failed for ${doctor.id}: ${e}`);
        }
      }

      const name =
        `${doctor.user.firstName ?? ''} ${doctor.user.lastName ?? ''}`.trim() ||
        'Эмч';
      const rating = Math.min(
        5,
        Math.round((3.6 + doctor.experienceYears * 0.06) * 10) / 10,
      );

      out.push({
        id: doctor.id,
        name,
        specialty: doctor.department.name,
        branch: doctor.branch.name,
        rating,
        experienceYears: doctor.experienceYears,
        nextAvailableSlot,
        booking: {
          branchId: doctor.branchId,
          departmentId: doctor.departmentId,
          serviceId,
          doctorId: doctor.id,
        },
      });
    }
    return out;
  }
}
