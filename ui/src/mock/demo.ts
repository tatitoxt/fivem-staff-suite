import type { Alert, AuditEntry, Priority, StaffStat, Ticket, TicketState } from '../types';
import { append } from './chain';

// Datos demo deterministas (relativos a `now`) para el harness de dev.
export const ME = 'Fausto';

export const ALL_CAPS = [
  'report.view', 'report.claim', 'report.resolve', 'report.message',
  'report.export',
  'staff.chat',
  'player.profile.view', 'player.profile.note',
  'player.online.view',
  'mod.template',
  'mod.goto', 'mod.bring', 'mod.spectate', 'mod.freeze', 'mod.heal',
  'mod.revive', 'mod.kick', 'mod.warn', 'mod.ban',
  'ban.view', 'ban.revoke',
  'audit.view', 'audit.verify', 'audit.export',
  'staff.duty', 'staff.analytics', 'staff.announce', 'admin.config', 'admin.permissions',
  'staff.waypoint',
  'staff.noclip', 'staff.invisible',
  'staff.analytics.export',
];

const P = {
  tomi: 'license:3f9a1c27e0b44d6a9c1e5b7f20a8d3c4e6f1b2a9',
  meli: 'license:a81d0c3e9f2b47c6b5e8d1f0a3c2b9e7d4f6a1c8',
  juanma: 'license:5c7e2a9d1b3f4e8c0a6d2b9f7e1c3a5d8b0f4e2c',
  rocio: 'license:e2b9f4c1a7d3e8b0c5f2a9d6e1b4c7f3a0d8e5b2',
  gaston: 'license:9d4f1e7b2c8a3d0f6e5b1c9a7d2f8e4b0c3a6d1f',
  vale: 'license:1b6e3c9f0a4d7e2b8c5f1a6d3e9b0c7f4a2d8e5b',
  bruno: 'license:7a2d5f8e1c4b9a3d6f0e2c7b5a8d1f4e9c3b6a0d',
};

export const STAFF = ['Nahuel_R', 'Sofi.Mod', 'Kevo', 'Lu.Helper', 'Martin_B', ME];

interface DemoTicket {
  reporter: string; category: string; priority: Priority; state: TicketState; claimer: string | null;
  age: number; description: string; resolution?: string; rating?: number;
  messages?: { who: string; body: string; ago: number; internal?: boolean }[];
}

const TICKETS: DemoTicket[] = [
  { reporter: P.tomi, category: 'player', priority: 'urgent', state: 'open', claimer: null, age: 4 * 60,
    description: 'Un jugador está atropellando gente a propósito en la plaza de Legion. Ya van tres veces.',
    messages: [{ who: P.tomi, body: 'Es el del Sultan azul, sigue dando vueltas.', ago: 3 * 60 }] },
  { reporter: P.meli, category: 'bug', priority: 'high', state: 'in_progress', claimer: 'Sofi.Mod', age: 22 * 60,
    description: 'Después de morir en el hospital no me aparece el inventario y perdí el teléfono.',
    messages: [
      { who: 'Sofi.Mod', body: 'Hola Meli, ¿me decís a qué hora fue más o menos?', ago: 18 * 60 },
      { who: P.meli, body: 'Hace unos 20 minutos, justo después del reinicio.', ago: 16 * 60 },
      { who: 'Sofi.Mod', body: 'Revisar logs de ox_inventory antes de devolver nada.', ago: 15 * 60, internal: true },
    ] },
  { reporter: P.juanma, category: 'staff', priority: 'high', state: 'claimed', claimer: 'Nahuel_R', age: 48 * 60,
    description: 'Un admin me sacó 50.000 del banco sin explicarme nada. Quiero saber quién fue.',
    messages: [
      { who: 'Nahuel_R', body: 'Estoy revisando la auditoría, te escribo en un rato.', ago: 40 * 60 },
      { who: 'Nahuel_R', body: 'Hay un givemoney negativo de Kevo a las 14:10. Cruzar con su turno.', ago: 38 * 60, internal: true },
    ] },
  { reporter: P.rocio, category: 'question', priority: 'normal', state: 'open', claimer: null, age: 9 * 60,
    description: '¿Cómo hago para postularme a la policía? No encuentro el formulario en Discord.' },
  { reporter: P.gaston, category: 'player', priority: 'normal', state: 'resolved', claimer: 'Kevo', age: 3 * 3600,
    description: 'Me robaron el auto en el estacionamiento del hospital y el tipo se desconectó.',
    resolution: 'Se devolvió el vehículo y se advirtió al jugador por combat logging.', rating: 5,
    messages: [
      { who: 'Kevo', body: 'Ya lo encontré, te lo dejo en el garaje de Pillbox.', ago: 2.6 * 3600 },
      { who: P.gaston, body: 'Gracias, crack.', ago: 2.5 * 3600 },
    ] },
  { reporter: P.vale, category: 'bug', priority: 'low', state: 'open', claimer: null, age: 35 * 60,
    description: 'El cajero de Vespucci no deja depositar, se queda cargando.' },
  { reporter: P.bruno, category: 'player', priority: 'high', state: 'reopened', claimer: null, age: 5 * 3600,
    description: 'Me siguen insultando por radio después del warn. Mismo jugador de ayer.',
    messages: [{ who: P.bruno, body: 'Lo reabro porque volvió a pasar hace 10 minutos.', ago: 12 * 60 }] },
  { reporter: P.tomi, category: 'other', priority: 'low', state: 'closed', claimer: 'Lu.Helper', age: 26 * 3600,
    description: 'Sugerencia: agregar más estacionamientos cerca del Mechanic.', resolution: 'Pasado al equipo de mapeo.', rating: 4 },
  { reporter: P.meli, category: 'player', priority: 'urgent', state: 'claimed', claimer: ME, age: 6 * 60,
    description: 'Hay alguien con un helicóptero militar disparando en el centro. Seguro es mod menu.',
    messages: [
      { who: ME, body: 'Voy para allá, no te muevas.', ago: 5 * 60 },
      { who: ME, body: 'Si se confirma, ban permanente y captura del log.', ago: 4 * 60, internal: true },
    ] },
  { reporter: P.rocio, category: 'staff', priority: 'normal', state: 'resolved', claimer: 'Nahuel_R', age: 7 * 3600,
    description: 'Un helper me teletransportó en medio de un rol sin avisar.',
    resolution: 'Se habló con el helper y se documentó en su legajo.', rating: 3 },
  { reporter: P.juanma, category: 'bug', priority: 'normal', state: 'closed', claimer: 'Martin_B', age: 30 * 3600,
    description: 'La puerta del taller de Bennys queda trabada.', resolution: 'Reportado al dev del MLO.' },
  { reporter: P.gaston, category: 'question', priority: 'low', state: 'open', claimer: null, age: 70 * 60,
    description: '¿Se puede transferir una propiedad a otro personaje?' },
];

