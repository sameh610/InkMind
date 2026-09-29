import { parse } from '@babel/parser';

export const COMPONENTS = new Set([
  'App','Row','Column','Grid','Stack','Panel','Controls','Section','Spacer','Divider',
  'Title','Heading','Text','Label','Note','Hint','Success','Warning','ErrorText','Equation','Number',
  'Slider','Button','Toggle','Select','Input','NumberInput','Tabs','SegmentedControl',
  'Graph','Chart','Table','Timeline','Flowchart','Diagram','Planet','Orbit','Star','ParticleField',
  'Wave','Vector','ForceArrow','Field','Flow','Pendulum','Projectile','Spring','Ramp','Ball',
  'Collision','NeuralNetwork','SortingVisualizer','SearchVisualizer','TreeVisualizer','GraphNetwork',
  'Scene','Circle','Rect','Line','Path','Polygon','TextObject','Arrow','NativeWeb'
]);
export const CAPABILITIES = Object.freeze({ LITE: 0, BALANCED: 1, SMART: 2, ULTRA: 3 });
const SCENE = new Set(['Scene','Circle','Rect','Line','Path','Polygon','TextObject','Arrow']);
const MATH = new Set(['sin','cos','tan','sqrt','abs','pow','min','max']);
const STYLE = new Set(['width','height','minWidth','maxWidth','minHeight','maxHeight','padding','gap','align','justify','opacity','rotation','scale','zIndex']);
const OPS = new Set(['+','-','*','/','%','**','>','<','>=','<=','==','!=','===','!==','&&','||']);
const PROP = /^[a-zA-Z][a-zA-Z0-9]*$/;
const MAX_SOURCE = 25000;

function distance(a,b) {
  const row = Array.from({length:b.length+1},(_,i)=>i);
  for(let i=1;i<=a.length;i++) {
    let prev=row[0];row[0]=i;
    for(let j=1;j<=b.length;j++) { const old=row[j];row[j]=Math.min(row[j]+1,row[j-1]+1,prev+(a[i-1]===b[j-1]?0:1));prev=old; }
  }
  return row[b.length];
}
function componentName(raw) {
  return [...COMPONENTS].find(c=>c.toLowerCase()===raw.toLowerCase()) || raw;
}
function error(code,node,message,repair) {
  const loc=node?.loc?.start || {line:1,column:0};
  return {code,line:loc.line,column:loc.column+1,message,repair};
}
function fail(code,node,message,repair) { throw error(code,node,message,repair); }
function nameOf(node) {
  if(node?.type==='JSXIdentifier') return node.name;
  fail('INK100',node,'Only simple InkMind component names are supported.','Use a documented component such as <Panel>.');
}

