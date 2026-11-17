/* إضافة محلية بلا اعتماديات أو شبكة. كل الكتابة تمر بفحص كامل ثم دفعة متزامنة. */
figma.showUI(__html__, { width: 760, height: 680, themeColors: true });

const VERSION = 1;
const KEY = "codex-local-workspace-v1";
const MIXED = { $mixed: true };
const ENUMS = {
  textAlignHorizontal: ["LEFT", "CENTER", "RIGHT", "JUSTIFIED"],
  textAlignVertical: ["TOP", "CENTER", "BOTTOM"],
  layoutMode: ["NONE", "HORIZONTAL", "VERTICAL"],
  layoutWrap: ["NO_WRAP", "WRAP"],
  primaryAxisAlignItems: ["MIN", "CENTER", "MAX", "SPACE_BETWEEN"],
  counterAxisAlignItems: ["MIN", "CENTER", "MAX", "BASELINE"],
  counterAxisAlignContent: ["AUTO", "SPACE_BETWEEN"],
  primaryAxisSizingMode: ["FIXED", "AUTO"],
  counterAxisSizingMode: ["FIXED", "AUTO"],
  layoutAlign: ["INHERIT", "STRETCH", "MIN", "CENTER", "MAX"],
  layoutPositioning: ["AUTO", "ABSOLUTE"]
};
const NUMBERS = ["itemSpacing", "counterAxisSpacing", "paddingLeft", "paddingRight",
  "paddingTop", "paddingBottom", "cornerRadius", "topLeftRadius", "topRightRadius",
  "bottomLeftRadius", "bottomRightRadius", "layoutGrow", "opacity"];
const BINDABLE = NUMBERS.filter(p => !["layoutGrow"].includes(p));
const EDITABLE = ["characters", "fills", "strokes", ...Object.keys(ENUMS), ...NUMBERS];
const CONTEXT = ["x", "y", "width", "height", "rotation", "visible", "locked", "name",
  "fontName", "fontSize", "fontWeight", "textAutoResize", "lineHeight", "letterSpacing",
  "paragraphSpacing", "textStyleId", "fillStyleId", "strokeStyleId", "effectStyleId",
  "effects", "strokeWeight", "constraints", "componentProperties", "componentPropertyReferences",
  "variantProperties", "overrides", "explicitVariableModes"];
let baseline = null;
let pending = null;
let busy = false;

