import fs from 'node:fs';
import path from 'node:path';

const cwd=process.cwd();
const manifest=JSON.parse(fs.readFileSync('design/v1/manifest.json','utf8'));
const D=Object.fromEntries(Object.entries(manifest.catalogs).map(([k,v])=>[k,JSON.parse(fs.readFileSync(`design/v1/${v}`,'utf8'))]));
const write=(file,text)=>{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,text);};
const esc=x=>String(x??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const all=Object.values(D).filter(Array.isArray).flat();
const entities=new Map(all.filter(x=>x.id).map(x=>[x.id,x]));
const label=id=>id===null?'Sul campo':entities.get(id)?.name_it||id;
const cost=obj=>Object.entries(obj||{}).map(([id,n])=>`${n} ${label(id)}`).join(' + ')||'—';
const shade=(hex,f)=>'#'+[1,3,5].map(i=>Math.round(Math.min(255,Math.max(0,parseInt(hex.slice(i,i+2),16)*f))).toString(16).padStart(2,'0')).join('');
const hash=s=>[...s].reduce((n,c)=>(Math.imul(n,31)+c.charCodeAt(0))>>>0,17);

function pictogram(shape){
  const p={
    rock:'<path d="m15 39 5-17 18-8 13 16-6 18-21 3z"/><path d="m20 22 15 12 16-4M35 34l-3 16"/>',
    ore:'<path d="m14 38 9-18 19 1 10 17-14 13-19-4z"/><path d="m23 20 10 13 9-12M33 33l5 18M14 38l19-5 19 5"/>',
    soil:'<path d="m13 34 13-15 22 5 4 18-18 9-20-7z"/><path d="m16 39 17-8 15 6M27 22l4 7"/>',
    grain:'<path d="m16 37 5-11 10 3 2 13-10 6zM33 25l6-11 11 6-2 13-11 2zM38 42l7-7 10 8-6 9z"/>',
    crystal:'<path d="m20 22 12-12 12 12-4 24-8 9-12-12z"/><path d="m20 22 12 6 12-6M32 10v18l8 18M32 28l-12 15"/>',
    droplet:'<path d="M32 12C27 23 16 31 16 40a16 16 0 0 0 32 0c0-9-11-17-16-28z"/><path d="M24 38c-3 7 1 11 6 11"/>',
    leaf:'<path d="M48 15C19 11 9 27 19 42c10 13 30 5 29-27z"/><path d="m16 51 24-26M27 39l-4-12M33 32l12 3"/>',
    vial:'<path d="M25 13h14M27 13v15l-10 16q-2 8 7 8h16q9 0 7-8L37 28V13M22 37h20"/><path d="M28 43h3m5 3h3"/>',
    canister:'<rect x="19" y="19" width="27" height="34" rx="6"/><path d="M26 19v-7h13v7M20 32h25M32 37v9m-4-5h8"/>',
    pearl:'<circle cx="32" cy="33" r="19"/><path d="M23 27q4-8 13-7M25 44q7 5 15-1"/>',
    plate:'<path d="m12 29 24-13 17 10-24 15zM12 29v10l17 14 24-17V26M29 41v12"/>',
    ingot:'<path d="m14 33 7-16h25l7 16-11 17H23z"/><path d="M14 33h39M21 17l6 16-4 17m23-33-7 16 3 17"/>',
    coil:'<path d="M19 42c-16-30 4-38 5-10 2 36 13 19 10-8-3-19 17-16 12 4-3 11 2 17 8 15"/><path d="m12 39 7 3m27 1h8"/>',
    chip:'<rect x="19" y="19" width="27" height="27" rx="4"/><path d="M26 26h13v13H26zM13 24h6m-6 9h6m-6 9h6m27-18h6m-6 9h6m-6 9h6M24 13v6m9-6v6m9-6v6M24 46v6m9-6v6m9-6v6"/>',
    filter:'<rect x="17" y="16" width="31" height="36" rx="5"/><path d="M24 23h17M24 30h17M24 37h17M24 44h17"/>',
    roll:'<path d="M22 17c-15 0-15 29 0 29h24V17z"/><ellipse cx="23" cy="32" rx="9" ry="15"/><ellipse cx="23" cy="32" rx="3" ry="6"/>',
    battery:'<rect x="17" y="17" width="32" height="34" rx="5"/><path d="M25 17v-6h16v6m-6 12-9 10h8l-3 9 11-14h-8z"/>',
    med:'<rect x="16" y="18" width="34" height="33" rx="6"/><path d="M25 18v-7h16v7M33 27v16m-8-8h16"/>',
    frame:'<path d="M15 17h35v35H15zM23 25h19v19H23zM15 17l8 8m19 0 8-8M23 44l-8 8m27-8 8 8"/>',
    shield:'<path d="m32 12 20 8v15q0 14-20 21Q12 49 12 35V20z"/><path d="m21 33 8 8 15-17"/>',
    lens:'<circle cx="30" cy="30" r="17"/><path d="m43 43 12 12M21 28q3-9 12-9"/>',
    foam:'<path d="M13 24 32 13l21 11v23L32 56 13 45z"/><circle cx="26" cy="30" r="4"/><circle cx="41" cy="34" r="5"/><circle cx="29" cy="44" r="3"/>',
    lamp:'<path d="M21 20h22l8 20H13zM32 40v12M22 53h20M32 11v-5M14 19l-6-4m42 4 6-4"/>',
    ladder:'<path d="M21 10v46m22-46v46M21 19h22M21 31h22M21 43h22"/>',
    lab:'<path d="M14 49h39M20 47V23h15v24M23 23V12h9v11M41 14v14l-7 15q-1 5 5 5h10q6 0 5-5l-7-15V14M37 14h14M38 37h13"/>',
    crate:'<path d="M13 19h39v33H13zM13 30h39M24 19v11m17-11v11M26 39h13M26 45h13"/>',
    factory:'<path d="M12 51V27l13 7V22l15 9V14h11v37zM20 42h5m7 0h5m7 0h3"/>',
    arch:'<path d="M12 53V28q20-33 40 0v25H41V30q-9-15-18 0v23zM12 38h11m18 0h11M27 17v10m10-10v10"/>',
    door:'<path d="M17 54V12h32v42M23 19h20v35H23zM36 37h3"/>',
    airlock:'<path d="M12 52V16h13v36m14 0V16h13v36M25 22h14m-14 24h14m-8-13h8m-4-4 4 4-4 4"/>',
    air:'<path d="M12 26h29q13 0 8-10-5-7-10 0M12 35h39M12 44h23q13 0 8 9-5 7-10 0"/>',
    solar:'<path d="m13 25 29-9 11 25-29 9zM22 22l10 25m0-28 10 25M18 34l29-9M32 49v8m-10 0h22M13 11V5m-7 9-4-3m19-1 4-5"/>',
    thermo:'<path d="M24 16a8 8 0 0 1 16 0v23a12 12 0 1 1-16 0zM32 24v23M46 19h9m-9 10h6"/>',
    pump:'<path d="M13 33h10m18 0h12V19H43M23 22h18v25H23zM32 16v6M16 47h32M31 29l-4 9h9"/>',
    tank:'<ellipse cx="32" cy="17" rx="19" ry="8"/><path d="M13 17v31q19 14 38 0V17M14 36q18 9 36 0"/>',
    relay:'<path d="M32 54V26m-10 28h20M23 20q-9 8 0 16m18-16q9 8 0 16M16 13q-17 15 0 30m32-30q17 15 0 30"/><circle cx="32" cy="27" r="4"/>',
    greenhouse:'<path d="M13 49V26l19-15 20 15v23zM32 11v38M13 26h39M19 42q0-14 12-5m2 5q10-16 15-7"/>',
    habitat:'<path d="M12 49V27a20 20 0 0 1 40 0v22zM13 42h39"/><circle cx="31" cy="31" r="8"/><path d="m25 25-3-6m16 6 3-6M27 31h1m7 0h1"/>',
    aquarium:'<path d="M12 17h41v35H12zM13 29q9-7 19 0t20 0M25 37q10-9 16 0-7 10-16 0l-7 7V31z"/>',
    aviary:'<path d="M13 53V25l19-15 20 15v28M13 25h39M22 53V25m20 28V25M25 37q8-10 17 0M32 34v11"/>',
    sanctuary:'<path d="M10 52V25l22-15 22 15v27zM10 36h44M24 52V36m17 16V36M22 24h4m12 0h4"/>',
    drone:'<path d="M17 25h30v22H17zM32 18v7M25 14h14M7 28h10m30 0h10M7 24v8m50-8v8M23 52h18"/><circle cx="32" cy="35" r="6"/>',
    fuel:'<path d="M15 51V20h25v31M20 27h15v10H20zM40 26h7l6 9v13q0 7-7 0V36M11 52h34M45 18l9 8"/>',
    generator:'<path d="m15 19 17-9 18 9v30l-18 8-17-8zM23 24h18v20H23zM35 26l-8 10h8l-5 8"/>',
    radar:'<path d="M17 14q-7 32 26 29zM21 19l23 23M31 43v11m-11 0h25M40 10q16 0 16 16M41 18q7 0 7 7"/>',
    beacon:'<path d="M24 53V24h16v29M18 53h28M25 31h14M25 41h14M32 8v8M18 15l5 6m23-6-5 6"/><circle cx="32" cy="20" r="5"/>',
    pipe:'<path d="M13 18h20v17h20v17H24V35H13zM13 15v23M50 32v23"/>',
    cable:'<path d="M17 12v10q0 12 15 12t15 13v8M11 12h12m18 43h12M17 25h-8m46 21h-8"/>',
    drain:'<path d="M12 24h41v17H12zM19 24v17m9-17v17m9-17v17m9-17v17M24 48l8 8 8-8m-8-1v9"/>',
    archive:'<path d="M14 15h38v40H14zM21 22h24v7H21zM21 35h24M21 43h24M25 48h16"/>',
    engine:'<path d="m24 15 17-5 7 23-25 8zM23 41l-7 10 9-1 3 8 9-14M27 24l14-4"/>',
    rocket:'<path d="M32 9Q18 22 22 43h20Q46 22 32 9zM22 33l-9 17 10-4m19-13 9 17-10-4M27 49l5 9 5-9"/><circle cx="32" cy="29" r="6"/>',
    suit:'<circle cx="32" cy="20" r="11"/><path d="M24 30 17 43l6 4 5-10v19m8-19v19M40 30l7 13-6 4M25 34h14M28 56h-8m16 0h8"/>',
    scan:'<circle cx="30" cy="29" r="17"/><path d="m43 42 12 12M19 29h22M30 18v22M10 13V7h8m27 0h8v8"/>',
    tool:'<path d="m20 16 29 8-5 13-13-4-9 22-11-5 11-24-5-2zM31 16l4-7 16 6-2 9"/>',
    research:'<path d="M22 12h20M26 12v17L13 47q-2 6 7 6h24q9 0 7-6L38 29V12M20 38h24M25 45h2m9 2h2"/>',
    hazard:'<path d="m32 11 24 42H8zM32 24v14m0 8v1"/>',
    snow:'<path d="M32 9v47M12 20l40 25M12 45l40-25M26 13l6 6 6-6M26 52l6-6 6 6M13 27l8-1-1-8m24 29-1-8 8-1"/>',
    gas:'<path d="M14 43q-12-12 1-18 0-17 17-11 12-8 17 5 18 0 9 18 7 14-9 16H21q-13 0-7-10zM25 28v6m15-6v6M27 43q6-5 12 0"/>',
    bolt:'<path d="m37 9-21 27h14l-4 20 23-29H35z"/>',
    patch:'<path d="m13 27 14-14 26 26-14 14zM24 24l16 16M20 31l13 13M31 20l13 13"/>',
    ring:'<ellipse cx="32" cy="32" rx="22" ry="14"/><ellipse cx="32" cy="32" rx="12" ry="6"/>',
  };
  return p[shape]||p.crate;
}
function alien(e){
  const v=e.visual.variant||0;
  const eyes=1+v%3;
  const eyeMarkup=Array.from({length:eyes},(_,i)=>`<ellipse cx="${32+(i-(eyes-1)/2)*12}" cy="32" rx="${eyes===1?10:5}" ry="7" fill="#eef9f5" stroke="#142735"/><circle cx="${33+(i-(eyes-1)/2)*12}" cy="33" r="3" fill="#142735" stroke="none"/>`).join('');
  const appendages=v%4===0?'<path d="m17 32-11-9 7 18m34-9 11-9-7 18"/>':v%4===1?'<path d="m21 19-6-9m28 9 6-9M14 11h3m30 0h3"/>':v%4===2?'<path d="m14 33-8 4 9 6m34-10 9 4-9 6"/>':'<path d="m21 20 4-12 9 7 9-7 3 14"/>';
  return `${appendages}<path d="M15 37Q10 19 29 17q20-4 21 18 7 17-17 18Q14 54 15 37z"/><path d="m20 49-3 7m14-5v7m12-9 4 7"/>${eyeMarkup}<path d="M28 44q5 6 10-1" stroke="#142735"/>`;
}
function icon(e){
  const color=e.visual?.color||e.palette?.sky||'#94c9c5';
  let body;
  if(e.id.startsWith('planet_'))body=`<circle cx="32" cy="32" r="23" fill="${color}"/><path d="m18 16 14 7 4 14-11 7-13-13zM44 16l9 17-9 10-4-13z" fill="${shade(color,0.75)}" stroke="none"/><path d="M8 43q25 9 48-13" fill="none" stroke="${shade(color,1.3)}"/>`;
  else if(e.id.startsWith('species_'))body=alien(e);
  else if(e.kind==='manual_infrastructure')body=pictogram(e.visual?.shape);
  else if(e.id.startsWith('mod_'))body=`<path d="m9 20 23-12 23 12v28L32 60 9 48z" fill="${shade(color,0.5)}"/><path d="m9 20 23 12 23-12-23-12z" fill="${shade(color,1.2)}"/><path d="M32 32v28l23-12V20z" fill="${shade(color,0.72)}"/><g transform="translate(7 8) scale(.76)" fill="none" stroke="#edf4df" stroke-width="3">${pictogram(e.visual?.shape)}</g>`;
  else body=pictogram(e.visual?.shape||'research');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><title>${esc(e.name_it)}</title><g fill="${color}" stroke="${shade(color,0.55)}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">${body}</g></svg>\n`;
}
for(const e of [...D.services,...D.recipes]){
  if(!e.icon){e.icon=e.outputs?entities.get(Object.keys(e.outputs)[0])?.icon:`assets/design/icons/${e.id}.svg`;e.visual={color:'#a9c9ae',shape:'med'};}
}
const assetEntities=all.filter(e=>e.id&&!e.id.startsWith('recipe_'));
for(const e of assetEntities)write(`assets/design/icons/${e.id}.svg`,icon(e));
for(const r of D.resources){
  const c=r.visual.color;
  const seed=hash(r.id);
  let motif='';
  for(let i=0;i<9;i++){
    const x=(seed+i*23)%64,y=((seed>>>7)+i*37)%64,s=4+(seed+i)%8;
    for(const dx of [-64,0,64])for(const dy of [-64,0,64]){
      const a=x+dx,b=y+dy;
      motif+=`<path d="m${a} ${b-s} ${s} ${s/2} ${s/2} ${s} -${s} ${s/2} -${s/2} -${s}z" fill="${shade(c,i%2?0.8:1.13)}"/>`;
    }
  }
  write(r.visual.tile,`<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 64 64"><title>${esc(r.name_it)} periodic surface prototype</title><defs><clipPath id="tile"><rect width="64" height="64"/></clipPath></defs><rect width="64" height="64" fill="${c}"/><g clip-path="url(#tile)">${motif}</g></svg>\n`);
  write(r.visual.material,`[gd_resource type="StandardMaterial3D" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://${r.visual.tile}" id="1"]\n\n[resource]\nresource_name = "${r.id}"\nalbedo_texture = ExtResource("1")\nmetallic = ${r.visual.metallic}\nroughness = ${r.visual.roughness}\n`);
}
const assetManifest={version:'1.0.0',reference:'refs/Space_Digger.png',style:'friendly_alien_faceted_3d_target; vector_inventory_prototypes',icon_viewbox:[64,64],entries:assetEntities.map(e=>({id:e.id,icon:`assets/design/icons/${e.id}.svg`,...(e.id.startsWith('res_')?{tile:e.visual.tile,material:e.visual.material}:{})})),concepts:[{path:'assets/design/concepts/creatures-36-alien.png',role:'preferred_3d_creature_direction',order:D.creatures.map(x=>x.id),grid:[6,6]},{path:'assets/design/concepts/creatures-36.png',role:'earlier_reference_retained'}],not_included:['animated_sprites','rigged_3d_models','final_PBR_normal_roughness_maps']};
write('assets/design/manifest.json',JSON.stringify(assetManifest,null,2)+'\n');

function table(headers,records){return `| ${headers.join(' | ')} |\n| ${headers.map(()=> '---').join(' | ')} |\n`+records.map(row=>`| ${row.map(x=>String(x??'—').replaceAll('|','/').replaceAll('\n',' ')).join(' | ')} |`).join('\n')+'\n';}
const intro=(title,source)=>`# ${title}\n\nCatalogo generato da [${source}](../../design/v1/${source}). Modificare il JSON e rieseguire \`node tools/design/build.mjs\`. Numeri di bilanciamento iniziali, da provare nel gioco.\n\n`;
write('docs/design/resources.md',intro('Risorse e materiali','resources.json')+table(['ID','Risorsa','Tipo','Fase','Fonte primaria','Uso'],D.resources.map(r=>[r.id,r.name_it,r.kind,r.stage,r.primary_planets.map(label).join(', ')||'Ricetta',r.use])));
const manualNote=`Le scale sono costruzione manuale immediata sul posto: ${cost(D.rules.manual_ladders.inputs)}, zero secondi e zero energia. Nessun cubo, officina, laboratorio, Robbie o segnale; l'output e direttamente la scala attiva nel mondo, non un oggetto nello zaino. L'ID storico recipe_cube_ladder resta stabile, ma non indica un cubo.\n\n`;
const utilityNote='## Prototipo giocabile: cubi di servizio\n\nDa progression.prototype_fabrication: luce, pompa acqua e ventilatore gas si sbloccano dopo il primo laboratorio completato, con materiali comuni e cubi fisici. Queste tre ricette semplificate appartengono alla tranche attuale; il catalogo completo sotto resta il progetto della successiva economia planetaria.\n\n'+table(['Oggetto','Ingredienti','Secondi L1','kWh fabbricazione','Secondi apertura'],D.progression.prototype_fabrication.recipes.map(r=>[r.name_it,cost(r.inputs),r.seconds,r.energy_kwh,r.deployment_seconds]))+'\n## Catalogo completo proposto\n\n';
write('docs/design/recipes.md',intro('Ricette e postazioni','recipes.json')+manualNote+utilityNote+table(['ID','Postazione','Ricerca','Ingredienti','Risultato','Secondi','kWh'],D.recipes.map(r=>[r.id,label(r.station),label(r.research),cost(r.inputs),cost(r.outputs),r.seconds,r.energy_kwh]))+'\n## Servizi di cura e manutenzione\n\n'+table(['ID','Postazione','Ingredienti','Effetti','Secondi'],D.services.map(s=>[s.id,label(s.station)||'Sul campo',cost(s.inputs),JSON.stringify(s.effects),s.seconds])));
write('docs/design/modules.md',intro('Cubi installabili e funzioni','modules.json')+manualNote+table(['ID','Modulo','Fase','Aperto X per Y m','Carico chiuso','kW','Deposito','Aggancio'],D.modules.map(m=>[m.id,m.name_it,m.stage,m.footprint_m.join(' × '),m.packed_inventory_units,m.power_kw,m.cache_units,m.mount]))+'\n'+D.modules.map(m=>`## ${m.name_it}\n\n- ID: \`${m.id}\`. Ricerca: ${label(m.research)}.\n- Funzioni: ${m.functions.join(', ')}.\n- Costruisce: ${m.crafting_recipes.map(id=>label(id)).join('; ')||'nessuna ricetta; modulo di servizio'}.\n- Cura e servizi: ${m.services.map(label).join('; ')||'—'}.\n- Upgrade: ${m.upgrade_track||'nessun livello locale'}; ingombro invariato.\n`).join('\n'));
write('docs/design/planets.md',intro('Pianeti e dipendenze','planets.json')+table(['ID','Pianeta','Fase','Accesso','Risorse principali','Carburante rotta','Lumen garantiti'],D.planets.map(p=>[p.id,p.name_it,p.stage,label(p.required_research),p.primary_resources.map(label).join(', '),p.route_fuel,p.currency_budget.cur_lumen]))+'\n'+D.planets.map(p=>`## ${p.name_it}\n\n- Primo sito: ${p.landing_biome}; raggio sicuro ${p.safe_landing_radius_m} m.\n- Pericoli: ${p.hazards.map(label).join(', ')}.\n- Rilievo: ${p.planet_survey_objectives.map(o=>o.name_it).join('; ')}.\n- Valute garantite: ${cost(p.currency_budget)}. Ricompense assegnate una volta per sorgente.\n- Specie: ${p.ecology_species.map(label).join(', ')}.\n`).join('\n'));
write('docs/design/research.md',intro('Ricerca e progressione','research.json')+table(['ID','Ricerca','Prerequisiti','Visite','Rilievi completi','Materiali','Cristalli'],D.research.map(t=>[t.id,t.name_it,t.requires_all.map(label).join(', '),t.requires_planet_visits.map(label).join(', '),t.requires_surveys.map(label).join(', '),cost(t.cost_items),cost(t.cost_currency)]))+'\n## Prime azioni\n\n'+table(['Passo','Minuto obiettivo','Azione','Verifica'],D.progression.onboarding.map(x=>[x.step,x.target_minute,x.goal,x.completion]))+'\n## Fasi\n\n'+table(['Fase','Pianeti','Sistemi introdotti','Obiettivo di cura'],D.progression.stages.map(s=>[s.stage,s.planets.map(label).join(', '),s.systems.join(', '),s.care])));
fs.appendFileSync('docs/design/research.md','\n## Compiti Robbie / Ocra\n\nQuesta sequenza fino al primo laboratorio e letta dal runtime da progression.ocra_tutorial. I tempi sopra sono obiettivi di bilanciamento, non attese o blocchi.\n\n'+table(['ID','Obiettivo','Completamento','Azione'],D.progression.ocra_tutorial.steps.map(step=>[step.id,step.title_it,JSON.stringify(step.complete_when),step.action])));
write('docs/design/upgrades.md',intro('Potenziamenti e valute','upgrades.json')+`Lumen garantiti: **${D.rules.currency_economy.guaranteed_common_total}**. Costo di tutte le ricerche e di tutti i livelli: **${D.rules.currency_economy.costs_total_all_research_and_upgrades}**. Nuclei specifici finiti, con riserva; nessun nucleo necessario per raggiungere il proprio pianeta di origine.\n\n`+table(['ID','Proprietario','Valore iniziale','Livelli','Ricerca per livello','Materiali per livello','Valute per livello'],D.upgrades.map(u=>[u.id,u.owner,JSON.stringify(u.baseline),u.levels.map(l=>JSON.stringify(l.value)).join(' → '),u.levels.map(l=>label(l.required_research)).join('; '),u.levels.map(l=>cost(l.cost_items)).join('; '),u.levels.map(l=>cost(l.cost_currency)).join('; ')])));
write('docs/design/creatures.md',intro('Specie habitat e cooperazione','creatures.json')+'Nessun combattimento. Osservazione → fiducia → trasporto volontario → habitat adatto → aiuto facoltativo. Le capacità delle creature hanno sempre alternative tecnologiche. Nessuna specie crea metalli o cristalli dal nulla.\n\n'+table(['ID','Nome','Pianeta','Ambiente','Habitat','Aiuto','Alimento'],D.creatures.map(c=>[c.id,c.name_it,label(c.planet),c.biome,label(c.habitat.preferred),c.ability.id,label(c.habitat.food)]))+'\n## Direzione visiva\n\nReference: `refs/Space_Digger.png`. Tavola preferita: [36 creature aliene 3D](../../assets/design/concepts/creatures-36-alien.png). Ordine per righe uguale al catalogo: tre specie per pianeta. La tavola guida modelli e animazioni futuri; le icone SVG hanno lo stesso ID del catalogo.\n');
write('docs/design/hazards.md',intro('Pericoli e contromisure','hazards.json')+table(['ID','Pericolo','Fase','Segnale','Danno salute ogni 10 s','Contromisure','Recupero'],D.hazards.map(h=>[h.id,h.name_it,h.stage,h.telegraph,h.damage_health_per_10s,h.counter_tags.join(', '),h.recovery])));
write('docs/design/interface.md',intro('Interfaccia e stati','gui.json')+table(['ID','Schermata','Pannelli','Azione primaria','Pausa'],D.gui.screens.map(s=>[s.id,s.name_it,s.panels.join(', '),s.primary,s.world_paused]))+'\n## Errori utilizzabili dal codice\n\n'+table(['Codice','Messaggio'],D.gui.error_codes.map(e=>[e.id,e.text_it]))+'\n## Prototipo interattivo\n\nAprire [l’anteprima](../../design/preview/index.html) per consultare cataloghi, ingredienti, dipendenze e i flussi di costruzione, navigazione e cura. Il prototipo usa i dati JSON incorporati dal generatore; non modifica salvataggi o runtime.\n');

// A practical draft 2020-12 contract for reading all files as one aggregate object.
const qtySchema={type:'object',propertyNames:{pattern:'^(res_|mod_|cur_|item_)'},additionalProperties:{type:'integer',minimum:1}};
const ref={type:'string',minLength:3};
const arr={type:'array',items:ref,uniqueItems:true};
const entity=(required,properties={})=>({type:'object',required:['id','name_it',...required],properties:{id:{type:'string',pattern:'^[a-z]+_[a-z0-9_]+$'},name_it:{type:'string',minLength:1},...properties},additionalProperties:true});
const types={
 resources:entity(['kind','stage','inventory_units','icon','visual'],{kind:{enum:['raw','processed']},stage:{type:'integer',minimum:0,maximum:7},inventory_units:{const:1}}),
 recipes:entity(['station','research','inputs','outputs','seconds','energy_kwh'],{station:{type:['string','null'],minLength:3},research:ref,inputs:qtySchema,outputs:qtySchema,seconds:{type:'number',minimum:0},energy_kwh:{type:'number',minimum:0}}),
 modules:entity(['footprint_m','packed_inventory_units','research','ports','crafting_recipes'],{footprint_m:{type:'array',items:{type:'integer',minimum:1},minItems:2,maxItems:2},packed_inventory_units:{type:'integer',minimum:0},crafting_recipes:arr}),
 research:entity(['requires_all','requires_any','requires_planet_visits','requires_surveys','cost_items','cost_currency'],{requires_all:arr,requires_any:arr,cost_items:qtySchema,cost_currency:qtySchema}),
 planets:entity(['required_research','primary_resources','currency_budget','planet_survey_objectives'],{primary_resources:arr,currency_budget:qtySchema}),
 upgrades:entity(['owner','stat','baseline','levels'],{owner:{enum:['player','ship','robbie','module']},levels:{type:'array',minItems:1}}),
 creatures:entity(['planet','habitat','bond','ability','combat'],{planet:ref,combat:{const:false}}),
 hazards:entity(['stage','telegraph','counter_module','damage_health_per_10s'],{counter_module:ref}),
 currencies:entity(['kind','physical_inventory','repeatable'],{physical_inventory:{const:false},repeatable:{const:false}}),
 tools:entity(['research','mode','icon']),services:entity(['station','research','inputs','effects'],{inputs:qtySchema}),items:entity(['kind','stage','inventory_units','icon'])
};
const schema={$schema:'https://json-schema.org/draft/2020-12/schema',$id:'urn:rocketman:design:v1',title:'RocketMan aggregate design catalogs',type:'object',required:Object.keys(D),properties:Object.fromEntries(Object.keys(D).map(k=>[k,types[k]?{type:'array',items:types[k]}:{type:'object'}])),additionalProperties:false};
write('design/catalog.schema.json',JSON.stringify(schema,null,2)+'\n');

// Standalone preview, no server required and no network dependencies.
const payload=JSON.stringify(D).replaceAll('<','\\u003c');
const html=fs.readFileSync('tools/design/preview.template.html','utf8').replace('/*__DESIGN_DATA__*/',`const D=${payload};`);
write('design/preview/index.html',html);
const counts=Object.fromEntries(Object.entries(D).filter(([,x])=>Array.isArray(x)).map(([k,v])=>[k,v.length]));
write('docs/design/counts.json',JSON.stringify({...counts,upgrade_levels:D.upgrades.reduce((n,u)=>n+u.levels.length,0),icons:assetEntities.length,tiles:D.resources.length,materials:D.resources.length},null,2)+'\n');
console.log(JSON.stringify({generated:true,counts,icons:assetEntities.length,resource_surfaces:D.resources.length}));
