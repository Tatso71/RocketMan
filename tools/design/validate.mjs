import fs from 'node:fs';
const manifest=JSON.parse(fs.readFileSync('design/v1/manifest.json','utf8'));
const D=Object.fromEntries(Object.entries(manifest.catalogs).map(([k,v])=>[k,JSON.parse(fs.readFileSync(`design/v1/${v}`,'utf8'))]));
const errors=[],warnings=[];
const check=(ok,msg)=>{if(!ok)errors.push(msg);};
const all=Object.values(D).filter(Array.isArray).flat();
const byId=new Map();
for(const e of all){check(typeof e.id==='string'&&/^[a-z]+_[a-z0-9_]+$/.test(e.id),`Invalid id ${e.id}`);check(!byId.has(e.id),`Duplicate ${e.id}`);byId.set(e.id,e);}
const ref=(id,where)=>check(byId.has(id),`Unknown reference ${id} in ${where}`);
const refs=(a,where)=>(a||[]).forEach(x=>ref(x,where));
const quantities=(obj,where)=>{check(obj&&typeof obj==='object'&&!Array.isArray(obj),`Not quantity map ${where}`);for(const[id,n]of Object.entries(obj||{})){ref(id,where);check(Number.isSafeInteger(n)&&n>0,`Invalid quantity ${where}.${id}=${n}`);}};

