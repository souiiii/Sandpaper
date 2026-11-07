#!/usr/bin/env python3
"""Export small reviewable evidence; exclude weights, thought text and dictionary articles."""
import argparse, gzip, hashlib, json, pathlib, sys
from summarize import summarize
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/model-evaluation'
p=argparse.ArgumentParser();p.add_argument('names',nargs='+');args=p.parse_args()
all_summaries=[]
for name in args.names:
    directory=pathlib.Path('/private/tmp/sandpaper-model-eval')/name
    rows=[]
    for line in (directory/'results.jsonl').read_text().splitlines():
        row=json.loads(line)
        for e in row.get('dictionaryEvidence',[]):
            text=e.pop('text');e['textSHA256']=hashlib.sha256(text.encode()).hexdigest();e['utf16Length']=len(text.encode('utf-16-le'))//2
        rows.append(row)
    (OUT/f'{name}.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n')
    summary=summarize(directory)
    telemetry={}
    for filename in ['memory.jsonl','responsiveness.jsonl']:
        if (directory/filename).exists():telemetry[filename]=[json.loads(s) for s in (directory/filename).read_text().splitlines()]
    for filename in ['before.json','after.json','command.json','exit.json']:
        if (directory/filename).exists():telemetry[filename]=json.loads((directory/filename).read_text())
    if (directory/'background-apps.txt').exists():telemetry['background-apps']=(directory/'background-apps.txt').read_text().splitlines()
    with gzip.open(OUT/f'{name}-telemetry.json.gz','wt') as archive:json.dump(telemetry,archive)
    summary['execution']=telemetry.get('exit.json')
    summary['recordedRequestCount']=len(rows)
    protocol=json.loads((directory/'protocol.json').read_text())
    summary['protocol']={k:v for k,v in protocol.items() if k!='prompts'}
    if (directory/'props.json').exists():
        props=json.loads((directory/'props.json').read_text());template=props.get('chat_template','')
        summary['template']={'sha256':hashlib.sha256(template.encode()).hexdigest(),'capabilities':props.get('chat_template_caps'),'bos':props.get('bos_token'),'eos':props.get('eos_token')}
    review=OUT/'reviews'/f'{name}.json'
    if review.exists():
        all_scores=json.loads(review.read_text())['reviews']
        summary['reviewedCount']=len(all_scores)
        summary['qualityExcludedCount']=sum(bool(r.get('qualityExcluded')) for r in all_scores)
        summary['administrativeQualityExclusions']=sum(bool(r.get('excludeFromModelQuality')) for r in all_scores)
        scores=[r for r in all_scores if not r.get('qualityExcluded') and not r.get('excludeFromModelQuality')];groups={}
        for r in scores:groups.setdefault((r['split'],r['strategy'],r['thinking'],r['dictionaryRequested']),[]).append(r)
        summary['quality']=[]
        for (split,strategy,thinking,dictionary),items in groups.items():
            summary['quality'].append({'split':split,'strategy':strategy,'thinking':thinking,'dictionary':dictionary,'reviewed':len(items),'contextuallySound':sum(r['correctness']==2 for r in items),'seriousErrors':sum(r['seriousError'] for r in items),'meanCorrectness':sum(r['correctness'] for r in items)/len(items),'meanDepth':sum(r['depth'] for r in items)/len(items),'grounded':sum(r['faithfulness']==2 for r in items),'clear':sum(r['clarity']==2 for r in items)})
    all_summaries.append(summary)
(OUT/'summary.json').write_text(json.dumps(all_summaries,indent=2)+'\n')
print('Exported',len(all_summaries),'runs,',sum(len(json.loads((OUT/f'{n}.json').read_text())) for n in args.names),'answers/attempts')
