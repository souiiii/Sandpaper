"""Write explicit manual judgments. No heuristic or model-based grading."""
import json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[2]
TMP=pathlib.Path('/private/tmp/sandpaper-model-eval')

def write_review(name, judgments):
    rows=[json.loads(s) for s in (TMP/name/'results.jsonl').read_text().splitlines()]
    result=[]
    for index,row in enumerate(rows):
        key=(row['id'],row['strategy'],row['thinking'],row.get('dictionaryRequested',False))
        if key not in judgments:continue
        score,note=judgments[key]
        result.append({'row':index,'id':row['id'],'split':row['split'],'strategy':row['strategy'],'thinking':row['thinking'],'dictionaryRequested':row.get('dictionaryRequested',False),'correctness':score[0],'depth':score[1],'faithfulness':score[2],'clarity':score[3],'seriousError':bool(score[4]),'review':note})
    errata=ROOT/'docs/model-evaluation/errata.json'
    excluded={r['id'] for r in json.loads(errata.read_text())['excludedCases']} if errata.exists() else set()
    for row in result:
        if row['id'] in excluded:
            fields=['correctness','depth','faithfulness','clarity','seriousError','review']
            row['originalPreliminaryReview']={key:row[key] for key in fields}
            row.update(qualityExcluded=True,correctness=None,depth=None,faithfulness=None,clarity=None,seriousError=None,review='EXCLUDED: flawed intended ambiguity key; see errata.json. Original preliminary ratings are superseded.')
    cancellations=json.loads(errata.read_text()).get('administrativeCancellations',[]) if errata.exists() else []
    for row in result:
        if any(c['run']==name and c['row']==row['row'] for c in cancellations):
            row.update(excludeFromModelQuality=True,administrativeCancellation=True)
    (ROOT/'docs/model-evaluation/reviews'/f'{name}.json').write_text(json.dumps({'reviewer':'Implementing agent; manual, unblinded; no external judge','rubric':'tools/model_eval/PROTOCOL.md','reviews':result},indent=2)+'\n')
    print(name,len(result),'reviewed of',len(rows))

def keys_for(rows,strategy,thinking=False,dictionary=False):
    return [(id,strategy,thinking,dictionary) for id in rows]
