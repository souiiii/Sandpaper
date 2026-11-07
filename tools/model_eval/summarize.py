#!/usr/bin/env python3
"""Summarize timing/telemetry; linguistic scores are supplied by manual review."""
import argparse, collections, json, math, pathlib, re, statistics

def quantile(values,p):
    return sorted(values)[max(0,math.ceil(len(values)*p)-1)] if values else None

def readlines(p):return [json.loads(s) for s in p.read_text().splitlines()] if p.exists() else []
def summarize(directory):
    rows=readlines(directory/'results.jsonl');mem=readlines(directory/'memory.jsonl');probes=readlines(directory/'responsiveness.jsonl');groups=collections.defaultdict(list)
    for r in rows:groups[(r['split'],r['strategy'],r['thinking'],r.get('dictionaryRequested',False))].append(r)
    result={'name':directory.name,'groups':[]}
    # Post-hoc descriptive cache analysis; never substitutes for the frozen quality gate.
    stable=collections.defaultdict(list)
    previous=None
    for row in rows:
        main=row['strategy'] in ['baseline','adaptive'] and not row['thinking'] and not row.get('dictionaryRequested',False)
        if main and row['split']=='heldout' and previous is not None and previous['strategy']==row['strategy'] and not previous['thinking'] and not previous.get('dictionaryRequested',False) and row.get('valid'):
            stable[row['strategy']].append(row)
        previous=row
    result['samePromptPredecessor']=[{'strategy':strategy,'requests':len(items),'medianSeconds':statistics.median(r['seconds'] for r in items),'medianFirstReadableSeconds':statistics.median(r['firstReadableSeconds'] for r in items if r.get('firstReadableSeconds') is not None)} for strategy,items in stable.items()]
    for (split,strategy,thinking,dictionary),items in groups.items():
        t=[r['seconds'] for r in items if r.get('valid')];f=[r['firstReadableSeconds'] for r in items if r.get('valid') and r.get('firstReadableSeconds') is not None]
        result['groups'].append(dict(split=split,strategy=strategy,thinking=thinking,dictionary=dictionary,requests=len(items),valid=sum(bool(r.get('valid')) for r in items),medianSeconds=statistics.median(t) if t else None,p95Seconds=quantile(t,.95),maxSeconds=max(t) if t else None,medianFirstReadableSeconds=statistics.median(f) if f else None,medianReasoningCharacters=statistics.median(r.get('reasoningCharacters',0) for r in items)))
    if mem:
        baseline=json.loads((directory/'before.json').read_text());result['memory']={'peakRSSGiB':max(m['residentBytes'] for m in mem)/1024**3,'peakFootprintGiB':max(m['physicalFootprintBytes'] for m in mem)/1024**3,'lifetimePeakFootprintGiB':max(m['lifetimePeakFootprintBytes'] for m in mem)/1024**3,'startSwapGiB':baseline['swapUsedBytes']/1024**3,'endSwapGiB':json.loads((directory/'after.json').read_text())['swapUsedBytes']/1024**3 if (directory/'after.json').exists() else None,'peakSwapGrowthGiB':(max(m['swapUsedBytes'] for m in mem)-baseline['swapUsedBytes'])/1024**3,'peakCompressorGiB':max(m['compressorBytes'] for m in mem)/1024**3,'swapInGiB':(max(m['swapInBytes'] for m in mem)-baseline['swapInBytes'])/1024**3,'swapOutGiB':(max(m['swapOutBytes'] for m in mem)-baseline['swapOutBytes'])/1024**3,'pressureSampleCounts':dict(collections.Counter(m['pressureLevel'] for m in mem))}
    # Keep individual allocations, not an invented additive RSS + Metal number.
    if (directory/'server.log').exists():
        logs=(directory/'server.log').read_text(errors='replace')
        result['serverMemoryLines']=[l.split(' I ',1)[-1] for l in logs.splitlines() if any(x in l for x in ['buffer size =','projected to use','model size  ','general.architecture','model params'])]
        # Equal-sized per-layer mapped buffers are distinct; do not deduplicate them.
        result['metalReportedBuffersMiB']=sum(float(value) for value in re.findall(r'MTL0(?:_Mapped)?\s+[^\n]*buffer size\s*=\s*([0-9.]+) MiB',logs))
    if probes:
        values=[p['processAndDictionarySeconds'] for p in probes if 'processAndDictionarySeconds' in p];result['responsiveness']={'samples':len(probes),'errors':sum('error' in p for p in probes),'medianProcessAndDictionarySeconds':statistics.median(values) if values else None,'p95ProcessAndDictionarySeconds':quantile(values,.95),'maxProcessAndDictionarySeconds':max(values) if values else None}
    if (directory/'startup.json').exists():result['startup']=json.loads((directory/'startup.json').read_text())
    return result
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('directories',nargs='+');p.add_argument('--output');args=p.parse_args();result=[summarize(pathlib.Path(d)) for d in args.directories];text=json.dumps(result,indent=2)
    if args.output:pathlib.Path(args.output).write_text(text+'\n')
    else:print(text)
