import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const html=fs.readFileSync('design/preview/index.html','utf8');
const script=html.match(/<script>([\s\S]*)<\/script>/)[1];
const elements=new Map();
const listeners={};
const element=id=>{if(!elements.has(id))elements.set(id,{innerHTML:'',open:false,classList:{toggle(){}},showModal(){this.open=true;},close(){this.open=false;},focus(){},setSelectionRange(){}});return elements.get(id);};
const document={querySelector:element,querySelectorAll:()=>[],addEventListener:(event,fn)=>(listeners[event]??=[]).push(fn)};
const context=vm.createContext({document,console});
vm.runInContext(script,context,{timeout:10000});
const run=code=>vm.runInContext(code,context,{timeout:10000});
const main=()=>element('#main').innerHTML;
const dispatch=(type,target)=>listeners[type].forEach(fn=>fn({target:{...target,closest:()=>target}}));
assert.match(main(),/Cubo laboratorio/);
dispatch('click',{id:'build-next',dataset:{}});assert.match(main(),/Cubo pronto/);
dispatch('click',{id:'build-next',dataset:{}});assert.match(main(),/Spazio verificato/);
dispatch('change',{id:'obstruction',checked:true});assert.match(main(),/scava ancora 1 cella/);assert.match(main(),/id="build-next" disabled/);
dispatch('change',{id:'obstruction',checked:false});dispatch('click',{id:'build-next',dataset:{}});assert.match(main(),/Laboratorio attivo/);
let states=5;
for(const view of ['flows','catalog','progression','materials']){
  run(`state.view=${JSON.stringify(view)};render();`);assert.ok(main().length>1000);states++;
}
for(const flow of ['build','navigation','inventory','care']){
  run(`state.view='flows';state.flow=${JSON.stringify(flow)};render();`);assert.ok(main().includes('anteprima')||main().includes('Anteprima'));states++;
}
const categories=run('Object.keys(names)');
for(const category of categories){run(`state.view='catalog';state.category=${JSON.stringify(category)};state.search='';state.stage='all';render();`);assert.ok(main().includes('elementi'));states++;}
run("state.search='rame';state.category='resources';render();");assert.match(main(),/Rame/);assert.doesNotMatch(main(),/title\">Iridio/);states++;
run("state.search='';state.stage='0';render();");assert.doesNotMatch(main(),/class="badge">Fase 7/);states++;
const ids=run('entities.map(e=>e.id)');
for(const id of ids){run(`detail(${JSON.stringify(id)});`);assert.ok(element('#details').open);assert.ok(element('#detail-content').innerHTML.includes(id));states++;}
run("detail('mod_ladder');");
assert.match(element('#detail-content').innerHTML,/Costruzione manuale immediata/);
assert.doesNotMatch(element('#detail-content').innerHTML,/Cubo chiuso/);
run("detail('recipe_cube_ladder');");
assert.match(element('#detail-content').innerHTML,/Sul campo/);
assert.match(element('#detail-content').innerHTML,/0 s · 0 kWh · Nessun cubo/);
run("detail('mod_workshop');");
assert.doesNotMatch(element('#detail-content').innerHTML,/recipe_cube_ladder/);
states+=3;
const broken=[];
for(const file of ['docs/design/README.md','docs/design/ai-implementation-contract.md','docs/design/care-and-caves.md']){
  const source=fs.readFileSync(file,'utf8');
  for(const m of source.matchAll(/\]\(([^)]+)\)/g)){
    const href=m[1];if(/^(?:https?:|#)/.test(href))continue;
    const target=new URL(href,new URL(file,'file:///'+process.cwd().replaceAll('\\','/')+'/')).pathname;
    const absolute=decodeURIComponent(target.replace(/^\/(?:([A-Za-z]):)/,'$1:'));
    if(!fs.existsSync(absolute))broken.push({file,href,absolute});
  }
}
assert.deepEqual(broken,[]);
const report={ok:true,rendered_states_and_entity_details:states,categories:categories.length,checked:['build_state_transitions','blocked_placement','all_flow_render_functions','category_filters','search','stage_filter','all_entity_detail_dialogs','instant_manual_ladder_without_cube_or_workstation','entry_document_links'],method:'isolated_Node_VM_with_minimal_DOM_test_double',browser_visual_verified:false,browser_limitation:'local_file_protocol_blocked_by_browser_policy'};
fs.writeFileSync('docs/design/preview-check-report.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