function fail(message) { throw new Error(message); }
function plain(value) {
  if (value === figma.mixed || typeof value === "symbol") return MIXED;
  if (value === undefined) return null;
  return JSON.parse(JSON.stringify(value));
}
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") {
    const out = {};
    Object.keys(value).sort().forEach(k => { out[k] = canonical(value[k]); });
    return out;
  }
  return value;
}
function same(a, b) { return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b)); }
function uuid() {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
    const r = Math.floor(Math.random() * 16);
    return (c === "x" ? r : (r & 3) | 8).toString(16);
  });
}
function identity() {
  const raw = figma.root.getPluginData(KEY);
  if (!raw) return null;
  return JSON.parse(raw);
}
function send(type, data) { figma.ui.postMessage({ type, ...data }); }
function hasMixed(value) { return value && value.$mixed === true; }
function aliases(value, found = []) {
  if (!value || typeof value !== "object") return found;
  if (value.type === "VARIABLE_ALIAS" && typeof value.id === "string") found.push(value.id);
  else Object.values(value).forEach(v => aliases(v, found));
  return found;
}
function bindingState(node, property, runs) {
  const fields = [property];
  if (property === "cornerRadius") fields.push("topLeftRadius", "topRightRadius", "bottomLeftRadius", "bottomRightRadius");
  const direct = {};
  fields.forEach(p => { if (node.boundVariables && node.boundVariables[p]) direct[p] = plain(node.boundVariables[p]); });
  const paints = ["fills", "strokes"].includes(property) ? plain(node[property]) : null;
  const text = node.type === "TEXT" ? (runs || textRuns(node)).map(r => ({ start: r.start, end: r.end, boundVariables: r.boundVariables || {} })) : [];
  return { direct, paintAliases: aliases(paints), text };
}
function textRuns(node) {
  if (!node.characters.length) return [];
  return plain(node.getStyledTextSegments(["fontName", "fontSize", "fontWeight", "textDecoration",
    "textCase", "lineHeight", "letterSpacing", "fills", "textStyleId", "fillStyleId",
    "boundVariables", "hyperlink"]));
}
function snapshotSync(node) {
  const properties = {};
  for (const p of [...EDITABLE, ...CONTEXT]) if (p in node) properties[p] = plain(node[p]);
  const path = [];
  let parent = node.parent;
  while (parent) { path.push({ id: parent.id, type: parent.type, name: parent.name }); parent = parent.parent; }
  const runs = node.type === "TEXT" ? textRuns(node) : null;
  const propertyBindings = {};
  EDITABLE.forEach(p => { if (p in node) propertyBindings[p] = bindingState(node, p, runs); });
  return {
    id: node.id, name: node.name, type: node.type, parentId: node.parent ? node.parent.id : null,
    children: "children" in node ? node.children.map(c => c.id) : [], path,
    properties, boundVariables: plain(node.boundVariables || {}),
    textRuns: runs, propertyBindings, componentKey: "key" in node ? node.key : null
  };
}
async function snapshot(node) {
  let mainComponent = null;
  if (node.type === "INSTANCE") {
    const main = await node.getMainComponentAsync();
    if (main) mainComponent = { id: main.id, key: main.key, name: main.name, remote: main.remote };
  }
  return { ...snapshotSync(node), mainComponent };
}
function syncMatches(node, original) {
  const copy = { ...original };
  delete copy.mainComponent;
  return same(snapshotSync(node), copy);
}
async function exportSelection() {
  const work = identity();
  if (!work) fail("هيّئ نسخة العمل أولًا. افتح النسخة المستقلة ثم اضغط «هوية جديدة لنسخة العمل».");
  if (!figma.currentPage.selection.length) fail("حدد إطارًا أو طبقة واحدة على الأقل.");
  pending = null;
  const selected = [...figma.currentPage.selection];
  const nodes = [];
  const visited = new Set();
  async function visit(node) {
    if (visited.has(node.id)) return;
    visited.add(node.id);
    if (nodes.length >= 10000) fail("التحديد أكبر من 10000 طبقة؛ صدّر نطاقًا أصغر.");
    nodes.push(await snapshot(node));
    if ("children" in node) for (const child of node.children) await visit(child);
  }
  for (const node of selected) await visit(node);
  const variableIds = [...new Set(aliases(nodes))];
  const variables = [];
  for (const id of variableIds) {
    const v = await figma.variables.getVariableByIdAsync(id);
    variables.push(v ? { id: v.id, key: v.key, name: v.name, resolvedType: v.resolvedType,
      variableCollectionId: v.variableCollectionId, valuesByMode: plain(v.valuesByMode), remote: v.remote } : { id, unavailable: true });
  }
  const data = { schema: "codex-figma-selection", version: VERSION, workspaceId: work.workspaceId,
    exportId: uuid(), fileKey: figma.fileKey || null, pageId: figma.currentPage.id,
    exportedAt: new Date().toISOString(), selection: selected.map(n => n.id), nodes, variables };
  // نعيد قراءة كل عنصر بعد القراءات غير المتزامنة لمنع تصدير لقطة تحركت أثناء جمعها.
  for (const original of nodes) {
    const live = await figma.getNodeByIdAsync(original.id);
    if (!live || !same(await snapshot(live), original)) fail("تغير التصميم أثناء التصدير؛ أعد التصدير.");
  }
  for (const node of selected) if (node.removed) fail("حُذف التحديد أثناء التصدير.");
  baseline = data;
  send("export", { data });
}
function checkValue(property, value, before) {
  if (property === "characters") {
    if (typeof value !== "string" || value.length > 100000) fail("النص يجب أن يكون سلسلة لا تتجاوز 100000 وحدة UTF-16.");
  } else if (ENUMS[property]) {
    if (!ENUMS[property].includes(value)) fail("قيمة غير مدعومة لـ " + property);
  } else if (NUMBERS.includes(property)) {
    if (typeof value !== "number" || !Number.isFinite(value)) fail("قيمة رقمية غير صالحة: " + property);
    if (property !== "itemSpacing" && value < 0) fail("هذه الخاصية لا تقبل قيمة سالبة: " + property);
    if (property === "opacity" && value > 1) fail("opacity بين 0 و1.");
    if (property === "layoutGrow" && ![0, 1].includes(value)) fail("layoutGrow يساوي 0 أو 1.");
  } else if (["fills", "strokes"].includes(property)) {
    if (!Array.isArray(value) || !Array.isArray(before) || value.length !== before.length) fail("تعديل الألوان يحافظ على عدد الطلاءات.");
    value.forEach((paint, i) => {
      if (paint.type !== "SOLID" || before[i].type !== "SOLID") fail("تحرير الألوان يدعم طلاء SOLID فقط.");
      if (!paint.color || Object.keys(paint.color).sort().join() !== "b,g,r" ||
        !Object.values(paint.color).every(v => typeof v === "number" && Number.isFinite(v) && v >= 0 && v <= 1)) fail("RGB يجب أن يكون بين 0 و1.");
      if (paint.opacity !== undefined && (typeof paint.opacity !== "number" || !Number.isFinite(paint.opacity) || paint.opacity < 0 || paint.opacity > 1)) fail("شفافية الطلاء غير صالحة.");
      const stripped = p => { const copy = { ...p }; delete copy.color; delete copy.opacity; return copy; };
      if (!same(stripped(paint), stripped(before[i]))) fail("set يغير اللون والشفافية فقط؛ استخدم paintBinding لتغيير الارتباط.");
    });
  }
}
function locked(node) {
  let n = node;
  while (n && n.type !== "DOCUMENT") { if (n.locked) return true; n = n.parent; }
  return false;
}
function isBound(node, p) {
  const state = bindingState(node, p);
  // روابط النص على مستوى النطاقات: نحمي الطلاء والنص من التسطيح.
  return aliases(state.direct).length > 0 || state.paintAliases.length > 0 ||
    (node.type === "TEXT" && ["characters", "fills"].includes(p) && aliases(state.text).length > 0);
}
function styleLinked(node, p) {
  return ["fills", "strokes"].includes(p) &&
    (node[p === "fills" ? "fillStyleId" : "strokeStyleId"] !== "" ||
      (node.type === "TEXT" && p === "fills" && textRuns(node).some(r => r.fillStyleId)));
}
function checkHeader(patch) {
  if (!patch || patch.schema !== "codex-figma-patch" || patch.version !== VERSION) fail("صيغة ملف التعديلات أو إصدارها غير صحيح.");
  const work = identity();
  if (!baseline) fail("أعد تصدير التحديد في هذه الجلسة قبل استيراد التعديلات.");
  if (!work || patch.workspaceId !== work.workspaceId || patch.workspaceId !== baseline.workspaceId) fail("الملف يخص نسخة عمل أخرى.");
  if (patch.exportId !== baseline.exportId) fail("الملف ليس مبنيًا على آخر تصدير.");
  if (baseline.fileKey !== (figma.fileKey || null)) fail("تغير ملف Figma المفتوح.");
  if (baseline.pageId !== figma.currentPage.id) fail("ارجع إلى صفحة التصدير قبل التطبيق.");
  if (!Array.isArray(patch.operations) || patch.operations.length < 1 || patch.operations.length > 500) fail("يلزم من 1 إلى 500 عملية.");
}
async function makePlan(patch) {
  checkHeader(patch);
  const rows = [], writes = [], seen = new Set(), checked = new Map();
  for (const op of patch.operations) {
    const row = { nodeId: op && op.nodeId, name: op && op.nodeId, property: op && op.property,
      before: op && op.before, after: op && op.after, status: "ready", reason: "" };
    rows.push(row);
    try {
      if (!op || typeof op !== "object" || !["set", "bind", "paintBinding"].includes(op.kind)) fail("نوع العملية غير مدعوم.");
      const p = op.property;
      if (!EDITABLE.includes(p)) fail("خاصية غير مسموحة.");
      const key = op.nodeId + ":" + p;
      if (seen.has(key)) fail("عملية مكررة للخاصية نفسها؛ اجمعها في عملية واحدة.");
      seen.add(key);
      if ((p === "cornerRadius" && NUMBERS.filter(x => x.endsWith("Radius") && x !== p).some(x => seen.has(op.nodeId + ":" + x))) ||
        (p.endsWith("Radius") && p !== "cornerRadius" && seen.has(op.nodeId + ":cornerRadius"))) fail("لا تجمع cornerRadius مع زواياه الفردية.");
      const original = baseline.nodes.find(n => n.id === op.nodeId);
      if (!original) fail("العنصر خارج آخر تحديد مُصدّر.");
      row.name = original.name;
      const node = await figma.getNodeByIdAsync(op.nodeId);
      if (!node || node.removed) fail("العنصر غير موجود.");
      if (!(p in original.properties) || !(p in node)) fail("الخاصية غير متاحة لهذا النوع.");
      row.before = plain(node[p]);
      row.bindings = bindingState(node, p);
      if (!checked.has(node.id)) checked.set(node.id, same(await snapshot(node), original));
      if (!checked.get(node.id)) fail("تغير العنصر أو سياقه أو ارتباطه منذ التصدير؛ أعد التصدير.");
      if (!Object.prototype.hasOwnProperty.call(op, "before") || !same(op.before, original.properties[p]) || !same(op.before, row.before)) fail("القيمة الحالية لا تطابق before أو لقطة التصدير.");
      if (!Object.prototype.hasOwnProperty.call(op, "beforeBindings") || !same(op.beforeBindings, row.bindings)) fail("beforeBindings لا يطابق الارتباطات الحالية.");
      if (locked(node)) fail("العنصر أو أحد آبائه مقفل.");
      if (styleLinked(node, p)) fail("الطلاء مرتبط بنمط؛ تم إيقاف العملية للحفاظ على النمط.");
      let value;
      let variable = null;
      if (op.kind === "set") {
        if (!Object.prototype.hasOwnProperty.call(op, "after")) fail("after مطلوب.");
        checkValue(p, op.after, op.before);
        if (isBound(node, p)) { row.status = "skip"; row.reason = "خاصية مرتبطة بمتغير؛ يلزم bind أو paintBinding صريح."; continue; }
        if (hasMixed(row.before)) fail("خاصية مختلطة؛ حرر نطاقًا متجانسًا لحماية التنسيق.");
        if (p === "characters" && original.textRuns.length > 1) fail("النص متعدد التنسيق؛ لا يستبدل كاملًا لتجنب فقد تنسيق النطاقات.");
        value = plain(op.after);
      } else {
        if (op.variableId !== null && typeof op.variableId !== "string") fail("variableId مطلوب: معرف أو null لفك الارتباط.");
        if (op.variableId !== null) {
          variable = await figma.variables.getVariableByIdAsync(op.variableId);
          if (!variable) fail("المتغير غير موجود أو غير متاح محليًا.");
        }
        if (op.kind === "bind") {
          if (!BINDABLE.includes(p) || typeof node.setBoundVariable !== "function") fail("الربط المباشر مدعوم للخصائص الرقمية المحددة فقط.");
          if (variable && variable.resolvedType !== "FLOAT") fail("هذه الخاصية تحتاج متغير FLOAT.");
          if (p === "cornerRadius") fail("اربط كل زاوية فرديًا بدل cornerRadius.");
        } else {
          if (!["fills", "strokes"].includes(p) || !Array.isArray(row.before) || !Number.isInteger(op.paintIndex) || !row.before[op.paintIndex] || row.before[op.paintIndex].type !== "SOLID") fail("paintBinding يحتاج طلاء SOLID وفهرس paintIndex صالحًا.");
          if (variable && variable.resolvedType !== "COLOR") fail("لون الطلاء يحتاج متغير COLOR.");
          value = plain(row.before);
          value[op.paintIndex] = figma.variables.setBoundVariableForPaint(value[op.paintIndex], "color", variable);
        }
        row.after = { variableId: op.variableId, variableName: variable ? variable.name : "فك الارتباط مع إبقاء القيمة المحلولة", paintIndex: op.paintIndex };
      }
      writes.push({ node, op, value, variable });
    } catch (error) { row.status = "error"; row.reason = error.message; }
  }
  return { rows, writes, ok: !rows.some(r => r.status === "error") };
}
async function loadFonts(writes) {
  const fonts = new Map();
  for (const { node } of writes) {
    if (node.type !== "TEXT") continue;
    if (node.hasMissingFont) fail("خط مفقود في «" + node.name + "»؛ ثبّته أولًا.");
    const list = node.characters.length ? node.getRangeAllFontNames(0, node.characters.length) : [node.fontName];
    for (const font of list) {
      if (font === figma.mixed) fail("لا يمكن تحديد خط النص الفارغ.");
      fonts.set(font.family + "\u0000" + font.style, font);
    }
  }
  await Promise.all([...fonts.values()].map(font => figma.loadFontAsync(font)));
}
async function applyPending() {
  if (!pending) fail("استورد ملفًا واعرض معاينته أولًا.");
  let plan = await makePlan(pending);
  if (!plan.ok) { send("preview", { rows: plan.rows, ok: false }); fail("تعارض: لم يتغير أي عنصر."); }
  await loadFonts(plan.writes);
  // فحص ثانٍ بعد تحميل الخطوط. لا await داخل مرحلة الكتابة.
  plan = await makePlan(pending);
  if (!plan.ok) { send("preview", { rows: plan.rows, ok: false }); fail("تغير التصميم أثناء التحضير؛ لم تطبق الدفعة."); }
  if (!plan.writes.length) { pending = null; send("done", { message: "كل العمليات متجاوزة؛ لم يتغير التصميم." }); return; }
  // حاجز متزامن لكل العناصر: يمنع سباق تعديل عنصر سابق أثناء انتظار قراءة عنصر لاحق.
  for (const { node } of plan.writes) {
    if (node.removed || locked(node) || !syncMatches(node, baseline.nodes.find(n => n.id === node.id))) fail("تغير عنصر أثناء الفحص النهائي؛ أعد التصدير.");
  }
  figma.commitUndo();
  let attempted = false;
  try {
    for (const { node, op, value, variable } of plan.writes) {
      attempted = true;
      if (op.kind === "bind") node.setBoundVariable(op.property, variable);
      else node[op.property] = value;
      if (op.kind === "set" && !same(plain(node[op.property]), value)) fail("لم يقبل Figma القيمة المطلوبة للخاصية " + op.property);
      if (op.kind === "bind") {
        const binding = node.boundVariables && node.boundVariables[op.property];
        if (variable ? !binding || binding.id !== variable.id : !!binding) fail("لم يقبل Figma تغيير ارتباط المتغير.");
      }
      if (op.kind === "paintBinding") {
        const paint = node[op.property][op.paintIndex];
        const binding = paint.boundVariables && paint.boundVariables.color;
        if (variable ? !binding || binding.id !== variable.id : !!binding) fail("لم يقبل Figma تغيير ارتباط اللون.");
      }
    }
    figma.commitUndo();
  } catch (error) {
    // حد commitUndo السابق يعزل الدفعة. التراجع الأصلي يستعيد تنسيق النص
    // وoverrides والقياسات التابعة أيضًا، دون إعادة إنشاء طبقة أو فك instance.
    // لا نستدعي undo إذا رفض أول setter دون أي تغيير (لحماية تاريخ المستخدم).
    let changed = false;
    if (attempted) {
      for (const { node } of plan.writes) {
        const original = baseline.nodes.find(n => n.id === node.id);
        // قراءة متزامنة دون await قبل triggerUndo.
        for (const p of Object.keys(original.properties)) {
          if (!same(plain(node[p]), original.properties[p])) changed = true;
        }
        if (!same(plain(node.boundVariables || {}), original.boundVariables)) changed = true;
      }
    }
    pending = null;
    if (changed) {
      figma.commitUndo();
      figma.triggerUndo();
      let restored = true;
      for (const { node } of plan.writes) {
        if (!same(await snapshot(node), baseline.nodes.find(n => n.id === node.id))) restored = false;
      }
      if (!restored) { baseline = null; fail("فشل التطبيق: " + error.message + " — تعذر تأكيد الاستعادة كاملة. أوقف التحرير وافحص سجل Undo في Figma ثم أعد التصدير."); }
    }
    fail("فشل التطبيق: " + error.message + (changed ? " — استعيدت القيم السابقة والتحقق منها عبر تراجع Figma الأصلي." : " — لم تسجل تغييرات على العناصر."));
  }
  const count = plan.writes.length;
  pending = null;
  baseline = null;
  send("done", { message: "طُبقت " + count + " عملية. تراجع بخطوة واحدة Ctrl+Z. صدّر مجددًا للتعديل التالي." });
}

