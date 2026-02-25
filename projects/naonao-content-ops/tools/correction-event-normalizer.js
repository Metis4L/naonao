const fs=require('fs');
const path=require('path');

const issueClassMap=[
  [/human|模板|口号|表达/i,'human_likeness'],
  [/tone|语气|人设|态度/i,'tone_consistency'],
  [/logic|bridge|闭环|跳跃/i,'logic_closure'],
  [/mechanism|原理|risk_communication/i,'mechanism_explanation'],
  [/cta|timing|行动/i,'cta_coordination'],
];
const tagMap=[
  [/quote|引号/i,'quote_overuse'],
  [/template|模板/i,'template_voice'],
  [/emotion|情绪/i,'emotion_overdrive'],
  [/attitude/i,'attitude_flip'],
  [/persona/i,'persona_shift'],
  [/missing_bridge|bridge|过渡/i,'missing_bridge'],
  [/premature|过早/i,'premature_cta'],
  [/incomplete|不完整/i,'incomplete_reasoning'],
  [/jump|跳跃/i,'topic_jump'],
  [/no_mechanism|机制|cause/i,'no_mechanism_explained'],
  [/risk_without_cause/i,'risk_without_cause'],
  [/hard_command|必须|命令/i,'hard_command_after_warning'],
  [/readiness|准备/i,'cta_without_readiness'],
];
const rootMap=[
  [/template/i,'template_problem'],
  [/rule/i,'rule_problem'],
  [/requirement/i,'requirement_problem'],
  [/workflow/i,'workflow_problem'],
  [/skill/i,'skill_boundary_problem'],
  [/input|data/i,'input_data_problem'],
];
const actMap=[
  [/add/i,'add'],
  [/delete|remove/i,'delete'],
  [/rewrite|replace|tone|mitigation|condition/i,'rewrite'],
  [/reorder/i,'reorder'],
];

function pickByMap(v,m,def='other'){
  const s=(Array.isArray(v)?v.join(' '):String(v||''));
  for(const [re,val] of m){ if(re.test(s)) return val; }
  return def;
}
function normTags(v){
  const arr=Array.isArray(v)?v:[v].filter(Boolean);
  const out=[];
  for(const x of arr){
    const t=pickByMap(x,tagMap,null);
    if(t && !out.includes(t)) out.push(t);
  }
  if(!out.length) out.push('other');
  return out.slice(0,3);
}
function normActs(v){
  const arr=Array.isArray(v)?v:[v].filter(Boolean);
  const out=[];
  for(const x of arr){
    const a=pickByMap(x,actMap,null);
    if(a && !out.includes(a)) out.push(a);
  }
  if(!out.length) out.push('rewrite');
  return out;
}

const base=process.argv[2];
const outDir=process.argv[3];
if(!base||!outDir) throw new Error('usage: node correction-event-normalizer.js <inputDir> <outputDir>');
fs.mkdirSync(outDir,{recursive:true});

const files=['reg_case_001.json','reg_case_002.json','reg_case_003.json'];
const results=[];
for(const f of files){
  const p=path.join(base,f);
  const raw=JSON.parse(fs.readFileSync(p,'utf8'));
  const normalized={
    issue_class: pickByMap(raw.issue_class,issueClassMap,'other'),
    issue_tags: normTags(raw.issue_tags),
    root_cause_layer: pickByMap(raw.root_cause_layer,rootMap,'unknown'),
    editor_action_types: normActs(raw.editor_action_types)
  };
  const op=path.join(outDir,f.replace('.json','.normalized.json'));
  fs.writeFileSync(op,JSON.stringify(normalized,null,2)+'\n');
  results.push({file:f,output:path.basename(op),normalized});
}
console.log(JSON.stringify({status:'ok',results},null,2));