// Evaluate the documented subset of draft 2020-12 used by catalog.schema.json.
function schemaCheck(value,s,where){
  if(s.const!==undefined)check(value===s.const,`Schema const ${where}`);
  if(s.enum)check(s.enum.includes(value),`Schema enum ${where}`);
  if(s.type){const matches=t=>t==='null'?value===null:t==='array'?Array.isArray(value):t==='object'?value!==null&&typeof value==='object'&&!Array.isArray(value):t==='integer'?Number.isInteger(value):typeof value===t;const ok=(Array.isArray(s.type)?s.type:[s.type]).some(matches);check(ok,`Schema type ${where}: ${s.type}`);if(!ok)return;}
  if(typeof value==='number'){if(s.minimum!==undefined)check(value>=s.minimum,`Schema minimum ${where}`);if(s.exclusiveMinimum!==undefined)check(value>s.exclusiveMinimum,`Schema exclusiveMinimum ${where}`);if(s.maximum!==undefined)check(value<=s.maximum,`Schema maximum ${where}`);}
  if(typeof value==='string'){if(s.minLength)check(value.length>=s.minLength,`Schema minLength ${where}`);if(s.pattern)check(new RegExp(s.pattern).test(value),`Schema pattern ${where}`);}
  if(Array.isArray(value)){if(s.minItems!==undefined)check(value.length>=s.minItems,`Schema minItems ${where}`);if(s.maxItems!==undefined)check(value.length<=s.maxItems,`Schema maxItems ${where}`);if(s.uniqueItems)check(new Set(value.map(x=>JSON.stringify(x))).size===value.length,`Schema uniqueItems ${where}`);if(s.items)value.forEach((v,i)=>schemaCheck(v,s.items,`${where}[${i}]`));}
  if(value&&typeof value==='object'&&!Array.isArray(value)){
    for(const k of s.required||[])check(Object.hasOwn(value,k),`Schema required ${where}.${k}`);
    for(const[k,v]of Object.entries(value)){
      if(s.propertyNames)schemaCheck(k,s.propertyNames,`${where}.key`);
      if(s.properties?.[k])schemaCheck(v,s.properties[k],`${where}.${k}`);
      else if(s.additionalProperties===false)check(false,`Schema additional ${where}.${k}`);
      else if(s.additionalProperties&&typeof s.additionalProperties==='object')schemaCheck(v,s.additionalProperties,`${where}.${k}`);
    }
  }
}
if(fs.existsSync('design/catalog.schema.json'))schemaCheck(D,JSON.parse(fs.readFileSync('design/catalog.schema.json','utf8')),'catalogs');
else warnings.push('Run build.mjs to produce schema and assets before final verification.');
check(D.planets.length===12,'Expected 12 planets');check(D.creatures.length===36,'Expected 36 species');
for(const r of D.resources){refs(r.primary_planets,r.id);if(r.required_tool)ref(r.required_tool,r.id);check(r.inventory_units===1,`Unexpected resource unit ${r.id}`);}
for(const r of D.recipes){
  const manual=r.category==='manual_construction';
  if(manual){
    check(r.station===null&&r.seconds===0&&r.energy_kwh===0,`Manual construction requires no station, time or energy ${r.id}`);
    check(r.output_mode==='immediate_world_placement'&&Object.keys(r.outputs).every(id=>byId.get(id)?.kind==='manual_infrastructure'),`Manual construction must place infrastructure directly ${r.id}`);
    check(!D.modules.some(m=>m.crafting_recipes.includes(r.id)),`Manual recipe must not require a workstation ${r.id}`);
  }else{
    ref(r.station,r.id);
    check(r.seconds>0,`Invalid process timing ${r.id}`);
    check(byId.get(r.station)?.crafting_recipes.includes(r.id),`Station missing recipe ${r.id}`);
  }
  ref(r.research,r.id);quantities(r.inputs,r.id+'.inputs');quantities(r.outputs,r.id+'.outputs');
  check(Number.isFinite(r.seconds)&&r.seconds>=0&&Number.isFinite(r.energy_kwh)&&r.energy_kwh>=0,`Invalid process timing ${r.id}`);
  check(!Object.keys(r.outputs).some(x=>x.startsWith('cur_')),`Currency crafting exploit ${r.id}`);
}
const ladderRecipe=byId.get('recipe_cube_ladder'),ladder=byId.get('mod_ladder'),ladderRule=D.rules.manual_ladders;
check(ladderRecipe?.category==='manual_construction'&&ladderRecipe.research==='tech_start'&&ladderRecipe.batch_limit===1&&Object.keys(ladderRecipe.inputs).length===1&&ladderRecipe.inputs.res_soil===2&&Object.keys(ladderRecipe.outputs).length===1&&ladderRecipe.outputs.mod_ladder===1,'Emergency ladder must immediately consume only 2 soil per placed cell');
check(ladder?.kind==='manual_infrastructure'&&ladder.fabricated_at===null&&ladder.packed_inventory_units===0&&ladder.deployment_seconds===0&&ladder.power_kw===0,'Emergency ladder must not use a cube, station, timer or energy');
check(ladderRule?.module==='mod_ladder'&&ladderRule.recipe==='recipe_cube_ladder'&&ladderRule.station===null&&ladderRule.seconds===0&&ladderRule.energy_kwh===0&&ladderRule.inputs.res_soil===2&&ladderRule.inventory_output===false&&['requires_cube','requires_laboratory','requires_robbie','requires_signal','requires_battery'].every(key=>ladderRule[key]===false)&&D.rules.cubes.excluded_modules.includes('mod_ladder'),'Emergency ladder rules must preserve instant independent field construction');
for(const m of D.modules){ref(m.research,m.id);if(m.fabricated_at)ref(m.fabricated_at,m.id);refs(m.crafting_recipes,m.id);refs(m.services,m.id);if(m.upgrade_track)ref(m.upgrade_track,m.id);check(m.footprint_m.length===2&&m.footprint_m.every(x=>Number.isInteger(x)&&x>0),`Invalid footprint ${m.id}`);check(m.packed_inventory_units>=0&&m.packed_inventory_units<=8,`Uncarryable cube ${m.id}`);for(const p of m.ports)check(p.cell.every((x,i)=>Number.isInteger(x)&&x>=0&&x<m.footprint_m[i]),`Port outside ${m.id}`);}
for(const t of D.research){refs(t.requires_all,t.id);refs(t.requires_any,t.id);refs(t.requires_planet_visits,t.id);refs(t.requires_surveys,t.id);if(t.requires_functional_module)ref(t.requires_functional_module,t.id);quantities(t.cost_items,t.id);quantities(t.cost_currency,t.id);}
for(const p of D.planets){ref(p.required_research,p.id);refs(p.primary_resources,p.id);refs(p.secondary_resources,p.id);refs(p.hazards,p.id);refs(p.ecology_species,p.id);quantities(p.currency_budget,p.id);check(p.ecology_species.length===3,`Expected three species ${p.id}`);for(const o of p.planet_survey_objectives){refs(o.requires_modules,o.id);quantities(o.requires_items,o.id);ref(o.required_research,o.id);}const lumen=p.reward_sources.reduce((n,s)=>n+s.count*s.lumen_each,0);check(lumen===p.currency_budget.cur_lumen,`Lumen source total mismatch ${p.id}`);const core=Object.keys(p.currency_budget).find(x=>x!=='cur_lumen');if(core)check(p.core_sources.reduce((n,s)=>n+s.count*s.cores_each,0)===p.currency_budget[core],`Core source mismatch ${p.id}`);}
for(const u of D.upgrades){if(u.target_module)ref(u.target_module,u.id);u.levels.forEach((l,i)=>{ref(l.required_research,u.id);ref(l.station,u.id);quantities(l.cost_items,u.id);quantities(l.cost_currency,u.id);check(l.level===i+1&&l.requires_previous===i,`Nonsequential level ${u.id}`);check(Object.keys(l.cost_currency).filter(x=>x!=='cur_lumen').length<=1,`Too many core currencies ${u.id}`);});}
for(const c of D.creatures){ref(c.planet,c.id);ref(c.habitat.preferred,c.id);refs(c.habitat.alternatives,c.id);ref(c.habitat.food,c.id);ref(c.bond.research,c.id);ref(c.renewable_output.input,c.id);ref(c.renewable_output.output,c.id);check(c.combat===false,`Combat creature ${c.id}`);check(c.renewable_output.output_units<=c.renewable_output.input_units,`Creature creates ore ${c.id}`);check(c.ability.optional_alternative.length>0,`Creature mandatory ability ${c.id}`);}
for(const h of D.hazards)ref(h.counter_module,h.id);
for(const p of D.planets)for(const deposit of p.deposit_layout){
  ref(deposit.resource,p.id);
  check(deposit.reserved_units===p.guaranteed_resource_units[deposit.resource],`Deposit reserve mismatch ${p.id}.${deposit.resource}`);
  check((deposit.vein_count-1)*deposit.max_units_per_vein+deposit.last_vein_units===deposit.reserved_units,`Deposit vein count mismatch ${p.id}.${deposit.resource}`);
  check(deposit.min_depth_m>=0&&deposit.max_depth_m>=deposit.min_depth_m,`Invalid deposit depth ${p.id}.${deposit.resource}`);
}
for(const c of D.creatures)check(Object.hasOwn(D.rules.creature_system.effect_operations,c.ability.effect.op),`Undefined creature operation ${c.id}`);
for(const t of D.tools)ref(t.research,t.id);
for(const s of D.services){if(s.station)ref(s.station,s.id);ref(s.research,s.id);quantities(s.inputs,s.id);}
for(const route of D.progression.explicit_dependency_paths)refs(route,'progression.explicit_dependency_paths');
const tutorial=D.progression.ocra_tutorial;
const validCondition=c=>c&&typeof c==='object'&&!Array.isArray(c)&&((Object.keys(c).length===1&&typeof c.fact==='string'&&c.fact.length>0)||(Object.keys(c).length===2&&typeof c.counter==='string'&&c.counter.length>0&&Number.isSafeInteger(c.at_least)&&c.at_least>0));
check(tutorial?.version===1&&tutorial.planet==='planet_ocra'&&Array.isArray(tutorial.steps)&&tutorial.steps.length>0&&validCondition(tutorial.finish_when),'Invalid Ocra tutorial definition');
const taskIds=new Set();
for(const step of tutorial?.steps||[]){
  check(typeof step.id==='string'&&/^[a-z][a-z0-9_]*$/.test(step.id)&&!taskIds.has(step.id),`Invalid or duplicate Robbie task ${step.id}`);
  taskIds.add(step.id);
  check(['title_it','hint_it','detail_it'].every(key=>typeof step[key]==='string'&&step[key].length>0),`Missing Robbie task copy ${step.id}`);
  check(['help','fabricate_lab','place_lab','inventory'].includes(step.action)&&validCondition(step.complete_when),`Invalid Robbie task action or condition ${step.id}`);
}
const fabrication=D.progression.prototype_fabrication;
const deviceModules={lamp:'mod_light',pump:'mod_pump',fan:'mod_gas_filter'};
check(fabrication?.version===1&&fabrication.unlock_after==='first_completed_laboratory'&&Array.isArray(fabrication.recipes)&&fabrication.recipes.length===3,'Invalid prototype device fabrication catalog');
const deviceIds=new Set();
for(const recipe of fabrication?.recipes||[]){
  check(Object.hasOwn(deviceModules,recipe.id)&&!deviceIds.has(recipe.id)&&recipe.module===deviceModules[recipe.id],`Invalid prototype device ${recipe.id}`);
  deviceIds.add(recipe.id);
  ref(recipe.module,'prototype_fabrication');quantities(recipe.inputs,`prototype_fabrication.${recipe.id}`);
  check(Object.keys(recipe.inputs||{}).every(id=>['res_soil','res_stone','res_copper'].includes(id)),`Unsupported prototype ingredient ${recipe.id}`);
  check(typeof recipe.name_it==='string'&&recipe.name_it.length>0,`Missing prototype device name ${recipe.id}`);
  check([recipe.seconds,recipe.deployment_seconds].every(n=>Number.isFinite(n)&&n>0&&n<=120)&&Number.isFinite(recipe.energy_kwh)&&recipe.energy_kwh>=0&&recipe.energy_kwh<=60,`Invalid prototype device timing ${recipe.id}`);
}
check(JSON.stringify(D.rules.cubes.fabrication.after_first_completed_laboratory)===JSON.stringify(Object.values(deviceModules)),'Prototype device unlock rules must match fabrication recipes');

