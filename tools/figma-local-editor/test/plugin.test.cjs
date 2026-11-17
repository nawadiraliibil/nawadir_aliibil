// اختبارات عقد محلية بمحاكاة Plugin API؛ لا تغني عن اختبار Figma Desktop.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '..', 'code.js'), 'utf8');
const clone = x => JSON.parse(JSON.stringify(x));

function setup() {
  const messages = [], storage = {}, all = new Map();
  const root = { id: '0:0', name: 'Document', type: 'DOCUMENT', parent: null,
    getPluginData: key => storage[key] || '', setPluginData: (key, value) => { storage[key] = value; } };
  const page = { id: '0:1', type: 'PAGE', name: 'الجوال', parent: root, selection: [] };
  const frame = { id: '1:1', name: 'قائمة', type: 'FRAME', parent: page, children: [],
    x: 0, y: 0, width: 390, height: 300, layoutMode: 'VERTICAL', itemSpacing: 12,
    paddingRight: 16, paddingLeft: 16, opacity: 1, boundVariables: {}, cornerRadius: 8,
    topLeftRadius: 8, topRightRadius: 8, bottomLeftRadius: 8, bottomRightRadius: 8,
    fills: [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }], fillStyleId: '', locked: false };
  const text = { id: '1:2', name: 'عنوان', type: 'TEXT', parent: frame,
    characters: 'القائمة', fontName: { family: 'Noto Sans Arabic', style: 'Regular' },
    hasMissingFont: false, fontSize: 16, textAlignHorizontal: 'RIGHT', textAlignVertical: 'TOP',
    boundVariables: {}, locked: false,
    getStyledTextSegments() { return this.characters ? [{ start: 0, end: this.characters.length,
      characters: this.characters, fontName: this.fontName, fontSize: this.fontSize, boundVariables: {} }] : []; },
    getRangeAllFontNames() { return [this.fontName]; } };
  frame.children.push(text);
  frame.setBoundVariable = function (p, v) {
    if (v) this.boundVariables[p] = { type: 'VARIABLE_ALIAS', id: v.id };
    else delete this.boundVariables[p];
  };
  [root, page, frame, text].forEach(n => all.set(n.id, n)); page.selection = [frame];
  const variables = new Map([
    ['VariableID:1', { id: 'VariableID:1', key: 'float', name: 'المسافة', resolvedType: 'FLOAT', valuesByMode: { m: 16 } }],
    ['VariableID:2', { id: 'VariableID:2', key: 'color', name: 'اللون', resolvedType: 'COLOR', valuesByMode: { m: { r: 1, g: 0, b: 0 } } }]
  ]);
  const state = () => [...all.values()].map(n => ({ id: n.id, values: Object.fromEntries(Object.entries(n)
    .filter(([k, v]) => !['parent', 'children', 'selection'].includes(k) && typeof v !== 'function')) })).map(clone);
  const restore = data => data.forEach(({ id, values }) => {
    const node = all.get(id);
    Object.entries(values).forEach(([k, v]) => { node[k] = clone(v); });
  });
  let boundary, history = [], undoCount = 0;
  const fonts = [];
  const figma = {
    root, currentPage: page, mixed: Symbol('mixed'), fileKey: 'test-file',
    showUI() {}, ui: { postMessage: m => messages.push(clone(m)) },
    async getNodeByIdAsync(id) { return all.get(id) || null; },
    async loadFontAsync(f) { fonts.push(clone(f)); },
    variables: {
      async getVariableByIdAsync(id) { return variables.get(id) || null; },
      setBoundVariableForPaint(paint, field, variable) {
        const result = clone(paint); result.boundVariables = result.boundVariables || {};
        if (variable) result.boundVariables[field] = { type: 'VARIABLE_ALIAS', id: variable.id };
        else delete result.boundVariables[field]; return result;
      }
    },
    commitUndo() {
      const current = state();
      if (boundary && JSON.stringify(boundary) !== JSON.stringify(current)) history.push(boundary);
      boundary = current;
    },
    triggerUndo() {
      undoCount++;
      const current = state();
      if (boundary && JSON.stringify(boundary) !== JSON.stringify(current)) restore(boundary);
      else if (history.length) restore(history.pop());
      boundary = state();
    }
  };
  const context = vm.createContext({ figma, __html__: '', console });
  vm.runInContext(source, context);
  const message = async (type, data = {}) => { await figma.ui.onmessage({ type, ...data }); return messages.filter(m => m.type !== 'idle').at(-1); };
  const exported = async () => {
    await message('newIdentity'); await message('export');
    return messages.filter(m => m.type === 'export').at(-1).data;
  };
  const patch = (data, operations) => ({ schema: 'codex-figma-patch', version: 1,
    workspaceId: data.workspaceId, exportId: data.exportId, operations });
  const op = (data, id, property, after, kind = 'set') => {
    const node = data.nodes.find(n => n.id === id);
    return { kind, nodeId: id, property, before: clone(node.properties[property]),
      beforeBindings: clone(node.propertyBindings[property]), after };
  };
  const preview = p => message('preview', { json: JSON.stringify(p) });
  return { figma, frame, text, page, all, messages, fonts, message, exported, patch, op, preview, undoCount: () => undoCount };
}

