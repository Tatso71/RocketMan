import { mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = fileURLToPath(new URL('../../', import.meta.url));
const entries = {};
const add = (id, name, body) => { entries[id] = { name, body }; };
const p = (d, fill, extra = '') => `<path d="${d}" fill="${fill}" ${extra}/>`;
const rect = (x, y, w, h, fill) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="2" fill="${fill}"/>`;
const circle = (x, y, r, fill) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}"/>`;
const line = d => p(d, 'none');
const bolt = p('M36 14 22 34h11l-5 17 16-23H33z', '#ffe289');
const housing = rect(9, 19, 46, 34, '#91acb4') + p('M9 19 20 10h25l10 9z', '#d7e5e6') + rect(15, 25, 34, 23, '#24484f');

add('copper', 'Rame', p('m9 39 7-19 19-7 17 15 3 17-23 10z', '#d88653') + p('m16 20 16 14 3-21 17 15-20 6 0 21', '#f3bf80') + line('M9 39 32 34l23 11'));
add('iron', 'Ferro', p('m10 29 13-16 23 4 10 23-19 14-23-6z', '#91a7b0') + p('m23 13 6 22 17-18 10 23-27-5 8 19', '#cbd9de') + line('M10 29 29 35 14 48'));
add('crystal', 'Cristallo', p('m12 39 4-20 12 6 6-18 15 16 4 20-20 15z', '#48b6bb') + p('m34 7 0 34 15-18M16 19l9 26 3-20M12 39l21 19 1-17 19 2', '#a9f5e7') + line('m25 45 9-4'));
add('silica', 'Quarzo', p('m11 43 3-18 11-11 10 8 7-10 12 21-6 17-23 7z', '#cad7de') + p('m14 25 11-11 0 29-14 0m24-21 7-10 2 33-19-2', '#f1f1e9') + line('m25 43 10-21M44 45l10-12'));
add('cobalt', 'Cobalto', p('m10 35 12-22 19 2 14 17-9 20-24 3z', '#596baf') + p('m22 13 7 21 12-19 14 17-26 2-7 21', '#a4bef2') + p('m29 34 17 18-24 3z', '#778de0') + circle(39, 30, 3, '#e2e9ff'));
add('bedrock', 'Roccia compatta', p('m8 27 15-15 24 5 10 23-17 16-27-7z', '#647582') + p('m23 12 8 23 16-18 10 23-26-5 9 21', '#a6b6bf') + line('M12 37h14m10 9h14m-26-22 15 4') + p('M24 33h17v16H24z', '#d6c58c') + p('M28 33v-5q5-9 9 0v5', 'none', 'stroke="#d6c58c" stroke-width="4"'));
add('anchor', 'Indistruttibile', p('m8 27 14-16 26 7 9 22-18 16-26-7z', '#66777c') + p('m22 11 9 24 17-17 9 22-26-5 8 21', '#aab7ad') + p('M24 28h17v20H24z', '#e8b28f') + p('M27 28v-5q6-10 11 0v5', 'none', 'stroke="#e8b28f" stroke-width="4"') + circle(32, 36, 2, '#394f59') + line('M32 36v6'));
add('structural_component', 'Componente strutturale', p('m11 20 12-7 30 13-12 7z', '#e5d6a5') + p('m11 20 30 13v20L11 40z', '#bc9f64') + p('m41 33 12-7v20l-12 7z', '#8b794f') + line('m20 24 0 16m10-12v16M14 34l24 10') + circle(17, 28, 2, '#f7edcb') + circle(35, 37, 2, '#f7edcb'));
add('electronic_component', 'Componente elettronico', rect(12, 12, 40, 40, '#439d87') + rect(23, 23, 18, 18, '#213b45') + p('M27 8v15m10-15v15M27 41v15m10-15v15M8 27h15M8 37h15m18-10h15M41 37h15', 'none', 'stroke="#dec77c" stroke-width="4"') + circle(18, 18, 2, '#cbf7d5') + line('m18 45 0-10 5-4'));
add('copper_ingot', 'Lingotto di rame', p('m13 24 30-8 12 17-29 11L8 36z', '#eac093') + p('m8 36 18 8 29-11v10l-29 12-18-9z', '#bd7249') + p('m26 44 29-11v10L26 55z', '#d99764') + line('m18 25 21-5'));
add('glass', 'Vetro', p('m15 14 35 5-7 35-32-9z', '#8dcfd8') + p('m15 14 7 9-6 18 27 13 7-35z', '#c6f1ef') + p('m23 19 10 2-14 24-3-4z', '#f4fffa', 'stroke="none"') + line('m27 45 15-18'));

add('water', 'Acqua', p('M32 7C27 20 13 29 13 40a19 19 0 0 0 38 0C51 29 37 20 32 7z', '#4aaecf') + p('M32 7c2 19 19 31 8 43-6 6-16 7-23-1 7 14 33 12 34-9C51 29 37 20 32 7z', '#27859f') + line('M22 34q-7 12 4 16'));
add('acid', 'Acido', p('M32 7C25 22 13 30 13 41a19 19 0 0 0 38 0C51 30 39 22 32 7z', '#a8ce58') + p('m25 31 6 7-6 7m14-14-6 7 6 7', 'none', 'stroke="#24484f" stroke-width="4"') + circle(49, 14, 4, '#d8e9a0'));
add('oil', 'Petrolio', p('M32 7C27 20 13 29 13 40a19 19 0 0 0 38 0C51 29 37 20 32 7z', '#394351') + p('M22 28q-10 14 1 21', 'none', 'stroke="#a7abc9" stroke-width="5"') + line('M30 53q15 0 15-13'));
add('gas', 'Gas', p('M12 46C1 39 8 25 18 27 15 10 35 7 41 20c12-7 23 11 12 19 5 13-11 21-20 13-9 10-25 4-21-6z', '#c4d286') + p('M18 39q5-9 12-2t16-2M24 25q5-5 9 0', 'none', 'stroke="#6c8d63" stroke-width="3"'));

add('laboratory', 'Laboratorio', housing + rect(18, 29, 17, 13, '#71d5cf') + p('M42 26v9l5 8H36l4-8v-9', '#dbe6ae') + line('M13 54v3m38-3v3M17 48h30'));
add('solar_panel', 'Pannello solare', p('M13 17h42l-9 25H4z', '#8fb7ce') + p('M17 21h32l-6 17H11z', '#3c75a6') + p('M27 21 21 38m17-17-6 17M14 29h32', 'none', 'stroke="#a9e4f1" stroke-width="2"') + p('M24 42v11h19v4H15v-4h5V42z', '#afbec0') + circle(52, 10, 5, '#ffe289') + p('M52 1v2m8 7h3m-5-6 2-2', 'none', 'stroke="#e6cf83" stroke-width="2"'));
add('lamp', 'Luce', p('m22 18 10-8 10 8v24H22z', '#e0b868') + rect(25, 22, 14, 16, '#fff6b4') + p('M18 43h28v9H18z', '#9aabb2') + p('M12 27H6m52 0h-6M16 13l-5-5m37 5 5-5M32 4V1', 'none', 'stroke="#e6cf83"'));
add('pump', 'Pompa acqua', p('M7 35h12v15H7zM45 18h12v15H45z', '#78bdcc') + rect(18, 20, 28, 30, '#91acb4') + circle(32, 35, 10, '#285463') + p('M32 27v15m-6-6 6 6 6-6', 'none', 'stroke="#8de4e0" stroke-width="3"') + line('M15 54h35M22 14h20'));
add('fan', 'Ventilatore gas', rect(10, 10, 44, 44, '#afc6b3') + circle(32, 32, 17, '#29464c') + p('M32 29q-15-25-17-7-1 11 14 10m6 0q27-7 13-17-9-6-16 15m-2 5q-10 26 7 19 10-5-3-21z', '#d1e5bd') + circle(32, 32, 5, '#b0d0d1'));
add('furnace', 'Fornace', rect(11, 14, 42, 40, '#98a7ae') + rect(40, 5, 10, 12, '#667a87') + rect(18, 26, 28, 22, '#533d49') + p('M23 45c-8-9 6-12 5-23 10 6 4 12 11 10 12 17-13 23-16 13z', '#eea45e') + p('M29 46q-4-5 4-12 8 12-4 12z', '#ffe3a0') + line('M17 20h15M10 56h44'));
add('gas_converter', 'Convertitore gas', rect(9, 18, 46, 36, '#759f92') + rect(14, 11, 12, 36, '#c7d68c') + rect(38, 11, 12, 36, '#c7d68c') + rect(24, 23, 17, 25, '#29464c') + p('m34 25-7 12h8l-4 9 10-14h-8z', '#ffe289') + line('M13 15h14m10 0h14M15 56h34'));
add('greenhouse', 'Serra', p('M8 26 32 8l24 18v29H8z', '#8bbcb5') + p('m13 28 19-15 19 15v21H13z', '#d5ece0') + line('M32 13v36M13 28h38') + p('M31 48V34q-15-11-16-1 1 10 16 6m1 1q18-17 17-4-1 7-17 9', '#79ac64') + rect(10, 49, 44, 7, '#ab9778'));
add('water_tank', 'Contenitore acqua', rect(13, 13, 38, 40, '#a8c8cd') + p('m13 13 8-6h23l7 6z', '#d9e9e7') + rect(19, 20, 26, 27, '#24484f') + rect(22, 31, 20, 13, '#55b8ff') + line('M22 28h20M26 35h12M26 40h12') + rect(7, 39, 6, 9, '#76b9d2') + rect(51, 39, 6, 9, '#76b9d2') + line('M15 56h34'));
add('ladder', 'Scala', p('M18 7v50m28-50v50M18 14h28M18 26h28M18 38h28M18 50h28', 'none', 'stroke="#dbbf78" stroke-width="6"') + p('M18 9v46m28-46v46', 'none', 'stroke="#f5dfa6" stroke-width="2"'));
for (const [id, name, color] of [['water_conduit', 'Tubo acqua', '#65bccf'], ['gas_conduit', 'Tubo gas', '#c4ce80']]) {
  add(id, name, p('M12 12h20v20h20v20H20V32h-8z', color) + line('M8 11h28M51 28v28M12 17h15v21h19') + (id === 'water_conduit' ? p('M43 38q-10 12 0 12t0-12z', '#bfeff0') : circle(41, 43, 4, '#eff1c4') + circle(28, 21, 3, '#eff1c4')));
}
add('energy_conduit', 'Cavo energia', p('M18 9v13q0 12 14 12t14 12v10', 'none', 'stroke="#293e47" stroke-width="12"') + p('M18 9v13q0 12 14 12t14 12v10', 'none', 'stroke="#e3bc76" stroke-width="6"') + rect(11, 7, 14, 8, '#c7dadc') + rect(39, 49, 14, 8, '#c7dadc') + line('M14 3v4m8-4v4m20 50v5m8-5v5'));

add('potato', 'Patata', p('M14 23q18-20 36-1 16 26-10 32-25 7-32-12-4-10 6-19z', '#ddbf7d') + p('M12 27q-3 29 28 27-26 8-32-12-2-10 4-15z', '#b79b62') + circle(22, 26, 2, '#a58b58') + circle(39, 24, 2, '#a58b58') + circle(33, 43, 2, '#a58b58') + line('m19 43 3 2'));
add('ochre_tuber', 'Tubero ocra', p('M12 42q-7-18 11-20 7-17 20-6 20 8 6 27-13 18-31 11z', '#dc986f') + p('M14 39q7 14 30 8-18 16-29 1z', '#b66d59') + line('m25 24-1 7m11-12 3 7m-7 14 5 4M37 14l6-8'));
add('verdant_leaf', 'Verdura viridia', p('M14 47Q6 17 48 10q13 33-27 42z', '#88b779') + p('M17 49 48 10Q22 25 17 49z', '#b8d799') + p('M11 57 38 26m-18 18 17-1m-10-8-4-11', 'none', 'stroke="#345d50" stroke-width="3"'));
add('frost_berry', 'Bacca brina', p('M28 17q-7-15 11-9 9-7 12 1-9 12-23 8z', '#90ba99') + circle(23, 31, 14, '#a69ed2') + circle(41, 37, 14, '#7d8fc3') + circle(25, 47, 10, '#b1abd9') + p('m18 23 4 3 5-4m10 10 4 3 5-3', 'none', 'stroke="#e5e8fb" stroke-width="3"'));
for (const [crop, color] of [['potato', '#ddbf7d'], ['ochre_tuber', '#dc986f'], ['verdant_leaf', '#88b779'], ['frost_berry', '#a69ed2']]) {
  add(`seed_${crop}`, `Semi: ${entries[crop].name}`, p('M17 12h30l5 43H12z', '#cedbbf') + rect(18, 22, 28, 26, '#365b57') + p('M31 43V31m0 5q-14-10-13-1 1 5 13 4m1-4q14-13 12-3-2 5-12 7', '#b3d693') + circle(39, 41, 5, color) + line('M19 17h26'));
}

add('module_hull', 'Scafo', p('m10 14 22-6 22 6v20q-2 15-22 24C12 49 10 34 10 34z', '#8fa9b2') + p('m32 8 22 6v20Q52 49 32 58z', '#60838f') + p('m20 25 12-5 12 5v12l-12 8-12-8z', '#d3e0df') + line('M32 20v25'));
add('module_engine', 'Propulsori', p('m20 14 26-6 7 27-27 8z', '#abc1c7') + p('m20 14 26-6-2 11-23 5z', '#d8e6e6') + p('m27 43-8 9 6-1 4 10 10-20z', '#eeac65') + p('m31 43-4 9 8-11z', '#ffe6a0') + rect(27, 24, 16, 7, '#63c7d3'));
add('module_cargo', 'Stiva', p('m10 19 22-10 22 10v31L32 59 10 50z', '#9badb4') + p('m10 19 22 10 22-10-22-10z', '#dce6de') + p('M32 29v30l22-9V19z', '#6c8b97') + line('m17 24 0 21 8 4V28m14-3v26M10 35l22 10 22-10'));
add('module_battery', 'Accumulatori', rect(14, 12, 36, 44, '#86aea5') + rect(25, 6, 14, 6, '#c8d8ce') + rect(20, 18, 24, 32, '#29464c') + bolt);
add('module_drill', 'Banco strumenti', housing + p('M20 29h20v8H28l-6 9h-7l6-15z', '#d5c69b') + line('M40 29h6m-6 8h6M13 56h38'));
add('module_landing_gear', 'Carrelli', p('M24 8h16v12H24z', '#d1dfe0') + p('m26 20-10 25 8 4 13-29z', '#99b2bb') + p('m38 20 10 25-8 4-9-29z', '#829ca8') + rect(7, 48, 23, 8, '#c9ba8d') + rect(36, 48, 21, 8, '#c9ba8d'));
add('module_habitat', 'Supporto vitale', rect(12, 14, 40, 40, '#b0bfa3') + rect(18, 8, 9, 7, '#dbe5c7') + p('M31 17v32m0-22q-11-10-13 5-3 15 12 10m3-15q11-10 13 5 3 15-12 10', '#8cc9bd') + line('M8 23h4m40 0h4'));
add('module_drone', 'Robbie', rect(15, 22, 34, 26, '#9dbfbd') + rect(20, 27, 24, 13, '#22454e') + circle(32, 33, 5, '#7ee3df') + line('M32 22v-9M23 13h18M6 20h15m22 0h15M10 17v6m44-6v6M23 52h18') + p('m16 40-7 7h7m32-7 7 7h-7', '#d9c78f'));
add('ship_fuel', 'Carburante nave', p('M18 15h28v39H12V24z', '#d1b076') + rect(24, 8, 17, 8, '#d6dfcd') + line('M19 27h20M20 35l16 13m0-13L20 48') + p('M46 20h7v16h-7z', '#afc2c2'));

add('pulse', 'Pulse', p('m9 20 36-6 11 9-2 13-25 1-10 20-12-6 10-20z', '#84b8b4') + p('m15 22 28-5 6 6-28 5z', '#cee7dc') + rect(39, 26, 17, 9, '#67ded4') + line('M31 24v12M12 45l9 4'));
add('scanner', 'Scanner', rect(15, 10, 35, 39, '#dec58b') + rect(21, 16, 23, 23, '#295259') + circle(32, 27, 9, '#326c70') + p('M32 18v9l7 5', 'none', 'stroke="#a7e1c1" stroke-width="2"') + circle(27, 31, 2, '#e6dc9b') + rect(24, 49, 17, 9, '#a9bcbf') + line('M24 43h9m5 0h3'));
add('bomb', 'Bomba', p('m12 23 20-11 20 11v27L32 59 12 50z', '#ad6865') + p('m12 23 20 10 20-10-20-11z', '#e4a67c') + p('M32 33v26l20-9V23z', '#884f58') + rect(22, 6, 19, 10, '#b5c2ba') + circle(32, 10, 3, '#ffdc8a') + p('m22 32-4 9h8l-4 8', 'none', 'stroke="#ffe1a0" stroke-width="3"'));
add('jetpack', 'Jetpack', rect(20, 15, 24, 32, '#98b6c5') + rect(9, 18, 13, 31, '#c3d3d8') + rect(42, 18, 13, 31, '#c3d3d8') + rect(25, 21, 14, 14, '#446a83') + p('m11 50 5 12 5-12m23 0 5 12 5-12', '#89e1df') + line('M24 10h16M13 14h6m26 0h6'));
add('resonator', 'Risonatore', p('m8 22 29-8 9 9v14l-16 1-11 19-10-7 8-18z', '#a696be') + p('M40 14h12v28H40z', '#d7c5e7') + p('M46 18v20m10-17q6 8 0 15', 'none', 'stroke="#cd9fe9" stroke-width="4"') + line('M21 27h13'));
add('plasma', 'Plasma', p('m8 21 32-7 12 9v13l-22 1-10 20-11-7 9-19z', '#b7adb0') + rect(36, 22, 13, 15, '#3c4c59') + p('m48 20 10 9-10 10z', '#ee956f') + p('M22 22h9v8h-9z', '#f6cb8c') + line('M14 45l8 4'));

const aliases = { ship_energy: 'module_battery', local_energy: 'gas_converter', stored_water: 'water', hull_integrity: 'module_hull', repaired_ship_workshop: 'laboratory' };
for (const id of ['laboratory', 'solar_panel', 'lamp', 'pump', 'fan', 'furnace', 'gas_converter', 'greenhouse', 'water_tank']) aliases[`repaired_${id}`] = id;
for (const level of [2, 3]) {
  aliases[`laboratory_level_${level}`] = 'laboratory';
  for (const id of ['hull', 'engine', 'cargo', 'battery', 'drill', 'landing_gear', 'habitat', 'drone']) aliases[`module_${id}_${level}`] = `module_${id}`;
}
add('valve', 'Valvola blu', p('m10 20 22-12 22 12v25L32 57 10 45z', '#329fe8') + p('m10 20 22 12 22-12L32 8z', '#8ad8ff') + p('M32 32v25l22-12V20z', '#1672bd') + circle(23, 34, 7, '#c6f1ff') + circle(23, 34, 3, '#24484f') + line('M16 34h14M23 27v14'));
const directory = 'assets/ui/items';
const outputs = {};
for (const [id, entry] of Object.entries(entries)) {
  outputs[`${directory}/${id}.svg`] = `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><title>${entry.name}</title><g stroke="#24404a" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${entry.body}</g></svg>\n`;
}
outputs[`${directory}/catalog.json`] = JSON.stringify({ version: 1, style: 'faceted-vector-inventory', icons: Object.fromEntries(Object.entries(entries).map(([id, entry]) => [id, { name: entry.name, path: `${directory}/${id}.svg` }])), aliases }, null, 2) + '\n';
const check = process.argv.includes('--check');
let failed = false;
for (const [path, content] of Object.entries(outputs)) {
  const absolute = resolve(root, path);
  if (check) {
    if (!existsSync(absolute) || readFileSync(absolute, 'utf8') !== content) { console.error(`Outdated icon asset: ${path}`); failed = true; }
  } else {
    mkdirSync(resolve(root, directory), { recursive: true });
    writeFileSync(absolute, content);
  }
}
console.log(`${Object.keys(entries).length} item icons, ${Object.keys(aliases).length} identity aliases: ${failed ? 'FAILED' : check ? 'up to date' : 'generated'}`);
process.exitCode = failed ? 1 : 0;