// Research prerequisite graph must be acyclic even before material reachability.
const visiting=new Set(),done=new Set();
function visit(id){if(visiting.has(id)){errors.push(`Research cycle ${id}`);return;}if(done.has(id))return;const n=byId.get(id);if(!n)return;visiting.add(id);for(const p of [...n.requires_all,...n.requires_any])visit(p);visiting.delete(id);done.add(id);}
D.research.forEach(t=>visit(t.id));

// Qualitative reachability includes technology, visits, full surveys, tools, stations,
// ingredients and cube fabrication. It deliberately does not claim a timed playthrough.
const knownTech=new Set(D.rules.starting_state.unlocked_research),visited=new Set(),surveyed=new Set();
const items=new Set(Object.keys(D.rules.starting_state.ship_stock));
const modules=new Set(D.rules.starting_state.ship.installed_modules),milestones=new Set();
const unlockedTools=()=>new Set(D.tools.filter(t=>knownTech.has(t.research)).map(t=>t.id));
const hasCost=cost=>Object.keys(cost||{}).every(x=>items.has(x));
const trace=[];
let changed=true,iterations=0;
while(changed&&iterations++<200){
  changed=false;
  const add=(set,id,type)=>{if(!set.has(id)){set.add(id);trace.push({iteration:iterations,type,id});changed=true;}};
  for(const p of D.planets)if(knownTech.has(p.required_research)){
    add(visited,p.id,'visit');
    for(const id of [...p.primary_resources,...p.secondary_resources]){const r=byId.get(id);if(r&&unlockedTools().has(r.required_tool))add(items,id,'gather');}
  }
  for(const r of D.recipes)if(knownTech.has(r.research)&&(r.category==='manual_construction'||modules.has(r.station))&&hasCost(r.inputs))for(const id of Object.keys(r.outputs))add(id.startsWith('mod_')?modules:items,id,'craft');
  if(modules.has('mod_lab'))add(milestones,'first_lab','milestone');
  for(const p of D.planets)if(visited.has(p.id)&&p.planet_survey_objectives.every(o=>knownTech.has(o.required_research)&&o.requires_modules.every(m=>modules.has(m))&&hasCost(o.requires_items)))add(surveyed,p.id,'survey');
  for(const t of D.research)if(t.requires_all.every(x=>knownTech.has(x))&&(!t.requires_any.length||t.requires_any.some(x=>knownTech.has(x)))&&t.requires_planet_visits.every(x=>visited.has(x))&&t.requires_surveys.every(x=>surveyed.has(x))&&(!t.requires_functional_module||modules.has(t.requires_functional_module))&&t.requires_milestones.every(x=>milestones.has(x))&&hasCost(t.cost_items))add(knownTech,t.id,'research');
}
for(const p of D.planets){check(visited.has(p.id),`Unreachable planet ${p.id}`);check(surveyed.has(p.id),`Unreachable survey ${p.id}`);}
for(const t of D.research)check(knownTech.has(t.id),`Unreachable research ${t.id}`);
for(const m of D.modules)check(modules.has(m.id),`Uncraftable module ${m.id}`);
for(const r of D.resources)check(items.has(r.id),`Unobtainable resource ${r.id}`);

