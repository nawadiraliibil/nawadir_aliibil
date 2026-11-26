// حركة مشي الجمل في شاشة التحميل: منقولة من ملف التصميم Nawader_Loading.html دون تغيير في
// الأرقام، ومقسمة إلى دوال نقية تكتب سمات عناصر SVG يمررها المكوّن.
import { MARK_PATH } from './splashArt'

export const WALK_PERIOD_MS = 2100
const TAU = 2 * Math.PI

// نقاط الرأس والرقبة: الكتف ثابت، ونقاط الوجه تدور معًا دورانًا صلبًا.
const fixed: string[] = []
const joints: { x: number; y: number; weight: number }[] = []
let end = 0
for (const match of MARK_PATH.matchAll(/(-?[\d.]+),(-?[\d.]+)/g)) {
  const x = Number(match[1])
  const y = Number(match[2])
  if (x <= 302 || y >= 295) continue
  const u = Math.min(1, (x - 302) / 72) * Math.min(1, (295 - y) / 38)
  fixed.push(MARK_PATH.slice(end, match.index))
  joints.push({ x, y, weight: u * u * (3 - 2 * u) })
  end = (match.index ?? 0) + match[0].length
}
const suffix = MARK_PATH.slice(end)

function nodPath(phase: number): string {
  const angle = 0.097 * Math.sin(TAU * 2 * phase - 0.48) + 0.021 * Math.sin(TAU * phase - 0.2) - 0.013
  const forward = 3 * Math.sin(TAU * 2 * phase - 0.84)
  const cosine = Math.cos(angle) - 1
  const sine = Math.sin(angle)
  let path = ''
  for (let i = 0; i < joints.length; i++) {
    const { x, y, weight } = joints[i]!
    const dx = x - 314
    const dy = y - 277
    const px = x + weight * (dx * cosine - dy * sine + forward)
    const py = y + weight * (dx * sine + dy * cosine)
    path += fixed[i]! + px.toFixed(2) + ',' + py.toFixed(2)
  }
  return path + suffix
}

export const GUSTS = [
  { id: 'breeze-low', x: 137, y: 380, travel: 85, rise: 8, delay: 0.17, opacity: 0.66 },
  { id: 'breeze-high', x: 424, y: 316, travel: 66, rise: 6, delay: 0.64, opacity: 0.58 },
  { id: 'breeze-dust', x: 239, y: 421, travel: 54, rise: 10, delay: 0.91, opacity: 0.67 },
] as const

export const LEGS = [
  { id: 'hind-far', back: true, root: [157, 295, 189, 298], foot: 170, offset: 0.46 },
  { id: 'fore-far', back: false, root: [276, 313, 312, 299], foot: 312, offset: 0.58 },
  { id: 'hind-near', back: true, root: [149, 294, 193, 297], foot: 162, offset: 0.96 },
  { id: 'fore-near', back: false, root: [273, 315, 316, 299], foot: 296, offset: 0.08 },
] as const

type Leg = (typeof LEGS)[number]

// ارتفاعات التلامس على حافة الكثيب.
const RIDGE: readonly [number, number][] = [
  [100, 462], [125, 461], [150, 458], [175, 453], [200, 448.6], [225, 443],
  [250, 437.4], [275, 432.6], [300, 428.4], [325, 425], [350, 422.5], [375, 422],
]

function ground(x: number): number {
  const i = RIDGE.findIndex((point) => point[0] >= x)
  if (i <= 0) return (i === 0 ? RIDGE[0]! : RIDGE[RIDGE.length - 1]!)[1]
  const [xa, ya] = RIDGE[i - 1]!
  const [xb, yb] = RIDGE[i]!
  return ya + ((yb - ya) * (x - xa)) / (xb - xa)
}

// كل قدم تمر بالارتكاز ثم التأرجح.
function legShape(leg: Leg, phase: number, bob: number): string {
  const p = (phase + leg.offset) % 1
  const stance = 0.6
  const swing = Math.max(0, (p - stance) / (1 - stance))
  const lift = Math.sin(Math.PI * swing) ** 2
  const reach = leg.back ? 30 : 33
  const stride = p < stance ? Math.cos((Math.PI * p) / stance) : -Math.cos(Math.PI * swing)
  const x = leg.foot + reach * stride
  const y = ground(x) - 3 - bob - 20 * lift
  const [a, ay, b, by] = leg.root
  const mid = (a + b) / 2
  const knee = mid + (x - mid) * 0.48 + (leg.back ? -13 : 1) + (leg.back ? 7 : 15) * lift
  const ky = ay + (y - ay) * 0.44 - 7 * lift
  const ankle = x - (leg.back ? 9 : 6) - 8 * lift
  const hy = y - 21 - 5 * lift
  const rear = leg.back ? 7 : 5
  return [
    'M', a, ay, 'C', a - 2, ay + 16, knee - 8, ky - 12, knee - rear, ky,
    'S', ankle - 5, hy - 6, ankle - 3, hy, 'Q', ankle - 2, hy + 5, x - 6, y - 8,
    'Q', x - 9, y - 1, x - 3, y, 'Q', x + 9, y + 1, x + 15, y - 2,
    'Q', x + 17, y - 6, x + 8, y - 10, 'Q', ankle + 3, hy + 4, ankle + 5, hy,
    'L', knee + 7, ky + 5, 'Q', knee + 10, ky, knee + 9, ky - 7,
    'C', knee + 9, ky - 16, b - 4, by + 16, b, by,
  ].join(' ')
}

export interface WalkNodes {
  animal: SVGGElement
  upper: SVGPathElement
  gusts: SVGGElement[]
  legs: SVGPathElement[]
}

/** يرسم إطارًا واحدًا عند الزمن t (ملّي ثانية). */
export function paintWalk(nodes: WalkNodes, t: number): void {
  const phase = (t % WALK_PERIOD_MS) / WALK_PERIOD_MS
  nodes.upper.setAttribute('d', nodPath(phase))
  GUSTS.forEach((g, i) => {
    const node = nodes.gusts[i]!
    const p = (phase + g.delay) % 1
    const x = g.x - g.travel * p
    const y = g.y - g.rise * Math.sin(Math.PI * p)
    node.setAttribute('transform', 'translate(' + x.toFixed(2) + ' ' + y.toFixed(2) + ')')
    node.setAttribute('opacity', (g.opacity * Math.sin(Math.PI * p) ** 2).toFixed(3))
  })
  const bob = 1.9 * Math.sin(TAU * 2 * phase) - 1
  nodes.animal.setAttribute('transform', 'translate(0 ' + bob + ')')
  LEGS.forEach((leg, i) => nodes.legs[i]!.setAttribute('d', legShape(leg, phase, bob)))
}