figma.ui.onmessage = async message => {
  if (busy) { send("error", { message: "انتظر اكتمال العملية الحالية." }); return; }
  busy = true;
  try {
    if (message.type === "init") send("identity", { work: identity() });
    else if (message.type === "newIdentity") {
      baseline = null; pending = null;
      figma.commitUndo();
      const work = { workspaceId: uuid(), createdAt: new Date().toISOString() };
      figma.root.setPluginData(KEY, JSON.stringify(work));
      figma.commitUndo();
      send("identity", { work });
    } else if (message.type === "export") await exportSelection();
    else if (message.type === "preview") {
      pending = null;
      if (typeof message.json !== "string" || message.json.length > 5000000) fail("ملف التعديلات أكبر من 5 ملايين حرف أو غير صالح.");
      const patch = JSON.parse(message.json, (key, value) => {
        if (["__proto__", "constructor", "prototype"].includes(key)) fail("مفتاح JSON غير مسموح.");
        return value;
      });
      const plan = await makePlan(patch);
      if (plan.ok) pending = patch;
      send("preview", { rows: plan.rows, ok: plan.ok });
    } else if (message.type === "apply") await applyPending();
    else fail("رسالة غير معروفة.");
  } catch (error) { send("error", { message: error.message || String(error) }); }
  finally { busy = false; send("idle", {}); }
};