function expression(node, scope) {
  if (!node) return {kind:'literal',value:null};
  switch(node.type) {
    case 'StringLiteral':case 'NumericLiteral':case 'BooleanLiteral':return {kind:'literal',value:node.value};
    case 'NullLiteral':return {kind:'literal',value:null};
    case 'Identifier':
      if(!scope.has(node.name)) fail('INK111',node,`Unknown variable ${node.name}.`,'Declare it with const or state().');
      return {kind:'ref',name:node.name};
    case 'ArrayExpression':return {kind:'array',items:node.elements.map(e=>expression(e,scope))};
    case 'ObjectExpression':return {kind:'object',entries:node.properties.map(p=>{
      if(p.type!=='ObjectProperty'||p.computed||p.method||p.shorthand) fail('INK112',p,'Only plain object properties are supported.','Use { name: value }.');
      const key=p.key.name??p.key.value;
      if(typeof key!=='string'||!PROP.test(key)) fail('INK112',p,'Invalid object key.','Use an identifier key.');
      return {key,value:expression(p.value,scope)};
    })};
    case 'UnaryExpression':
      if(!['!','+','-'].includes(node.operator)) fail('INK113',node,'Unsupported unary operator.','Use !, + or -.');
      return {kind:'unary',op:node.operator,arg:expression(node.argument,scope)};
    case 'BinaryExpression':case 'LogicalExpression':
      if(!OPS.has(node.operator)) fail('INK114',node,`Unsupported operator ${node.operator}.`,'Use approved arithmetic, comparisons or boolean operators.');
      return {kind:'binary',op:node.operator,left:expression(node.left,scope),right:expression(node.right,scope)};
    case 'ConditionalExpression':return {kind:'conditional',test:expression(node.test,scope),yes:expression(node.consequent,scope),no:expression(node.alternate,scope)};
    case 'TemplateLiteral':return {kind:'template',parts:node.quasis.map(q=>q.value.cooked),values:node.expressions.map(e=>expression(e,scope))};
    case 'MemberExpression': {
      if(node.computed) fail('INK115',node,'Computed property access is unavailable.','Use a named property.');
      if(node.object.type==='Identifier'&&node.object.name==='Math'&&node.property.name==='PI') return {kind:'literal',value:Math.PI};
      if(node.object.type==='Identifier'&&scope.has(node.object.name)&&['x','y','baseX','baseY','rotation','scaleX','scaleY','opacity','visible'].includes(node.property.name)) return {kind:'member',object:node.object.name,property:node.property.name};
      fail('INK115',node,'Property access is not available here.','Use state variables or approved Math functions.');
    }
    case 'CallExpression': {
      const callee=node.callee;
      if(callee.type==='MemberExpression'&&!callee.computed&&callee.object.name==='Math'&&MATH.has(callee.property.name)) return {kind:'math',fn:callee.property.name,args:node.arguments.map(a=>expression(a,scope))};
      if(callee.type==='Identifier'&&callee.name==='quantity'&&node.arguments.length===2) return {kind:'quantity',value:expression(node.arguments[0],scope),unit:expression(node.arguments[1],scope)};
      fail('INK116',node,'Function call is not permitted in this expression.','Use state(), quantity(), or approved Math functions.');
    }
    default:fail('INK117',node,`Unsupported expression ${node.type}.`,'Use literals, state references and simple expressions.');
  }
}
function constant(expr) {
  if(expr.kind==='literal') return expr.value;
  if(expr.kind==='unary') { const v=constant(expr.arg);return expr.op==='-'?-v:expr.op==='+'?+v:!v; }
  if(expr.kind==='array') return expr.items.map(constant);
  if(expr.kind==='object') return Object.fromEntries(expr.entries.map(e=>[e.key,constant(e.value)]));
  fail('INK120',null,'State initial values must be constant.','Use a literal number, string, boolean, array or object.');
}
function jsx(node,scope,capability,warnings) {
  if(node.type==='JSXFragment') return {type:'Column',props:{},children:node.children.map(c=>jsxChild(c,scope,capability,warnings)).filter(Boolean)};
  if(node.type!=='JSXElement') fail('INK130',node,'Expected an InkMind component.','Return JSX.');
  let type=nameOf(node.openingElement.name);
  const normalized=componentName(type);
  if(normalized!==type) { warnings.push(error('INK001',node,`Normalized <${type}> to <${normalized}>.`,`Use <${normalized}>.`));type=normalized; }
  if(!COMPONENTS.has(type)) {
    const near=[...COMPONENTS].map(c=>({c,d:distance(type.toLowerCase(),c.toLowerCase())})).sort((a,b)=>a.d-b.d)[0];
    fail('INK101',node,`Unknown component <${type}>.`,near?.d<=4?`Did you mean <${near.c}>?`:'Use a documented InkMind component.');
  }
  if(type==='NativeWeb'&&capability<CAPABILITIES.ULTRA) fail('INK301',node,'NativeWeb is unavailable for this model capability.','Use InkMind components or a Scene.');
  if(SCENE.has(type)&&capability<CAPABILITIES.BALANCED) fail('INK302',node,`${type} requires BALANCED capability.`, 'Use a high-level component.');
  const props={};
  for(const attr of node.openingElement.attributes) {
    if(attr.type!=='JSXAttribute') fail('INK131',attr,'Spread props are unavailable.','List props explicitly.');
    const key=attr.name.name;
    if(!PROP.test(key)) fail('INK132',attr,'Invalid prop name.','Use a named prop.');
    if(key==='dangerouslySetInnerHTML'||key.startsWith('on')) fail('INK133',attr,`${key} is not allowed.`, 'Use built-in controls and state.');
    const value=attr.value===null?{kind:'literal',value:true}:attr.value.type==='StringLiteral'?{kind:'literal',value:attr.value.value}:expression(attr.value.expression,scope);
    if(key==='style') {
      if(value.kind!=='object'||value.entries.some(e=>!STYLE.has(e.key))) fail('INK134',attr,'Style contains an unsupported property.','Use only InkMind layout style properties.');
    }
    props[key]=value;
  }
  if(type==='Slider'&&props.min?.kind==='literal'&&props.max?.kind==='literal'&&props.min.value>props.max.value) {
    [props.min,props.max]=[props.max,props.min];warnings.push(error('INK205',node,'Slider minimum exceeded maximum; values were swapped.','Set min below max.'));
  }
  for(const key of ['width','height']) if(props[key]?.kind==='literal'&&typeof props[key].value==='number'&&props[key].value<0) {
    props[key].value=Math.abs(props[key].value);warnings.push(error('INK206',node,`Negative ${key} was normalized.`,`Use a positive ${key}.`));
  }
  return {type,props,children:node.children.map(c=>jsxChild(c,scope,capability,warnings)).filter(Boolean),loc:node.loc?.start};
}
function jsxChild(node,scope,capability,warnings) {
  if(node.type==='JSXText') { const value=node.value.replace(/\s+/g,' ').trim();return value?{type:'Text',props:{text:{kind:'literal',value}},children:[]}:null; }
  if(node.type==='JSXExpressionContainer') { if(node.expression.type==='JSXEmptyExpression') return null;return {type:'Text',props:{text:expression(node.expression,scope)},children:[]}; }
  return jsx(node,scope,capability,warnings);
}
function compileVisual(fn,capability,warnings) {
  const scope=new Set();const state=[];let returned=null;
  for(const stmt of fn.body.body) {
    if(stmt.type==='VariableDeclaration'&&stmt.kind==='const') {
      for(const dec of stmt.declarations) {
        if(dec.id.type!=='Identifier'||!dec.init) fail('INK140',dec,'Only named const declarations are supported.','Use const name = value.');
        if(scope.has(dec.id.name)) fail('INK141',dec,`Duplicate variable ${dec.id.name}.`,'Rename this variable.');
        const isState=dec.init.type==='CallExpression'&&dec.init.callee.type==='Identifier'&&dec.init.callee.name==='state';
        if(isState && dec.init.arguments.length!==1) fail('INK145',dec,'state() takes one initial value.','Use state(9.81).');
        const value=isState?expression(dec.init.arguments[0],scope):expression(dec.init,scope);
        let initial=null;
        if(isState) initial=constant(value);
        else { try { initial=constant(value); } catch (_) { /* Derived const. */ } }
        scope.add(dec.id.name);
        state.push({name:dec.id.name,value:initial,reactive:isState,...(!isState?{expression:value}:{})});
      }
    } else if(stmt.type==='ReturnStatement') {
      if(returned) fail('INK142',stmt,'Only one return is supported.','Return one <App> tree.');
      returned=jsx(stmt.argument,scope,capability,warnings);
    } else fail('INK143',stmt,`Unsupported statement ${stmt.type}.`,'Use const declarations and one JSX return.');
  }
  if(!returned||returned.type!=='App') fail('INK144',fn,'Visual() must return <App>.','Wrap the visual in <App title="...">.');
  const reactive=new Set(state.filter(v=>v.reactive).map(v=>v.name));
  function check(node) {
    if(['Slider','Toggle','Select','Tabs','SegmentedControl','Input','NumberInput'].includes(node.type)) {
      const value=node.props.value;
      if(value?.kind!=='ref'||!reactive.has(value.name)) fail('INK210',{loc:{start:node.loc||{line:1,column:0}}},`${node.type} must use a reactive state value.`,'Declare const value = state(initial), then value={value}.');
    }
    if(node.type==='NativeWeb' && (node.props.html?.kind!=='literal'||typeof node.props.html.value!=='string')) fail('INK303',{loc:{start:node.loc||{line:1,column:0}}},'NativeWeb needs literal HTML.','Pass html="..." in ULTRA mode.');
    node.children.forEach(check);
  }
  check(returned);
  return {version:1,mode:'visual',state,root:returned};
}
function binding(node,scope) {
  if(node?.type!=='CallExpression'||node.callee?.type!=='MemberExpression'||node.callee.computed) fail('INK401',node,'Ink binding must use ink.selection(), ink.page(), ink.stroke(), ink.find() or group().','Use a documented ink selector.');
  const owner=node.callee.object, method=node.callee.property.name;
  if(owner.type==='Identifier'&&owner.name==='ink'&&['selection','page','stroke','find'].includes(method)) {
    if(['stroke','find'].includes(method)&&node.arguments[0]?.type!=='StringLiteral') fail('INK402',node,'Stroke/find requires a string ID or label.','Pass a string literal.');
    const optionsIndex=['stroke','find'].includes(method)?1:0;
    const options=node.arguments[optionsIndex]===undefined?{}:constant(expression(node.arguments[optionsIndex],new Set()));
    if(!options||typeof options!=='object'||Array.isArray(options)||Object.keys(options).some(k=>!['pivotX','pivotY'].includes(k))||Object.values(options).some(v=>typeof v!=='number'||!Number.isFinite(v)||Math.abs(v)>100000))
      fail('INK421',node,'Invalid ink pivot.','Use {pivotX:100,pivotY:50} with finite page coordinates.');
    return {selector:method,arg:['stroke','find'].includes(method)?node.arguments[0]?.value:null,...options};
  }
  if(owner.type==='Identifier'&&scope.has(owner.name)&&method==='group'&&node.arguments[0]?.type==='StringLiteral') return {selector:'group',parent:owner.name,arg:node.arguments[0].value};
  fail('INK401',node,'Unsupported ink binding.','Use ink.selection(), ink.stroke("id") or selection.group("label").');
}
function compileAnimation(fn) {
  const scope=new Set();const bindings=[];const animations=[];const drawings=[];const state=[];let rig=null;let animationStarted=false;
  for(const stmt of fn.body.body) {
    if(stmt.type==='VariableDeclaration'&&stmt.kind==='const') {
      for(const dec of stmt.declarations) {
        if(dec.id.type!=='Identifier') fail('INK403',dec,'Binding needs a name.','Use const part = ink.selection().');
        const isState=dec.init?.type==='CallExpression'&&dec.init.callee?.type==='Identifier'&&dec.init.callee.name==='state';
        if(isState) {
          if(animationStarted) fail('INK413',dec,'State controls must be declared before animate().','Move const speed = state(...) above animate().');
          if(dec.init.arguments.length!==1) fail('INK414',dec,'Animation state() takes one constant value.','Use const speed = state(1.4).');
          const value=constant(expression(dec.init.arguments[0],scope));
          if(typeof value!=='number'||!Number.isFinite(value)) fail('INK415',dec,'Animation state must be a finite number.','Use a numeric state value.');
          state.push({name:dec.id.name,value,reactive:true});scope.add(dec.id.name);continue;
        }
        bindings.push({name:dec.id.name,...binding(dec.init,scope)});scope.add(dec.id.name);
      }
    } else if(stmt.type==='ExpressionStatement'&&stmt.expression.type==='CallExpression'&&stmt.expression.callee.name==='draw') {
      if(animationStarted||bindings.length||state.length) fail('INK416',stmt,'Draw commands must come before state, ink bindings and animate().','Start Animation() with draw({...}) commands.');
      if(stmt.expression.arguments.length!==1) fail('INK417',stmt,'draw() takes one stroke object.','Use draw({id:"stroke", points:[[0,0],[1,1]]}).');
      const drawing=constant(expression(stmt.expression.arguments[0],new Set()));
      if(!drawing||typeof drawing.id!=='string'||drawing.id.length<1||drawing.id.length>150||!Array.isArray(drawing.points)||drawing.points.length>512||drawing.points.some(p=>!Array.isArray(p)||p.length<2||p.length>3||p.some(v=>typeof v!=='number'||!Number.isFinite(v))))
        fail('INK418',stmt,'Invalid drawn stroke.','Use a safe id and finite [x,y] points.');
      if(drawings.some(d=>d.id===drawing.id)) fail('INK419',stmt,'A stroke can only be drawn once.','Remove the duplicate draw() command.');
      drawings.push(drawing);
    } else if(stmt.type==='ExpressionStatement'&&stmt.expression.type==='CallExpression'&&stmt.expression.callee.name==='rig') {
      if(rig||stmt.expression.arguments.length!==1) fail('INK409',stmt,'Use one rig({...}) call.','Provide a single rig plan.');
      if(animationStarted||bindings.length||state.length) fail('INK420',stmt,'rig() must follow draw() commands and replace normal animation statements.','Use ink bindings and animate() for editable InkScript motion.');
      rig=constant(expression(stmt.expression.arguments[0],new Set()));
      const kinds=new Set(['pendulum','patrol','reveal','wave','float','slide','bounce','pulse','rotate']);
      const roles=new Set(['rod','bob','ink','static','anchor']);
      const controlsOk=rig?.controls===undefined||(Array.isArray(rig.controls)&&rig.controls.length<=8&&rig.controls.every(c=>c&&typeof c.name==='string'&&c.name.length>0&&c.name.length<32&&Number.isFinite(c.min)&&Number.isFinite(c.max)&&c.min<c.max&&Number.isFinite(c.value)&&c.value>=c.min&&c.value<=c.max&&(c.unit===undefined||typeof c.unit==='string')));
      if(!rig||!kinds.has(rig.kind)||!Array.isArray(rig.parts)||!rig.parts.length||rig.parts.length>256||
         !rig.parts.every(p=>p&&typeof p.id==='string'&&p.id.length>0&&p.id.length<150&&roles.has(p.role))||
         !rig.parts.some(p=>p.role!=='static'&&p.role!=='anchor')||
         new Set(rig.parts.map(p=>p.id)).size!==rig.parts.length||
         !Number.isFinite(rig.speed)||rig.speed<=0||rig.speed>12||
         !Number.isFinite(rig.amount)||Math.abs(rig.amount)>1000||!controlsOk||
         !Number.isFinite(rig.pivotX)||!Number.isFinite(rig.pivotY))
        fail('INK410',stmt,'Invalid ink rig.','Use allowed kind, unique selected stroke IDs, valid roles, speed, amount and pivot coordinates.');
    } else if(stmt.type==='ExpressionStatement'&&stmt.expression.type==='CallExpression'&&stmt.expression.callee.name==='animate') {
      animationStarted=true;
      const callback=stmt.expression.arguments[0];
      if(!['ArrowFunctionExpression','FunctionExpression'].includes(callback?.type)||callback.body.type!=='BlockStatement') fail('INK404',stmt,'animate() needs a callback block.','Use animate(({ time }) => { ... }).');
      for(const assignment of callback.body.body) {
        if(assignment.type!=='ExpressionStatement'||assignment.expression.type!=='AssignmentExpression'||assignment.expression.operator!=='=') fail('INK405',assignment,'Animation body supports property assignments only.','Set object.rotation, x, y, scaleX, scaleY or opacity.');
        const e=assignment.expression, target=e.left;
        if(target.type!=='MemberExpression'||target.computed||target.object.type!=='Identifier'||!scope.has(target.object.name)||!['x','y','rotation','scaleX','scaleY','opacity','visible','bend'].includes(target.property.name)) fail('INK406',target,'Invalid animation target.','Assign an approved property on an ink binding.');
        animations.push({target:target.object.name,property:target.property.name,value:expression(e.right,new Set([...scope,'time']))});
      }
    } else fail('INK407',stmt,'Unsupported animation statement.','Use bindings followed by animate().');
  }
  if(rig) {
    if(animations.length||bindings.length||state.length) fail('INK411',fn,'Rig and editable transform statements cannot be mixed.','Use draw(), ink bindings and animate() for normal InkScript.');
    return {version:1,mode:'animateInk',drawings,state:[],bindings:[],animations:[],rig};
  }
  if(!animations.length) fail('INK408',fn,'Animation has no transforms.','Add a property assignment inside animate().');
  return {version:1,mode:'animateInk',drawings,state,bindings,animations};
}
export function compileInkScript(source,{capability='LITE'}={}) {
  const warnings=[];
  try {
    if(typeof source!=='string'||source.length>MAX_SOURCE) fail('INK001',null,'InkScript source is too long.','Keep source below 25 KB.');
    const level=CAPABILITIES[capability];
    if(level===undefined) fail('INK002',null,'Unknown capability profile.','Use LITE, BALANCED, SMART or ULTRA.');
    const normalized=source.replace(/\b(min|max|step|width|height)=(-?\d+(?:\.\d+)?)(?=[\s/>])/g, (_,key,value)=>`${key}={${value}}`);
    if(normalized!==source) warnings.push(error('INK007',null,'Wrapped bare numeric JSX props in braces.','Use min={-3}, not min=-3.'));
    const ast=parse(normalized,{sourceType:'module',plugins:['typescript','jsx'],errorRecovery:false});
    if(ast.program.body.length!==1||ast.program.body[0].type!=='ExportDefaultDeclaration') fail('INK003',ast.program,'Export one default function.','Use export default function Visual() { ... }.');
    const fn=ast.program.body[0].declaration;
    if(fn.type!=='FunctionDeclaration'||!['Visual','Animation'].includes(fn.id?.name)||fn.params.length) fail('INK004',fn,'Default export must be Visual() or Animation().','Use export default function Visual() { ... }.');
    const ir=fn.id.name==='Animation'?compileAnimation(fn):compileVisual(fn,level,warnings);
    return {ok:true,source:normalized,ir,warnings,ast:{type:'Program',function:fn.id.name,statements:fn.body.body.map(s=>s.type)}};
  } catch(e) {
    const diagnostic=e.code?.startsWith('INK')?e:error('INK000',{loc:e.loc?{start:e.loc}:undefined},e.message||'Syntax error.','Return corrected restricted TSX.');
    return {ok:false,errors:[diagnostic],warnings,repairPrompt:`Fix only these InkScript errors:\n${diagnostic.code} line ${diagnostic.line}:${diagnostic.column}: ${diagnostic.message} ${diagnostic.repair}\nReturn corrected InkScript only.`};
  }
}