export function buildTickets(now: number): Ticket[] {
  return TICKETS.map((d, i) => ({
    id: i + 1,
    reporter: d.reporter,
    category: d.category,
    priority: d.priority,
    state: d.state,
    claimer: d.claimer,
    created_ts: Math.round(now - d.age),
    updated_ts: Math.round(now - (d.messages?.length ? d.messages[d.messages.length - 1].ago : d.age)),
    description: d.description,
    messages: (d.messages ?? []).map((m) => ({ author: m.who, body: m.body, ts: Math.round(now - m.ago), internal: !!m.internal })),
    resolution: d.resolution ?? null,
    rating: d.rating ?? null,
  }));
}

type Ev = [ago: number, actor: string, action: string, target: string, reason: string, payload?: Record<string, unknown>];

const EVENTS: Ev[] = [
  [6.0 * 3600, 'Nahuel_R', 'duty.in', 'Nahuel_R', ''],
  [5.9 * 3600, 'Kevo', 'duty.in', 'Kevo', ''],
  [5.8 * 3600, 'Nahuel_R', 'perm_grant', 'Sofi.Mod', 'Ascenso a moderadora', { cap: 'mod.kick' }],
  [5.6 * 3600, P.bruno, 'ticket_create', P.bruno, '', { ticket: 7 }],
  [5.5 * 3600, 'Kevo', 'ticket_claim', 'ticket:7', ''],
  [5.4 * 3600, 'Kevo', 'mod_warn', P.vale, 'Insultos por radio'],
  [5.2 * 3600, 'Kevo', 'ticket_resolve', 'ticket:7', 'Warn aplicado'],
  [5.0 * 3600, 'Sofi.Mod', 'duty.in', 'Sofi.Mod', ''],
  [4.8 * 3600, 'Kevo', 'cmd_givemoney', P.juanma, '', { amount: -50000 }],
  [4.6 * 3600, 'Lu.Helper', 'duty.in', 'Lu.Helper', ''],
  [4.4 * 3600, 'Martin_B', 'duty.in', 'Martin_B', ''],
  [4.3 * 3600, 'Martin_B', 'perm_grant', 'Martin_B', '', { cap: 'mod.ban' }],
  [4.1 * 3600, 'Kevo', 'mod_kick', P.bruno, 'Combat logging reiterado'],
  [4.0 * 3600, 'Kevo', 'mod_ban', P.vale, 'Mod menu detectado', { duration: 'perm' }],
  [3.95 * 3600, 'Kevo', 'mod_ban', P.tomi, 'Evasión de ban'],
  [3.9 * 3600, 'Kevo', 'mod_ban', P.rocio, 'RDM'],
  [3.85 * 3600, 'Kevo', 'mod_ban', P.gaston, 'RDM'],
  [3.8 * 3600, 'Kevo', 'mod_ban', P.meli, 'Metagaming'],
  [3.5 * 3600, 'Nahuel_R', 'mod_unban', P.meli, 'Ban sin pruebas, revertido'],
  [3.0 * 3600, P.gaston, 'ticket_create', P.gaston, '', { ticket: 5 }],
  [2.9 * 3600, 'Kevo', 'ticket_claim', 'ticket:5', ''],
  [2.8 * 3600, 'Kevo', 'mod_goto', P.gaston, ''],
  [2.7 * 3600, 'Kevo', 'mod_freeze', P.juanma, 'Investigación de robo'],
  [2.5 * 3600, 'Kevo', 'ticket_resolve', 'ticket:5', 'Vehículo devuelto'],
  [2.2 * 3600, 'Lu.Helper', 'mod_heal', P.rocio, ''],
  [2.0 * 3600, 'Sofi.Mod', 'cmd_setjob', P.bruno, 'Ingreso a mecánicos', { job: 'mechanic', grade: 1 }],
  [1.8 * 3600, 'Martin_B', 'cmd_giveitem', 'Martin_B', '', { item: 'weapon_pistol', count: 1 }],
  [1.5 * 3600, 'Kevo', 'duty.out', 'Kevo', ''],
  [1.2 * 3600, 'Nahuel_R', 'audit_verify', '', 'ok'],
  [1.1 * 3600, 'Lu.Helper', 'duty.out', 'Lu.Helper', ''],
  [58 * 60, P.juanma, 'ticket_create', P.juanma, '', { ticket: 3 }],
  [40 * 60, 'Nahuel_R', 'ticket_claim', 'ticket:3', ''],
  [35 * 60, P.vale, 'ticket_create', P.vale, '', { ticket: 6 }],
  [30 * 60, 'Sofi.Mod', 'mod_bring', P.meli, ''],
  [22 * 60, P.meli, 'ticket_create', P.meli, '', { ticket: 2 }],
  [18 * 60, 'Sofi.Mod', 'ticket_claim', 'ticket:2', ''],
  [12 * 60, P.bruno, 'ticket_reopen', 'ticket:7', ''],
  [9 * 60, P.rocio, 'ticket_create', P.rocio, '', { ticket: 4 }],
  [6 * 60, P.meli, 'ticket_create', P.meli, '', { ticket: 9 }],
  [5.5 * 60, ME, 'ticket_claim', 'ticket:9', ''],
  [4 * 60, P.tomi, 'ticket_create', P.tomi, '', { ticket: 1 }],
];

