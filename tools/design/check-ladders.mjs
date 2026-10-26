import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source=fs.readFileSync('tools/design/validate.mjs','utf8').replace("import fs from 'node:fs';",'');
const fixtures=[
  ['valid instant ladder',null,null],
  ['ladder recipe delay','recipes',data=>data.find(x=>x.id==='recipe_cube_ladder').seconds=5],
  ['ladder workshop dependency','recipes',data=>data.find(x=>x.id==='recipe_cube_ladder').station='mod_workshop'],
  ['ladder energy cost','recipes',data=>data.find(x=>x.id==='recipe_cube_ladder').energy_kwh=0.01],
  ['ladder as cube','modules',data=>data.find(x=>x.id==='mod_ladder').kind='unfolding_cube'],
  ['ladder deployment delay','modules',data=>data.find(x=>x.id==='mod_ladder').deployment_seconds=5],
  ['ladder requires Robbie','rules',data=>data.manual_ladders.requires_robbie=true],
  ['other recipe instant','recipes',data=>data.find(x=>x.id==='recipe_cube_lab').seconds=0],
  ['other recipe without station','recipes',data=>data.find(x=>x.id==='recipe_cube_lab').station=null],
  ['invalid station type','recipes',data=>data.find(x=>x.id==='recipe_cube_ladder').station=false],
];

for(const [name,catalog,mutate] of fixtures){
  let report;
  const processState={exitCode:0};
  // Keep mutations and validator reports in memory; never rewrite design fixtures.
  const files={
    existsSync:fs.existsSync,
    readFileSync(file,encoding){
      const text=fs.readFileSync(file,encoding);
      if(file!==`design/v1/${catalog}.json`)return text;
      const data=JSON.parse(text);
      mutate(data);
      return JSON.stringify(data);
    },
    mkdirSync(){},
    writeFileSync(file,text){
      assert.equal(file,'docs/design/validation-report.json');
      report=JSON.parse(text);
    },
  };
  vm.runInNewContext(source,{fs:files,process:processState,console:{log(){}}},{timeout:10000});
  assert.ok(report,`${name}: missing validation report`);
  assert.equal(report.ok,mutate===null,`${name}: incorrect validation result`);
  assert.equal(processState.exitCode,mutate===null?0:1,`${name}: incorrect exit code`);
  console.log(`PASS: ${name}`);
}
console.log(`MANUAL LADDER DESIGN: ${fixtures.length} checks passed`);