test('تصدير عربي بعلاقات وارتباطات؛ لا تهيئة تلقائية للنسخة', async () => {
  const h = setup(); assert.equal((await h.message('export')).type, 'error');
  const d = await h.exported();
  assert.equal(d.nodes.length, 2); assert.equal(d.nodes[1].parentId, '1:1');
  assert.equal(d.nodes[1].properties.characters, 'القائمة');
  assert.ok(d.nodes[0].propertyBindings.itemSpacing); assert.ok(d.workspaceId);
});
test('معاينة بلا كتابة، تحميل خط عربي، تطبيق في المكان وتراجع واحد', async () => {
  const h = setup(), d = await h.exported();
  const p = h.patch(d, [h.op(d, '1:2', 'characters', 'إعلانات الإبل'), h.op(d, '1:1', 'itemSpacing', 20)]);
  assert.equal((await h.preview(p)).ok, true);
  assert.equal(h.text.characters, 'القائمة'); assert.equal(h.frame.itemSpacing, 12);
  assert.equal((await h.message('apply')).type, 'done');
  assert.equal(h.text.characters, 'إعلانات الإبل'); assert.equal(h.frame.itemSpacing, 20);
  assert.equal(h.fonts[0].family, 'Noto Sans Arabic'); assert.equal(h.text.parent, h.frame);
  h.figma.triggerUndo(); assert.equal(h.text.characters, 'القائمة'); assert.equal(h.frame.itemSpacing, 12);
});
test('رفض نسخة أخرى، تصدير قديم، عنصر مفقود، before وارتباطات غير صحيحة', async () => {
  for (const mode of ['workspace', 'export', 'missing', 'before', 'binding', 'unknown']) {
    const h = setup(), d = await h.exported(), op = h.op(d, '1:1', 'itemSpacing', 20), p = h.patch(d, [op]);
    if (mode === 'workspace') p.workspaceId = 'other';
    if (mode === 'export') p.exportId = 'old';
    if (mode === 'missing') h.all.delete('1:1');
    if (mode === 'before') op.before = 999;
    if (mode === 'binding') op.beforeBindings = {};
    if (mode === 'unknown') op.property = '__proto__';
    const preview = await h.preview(p);
    assert.ok(preview.type === 'error' || preview.ok === false, mode);
    await h.message('apply'); assert.equal(h.frame.itemSpacing, 12);
  }
});
test('تعارض بعد المعاينة يوقف كامل الدفعة', async () => {
  const h = setup(), d = await h.exported();
  await h.preview(h.patch(d, [h.op(d, '1:2', 'characters', 'جديد'), h.op(d, '1:1', 'itemSpacing', 20)]));
  h.frame.itemSpacing = 24;
  assert.equal((await h.message('apply')).type, 'error');
  assert.equal(h.text.characters, 'القائمة'); assert.equal(h.frame.itemSpacing, 24);
});
test('تغير التصميم أثناء تحميل الخطوط يوقف الدفعة', async () => {
  const h = setup(), d = await h.exported();
  await h.preview(h.patch(d, [h.op(d, '1:2', 'characters', 'جديد'), h.op(d, '1:1', 'itemSpacing', 20)]));
  h.figma.loadFontAsync = async () => { h.frame.itemSpacing = 40; };
  assert.equal((await h.message('apply')).type, 'error'); assert.equal(h.text.characters, 'القائمة');
});
test('تجاوز خاصية مرتبطة، تغيير الارتباط صراحة وفكه', async () => {
  const h = setup(); h.frame.boundVariables.itemSpacing = { type: 'VARIABLE_ALIAS', id: 'VariableID:1' };
  const d = await h.exported();
  const op = h.op(d, '1:1', 'itemSpacing', 20);
  assert.equal((await h.preview(h.patch(d, [op]))).rows[0].status, 'skip');
  await h.message('apply'); assert.equal(h.frame.itemSpacing, 12);
  op.kind = 'bind'; op.variableId = null; delete op.after;
  assert.equal((await h.preview(h.patch(d, [op]))).ok, true);
  await h.message('apply'); assert.equal(h.frame.boundVariables.itemSpacing, undefined);
  const next = await h.message('export'), op2 = h.op(next.data, '1:1', 'itemSpacing', undefined, 'bind');
  delete op2.after; op2.variableId = 'VariableID:1';
  await h.preview(h.patch(next.data, [op2])); await h.message('apply');
  assert.equal(h.frame.boundVariables.itemSpacing.id, 'VariableID:1');
});
test('لون مرتبط يتجاوز set، وتغيير ربط الطلاء صريح فقط', async () => {
  const h = setup(); h.frame.fills[0].boundVariables = { color: { type: 'VARIABLE_ALIAS', id: 'VariableID:2' } };
  const d = await h.exported(), after = clone(h.frame.fills); after[0].color = { r: .2, g: .3, b: .4 };
  assert.equal((await h.preview(h.patch(d, [h.op(d, '1:1', 'fills', after)]))).rows[0].status, 'skip');
  const op = h.op(d, '1:1', 'fills', undefined, 'paintBinding'); delete op.after; op.paintIndex = 0; op.variableId = null;
  assert.equal((await h.preview(h.patch(d, [op]))).ok, true); await h.message('apply');
  assert.equal(h.frame.fills[0].boundVariables.color, undefined);
});
test('فشل الخط لا يغير أي عنصر', async () => {
  const h = setup(), d = await h.exported();
  await h.preview(h.patch(d, [h.op(d, '1:1', 'itemSpacing', 20), h.op(d, '1:2', 'characters', 'جديد')]));
  h.figma.loadFontAsync = async () => { throw Error('Font unavailable'); };
  assert.equal((await h.message('apply')).type, 'error');
  assert.equal(h.frame.itemSpacing, 12); assert.equal(h.text.characters, 'القائمة'); assert.equal(h.undoCount(), 0);
});
test('فشل منتصف الدفعة يستعيد القيم السابقة عبر حد Undo واحد', async () => {
  const h = setup(); let gap = 12;
  Object.defineProperty(h.frame, 'itemSpacing', { enumerable: true, configurable: true,
    get: () => gap, set: v => { if (v === 20) throw Error('Setter failed'); gap = v; } });
  const d = await h.exported();
  await h.preview(h.patch(d, [h.op(d, '1:2', 'characters', 'جديد'), h.op(d, '1:1', 'itemSpacing', 20)]));
  const result = await h.message('apply');
  assert.equal(result.type, 'error'); assert.match(result.message, /استعيدت القيم السابقة/);
  assert.equal(h.text.characters, 'القائمة'); assert.equal(h.frame.itemSpacing, 12); assert.equal(h.undoCount(), 1);
});
test('رفض أول setter دون تغير لا يتراجع عن عمل سابق', async () => {
  const h = setup();
  Object.defineProperty(h.frame, 'itemSpacing', { enumerable: true, configurable: true,
    get: () => 12, set: () => { throw Error('رفض'); } });
  const d = await h.exported(); await h.preview(h.patch(d, [h.op(d, '1:1', 'itemSpacing', 20)]));
  await h.message('apply'); assert.equal(h.undoCount(), 0);
});
test('أنماط الطلاء والنص المختلط والقيم غير الصحيحة والتكرار توقف التطبيق', async () => {
  for (const mode of ['style', 'mixedText', 'invalid', 'duplicate', 'radius']) {
    const h = setup();
    if (mode === 'style') h.frame.fillStyleId = 'Style:1';
    if (mode === 'mixedText') h.text.getStyledTextSegments = () => [{ start: 0, end: 2 }, { start: 2, end: 7 }];
    const d = await h.exported(); let ops = [h.op(d, '1:1', 'itemSpacing', 20)];
    if (mode === 'style') ops = [h.op(d, '1:1', 'fills', clone(h.frame.fills))];
    if (mode === 'mixedText') ops = [h.op(d, '1:2', 'characters', 'جديد')];
    if (mode === 'invalid') ops[0].after = '20';
    if (mode === 'duplicate') ops.push(clone(ops[0]));
    if (mode === 'radius') ops = [h.op(d, '1:1', 'cornerRadius', 10), h.op(d, '1:1', 'topLeftRadius', 12)];
    assert.equal((await h.preview(h.patch(d, ops))).ok, false, mode);
  }
});
test('ارتباط المكون يظل محفوظًا عند تعديل instance في مكانه', async () => {
  const h = setup(); h.frame.type = 'INSTANCE'; h.frame.componentProperties = { 'عنوان#1': { type: 'TEXT', value: 'القائمة' } };
  h.frame.getMainComponentAsync = async () => ({ id: '2:1', key: 'component-key', name: 'بطاقة', remote: false });
  const d = await h.exported(); assert.equal(d.nodes[0].mainComponent.id, '2:1');
  await h.preview(h.patch(d, [h.op(d, '1:2', 'characters', 'جديد')])); await h.message('apply');
  assert.equal(h.frame.type, 'INSTANCE'); assert.equal((await h.frame.getMainComponentAsync()).id, '2:1');
  assert.equal(h.text.parent, h.frame);
});
test('ملفات JSON وJavaScript والواجهة بلا اعتماديات شبكة', () => {
  const base = path.join(__dirname, '..');
  const manifest = JSON.parse(fs.readFileSync(path.join(base, 'manifest.json'), 'utf8'));
  assert.deepEqual(manifest.networkAccess.allowedDomains, ['none']);
  const html = fs.readFileSync(path.join(base, 'ui.html'), 'utf8');
  for (const m of html.matchAll(/<script>([\s\S]*?)<\/script>/g)) new vm.Script(m[1]);
  assert.ok(html.includes("connect-src 'none'"));
  assert.doesNotMatch(source + html, /\bfetch\s*\(|XMLHttpRequest|WebSocket|https?:\/\//);
  const selection = JSON.parse(fs.readFileSync(path.join(base, 'examples', 'selection.example.json'), 'utf8'));
  const patch = JSON.parse(fs.readFileSync(path.join(base, 'examples', 'patch.example.json'), 'utf8'));
  assert.equal(patch.workspaceId, selection.workspaceId); assert.equal(patch.exportId, selection.exportId);
  for (const op of patch.operations) {
    const node = selection.nodes.find(n => n.id === op.nodeId);
    assert.deepEqual(op.before, node.properties[op.property]);
    assert.deepEqual(op.beforeBindings, node.propertyBindings[op.property]);
  }
  for (const file of [manifest.main, manifest.ui]) assert.ok(fs.existsSync(path.join(base, file)));
});
test('الحاجز المتزامن يكشف تغير عنصر سابق أثناء قراءة عنصر لاحق', async () => {
  const h = setup(), d = await h.exported();
  await h.preview(h.patch(d, [h.op(d, '1:2', 'characters', 'جديد'), h.op(d, '1:1', 'itemSpacing', 20)]));
  const lookup = h.figma.getNodeByIdAsync;
  let frameReads = 0;
  h.figma.getNodeByIdAsync = async id => {
    // آخر makePlan يقرأ النص ثم الإطار؛ يتغير النص بعد فحصه وقبل انتهاء الدفعة.
    if (id === '1:1' && ++frameReads === 2) h.text.characters = 'تعديل المستخدم';
    return lookup(id);
  };
  assert.equal((await h.message('apply')).type, 'error');
  assert.equal(h.text.characters, 'تعديل المستخدم'); assert.equal(h.frame.itemSpacing, 12);
});