// Entry-tier resources must come from an earlier accessible source, not the new world.
for(const p of D.planets){
  const tech=byId.get(p.required_research);
  check(!tech.requires_planet_visits.includes(p.id)&&!tech.requires_surveys.includes(p.id),`Planet requires own visit ${p.id}`);
  for(const id of Object.keys(tech.cost_items)){
    const r=byId.get(id);
    if(r?.kind==='raw')check(r.primary_planets.some(source=>source!==p.id&&byId.get(source).stage<=p.stage),`Entry resource from own locked world ${p.id}: ${id}`);
  }
}
const requiredSpend={};
for(const t of D.research)for(const[k,v]of Object.entries(t.cost_currency))requiredSpend[k]=(requiredSpend[k]||0)+v;
for(const u of D.upgrades)for(const l of u.levels)for(const[k,v]of Object.entries(l.cost_currency))requiredSpend[k]=(requiredSpend[k]||0)+v;
const income={};for(const p of D.planets)for(const[k,v]of Object.entries(p.currency_budget))income[k]=(income[k]||0)+v;
for(const[k,v]of Object.entries(requiredSpend))check((income[k]||0)>=v,`Currency deficit ${k}: ${income[k]||0} < ${v}`);
check(income.cur_lumen>=requiredSpend.cur_lumen*1.25,'Lumen reserve below 25 percent');
check(D.rules.starting_state.world.predug_cells===0,'Starting ground must be untouched');
check(D.rules.survival.health.cache_expiry===null,'Rescue caches must not expire');
check(D.rules.logistics.ship_stock_remote_access===false,'Remote ship stock forbidden');
check(D.rules.robbie_care.forbidden.includes('autonomous_mining'),'Robbie autonomous mining forbidden');
check(D.rules.creature_system.max_companions===3,'Three companion cap required');
check(D.rules.player_progression.xp_to_next_level.length===29,'30 player levels require 29 thresholds');
check(D.rules.ship_progression.sockets_by_level.length===10,'10 ship levels require 10 socket rows');
for(const[id,demand]of Object.entries(D.balance.raw_demand_upper_bound)){
  const guaranteed=D.planets.reduce((n,p)=>n+(p.guaranteed_resource_units[id]||0),0);
  const starter=D.rules.starting_state.ship_stock[id]||0;
  check(guaranteed===D.balance.guaranteed_raw_supply[id],`Raw supply ledger mismatch ${id}`);
  check(guaranteed+starter>=demand,`Raw material deficit ${id}: ${guaranteed+starter} < ${demand}`);
}
for(const c of D.currencies)check((requiredSpend[c.id]||0)>0,`Currency has no sink ${c.id}`);
for(const r of D.resources)check(D.recipes.some(x=>Object.hasOwn(x.inputs,r.id))||D.research.some(x=>Object.hasOwn(x.cost_items,r.id))||D.upgrades.some(u=>u.levels.some(l=>Object.hasOwn(l.cost_items,r.id)))||D.services.some(s=>Object.hasOwn(s.inputs,r.id)),`Resource has no consumer ${r.id}`);

