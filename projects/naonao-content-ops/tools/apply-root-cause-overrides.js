const fs=require('fs');
const reportPath=process.argv[2];
const ovPath=process.argv[3];
const outPath=process.argv[4];
if(!reportPath||!ovPath||!outPath) throw new Error('usage: node apply-root-cause-overrides.js <report> <overrides> <out>');
const rep=JSON.parse(fs.readFileSync(reportPath,'utf8'));
const ov=JSON.parse(fs.readFileSync(ovPath,'utf8'));
if(!ov.enabled) { fs.writeFileSync(outPath,JSON.stringify(rep,null,2)+'\n'); process.exit(0); }
for(const c of rep.cases||[]){
  const id=c.case_id;
  if(ov.overrides[id]){
    c.predicted.root_cause_layer_overridden=ov.overrides[id];
    c.checks.root_cause_match=(ov.overrides[id]===c.expected.root);
  }
}
let c=0,t=0,r=0,u=0,n=(rep.cases||[]).length||1;
for(const x of rep.cases||[]){
  if(x.checks.issue_class_match) c++;
  if(x.checks.core_tag_hit) t++;
  if(x.checks.root_cause_match) r++;
  u += (x.checks.candidate_rule_usefulness||1);
}
const sv={class:c/n,tag:t/n,root:r/n,use:u/n};
const total=30*sv.class+35*sv.tag+20*sv.root+15*sv.use;
rep.run_id=(rep.run_id||'run')+'_override';
rep.scoring={
  issue_class_match:{weight:30,value:sv.class,score:30*sv.class},
  core_tag_hit:{weight:35,value:sv.tag,score:35*sv.tag},
  root_cause_match:{weight:20,value:sv.root,score:20*sv.root},
  candidate_rule_usefulness:{weight:15,value:sv.use,score:15*sv.use},
  total:Math.round(total*100)/100
};
rep.metrics={
  issue_class_match:`${c}/${n}`,
  core_tag_hit:`${t}/${n}`,
  root_cause_match:`${r}/${n}`,
  candidate_rule_usefulness_avg:sv.use
};
rep.override_meta={applied:true,source:ovPath,scope:ov.scope};
fs.writeFileSync(outPath,JSON.stringify(rep,null,2)+'\n');
console.log('written',outPath);