export function buildAudit(now: number): AuditEntry[] {
  const entries: AuditEntry[] = [];
  for (const [ago, actor, action, target, reason, payload] of EVENTS) {
    append(entries, { ts: Math.round(now - ago), actor, action, target, reason, payload: payload ? JSON.stringify(payload) : '' });
  }
  return entries;
}

export function buildStaff(): StaffStat[] {
  return [
    { actor: 'Nahuel_R', on_duty: true, duty_hours: 6.0, sessions: 41, resolved: 128, avg_response: 142, avg_rating: 4.8 },
    { actor: 'Sofi.Mod', on_duty: true, duty_hours: 5.0, sessions: 33, resolved: 96, avg_response: 188, avg_rating: 4.6 },
    { actor: 'Kevo', on_duty: false, duty_hours: 4.4, sessions: 52, resolved: 87, avg_response: 95, avg_rating: 3.9 },
    { actor: 'Lu.Helper', on_duty: false, duty_hours: 3.5, sessions: 19, resolved: 34, avg_response: 260, avg_rating: 4.4 },
    { actor: 'Martin_B', on_duty: true, duty_hours: 4.4, sessions: 12, resolved: 21, avg_response: 410, avg_rating: 4.1 },
    { actor: ME, on_duty: false, duty_hours: 2.1, sessions: 8, resolved: 15, avg_response: 120, avg_rating: 4.9 },
  ];
}

export function buildAlerts(now: number): Alert[] {
  return [
    { id: 'a1', kind: 'mass_bans', severity: 'high', actor: 'Kevo', ts: Math.round(now - 3.8 * 3600), vars: { n: 5, min: 12 } },
    { id: 'a2', kind: 'self_grant', severity: 'medium', actor: 'Martin_B', ts: Math.round(now - 4.3 * 3600), vars: { cap: 'mod.ban' } },
  ];
}

export const TAMPER_SEQ = 27;