const assetManifest=fs.existsSync('assets/design/manifest.json')?JSON.parse(fs.readFileSync('assets/design/manifest.json','utf8')):null;
if(assetManifest){
  for(const e of assetManifest.entries)for(const k of ['icon','tile','material'])if(e[k])check(fs.existsSync(e[k]),`Missing ${e[k]}`);
  for(const e of assetManifest.concepts)check(fs.existsSync(e.path),`Missing concept ${e.path}`);
  const iconSet=new Set(assetManifest.entries.map(e=>e.id));
  for(const e of all.filter(x=>!x.id.startsWith('recipe_')))check(iconSet.has(e.id),`Missing entity icon ${e.id}`);
}
const report={ok:!errors.length,errors,warnings,counts:{planets:D.planets.length,resources:D.resources.length,recipes:D.recipes.length,modules:D.modules.length,research:D.research.length,upgrades:D.upgrades.length,upgrade_levels:D.upgrades.reduce((n,u)=>n+u.levels.length,0),creatures:D.creatures.length,hazards:D.hazards.length,icons:assetManifest?.entries.length||0},reachability:{iterations,planets:visited.size,surveys:surveyed.size,research:knownTech.size,resources:D.resources.filter(r=>items.has(r.id)).length,portable_equipment:D.items.filter(r=>items.has(r.id)).length,modules:modules.size,scope:'qualitative_reference_and_unlock_feasibility_not_runtime_simulation'},raw_budget:{reference_build:D.balance.reference_scope,sufficient:true,excludes:'repeat_fuel_food_medicine_and_extra_construction'},currency:{income,cost:requiredSpend},trace};
fs.mkdirSync('docs/design',{recursive:true});fs.writeFileSync('docs/design/validation-report.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,trace:undefined},null,2));
process.exitCode=errors.length?1:0;
