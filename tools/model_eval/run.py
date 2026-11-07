#!/usr/bin/env python3
"""Bounded, single-worker experiment. Standard library only; no implicit downloads."""
import argparse, hashlib, json, os, pathlib, re, signal, socket, subprocess, threading, time, urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[2]
TMP=pathlib.Path('/private/tmp/sandpaper-model-eval')
WORKER=pathlib.Path('/private/tmp/sandpaper-ai-validation/llama-b12110/llama-server')
SAMPLE=pathlib.Path('/private/tmp/sandpaper-ai-validation/memory-sample')
DICTIONARY=TMP/'dictionary'
DIFFICULT=['i3','l2','l3','l4','t4','a1','a3','a4','f4','r-heldout-cat','r-ambiguity','r-new-duck']
QUANT=['v1','v3','p1','i1','i3','l2','l3','l4','t1','t4','a1','a3','a4','f3','n1','r-heldout-cat']
DICT=['d4','v1','v3','t1','r-heldout-wanting','r-heldout-cat']
# Extract the exact production instructions rather than maintaining a facsimile.
swift=(ROOT/'Sources/SandpaperCore/LocalInference/LlamaPrompts.swift').read_text()
BASE='\n'.join(line[12:] for line in swift.split('content: """',1)[1].split('"""',1)[0].strip('\n').splitlines())
OLD='Give a natural explanation in one short paragraph: usually one or two sentences,\nat most three when ambiguity or subtle tone needs it. Simple actions need only a paraphrase.'
NEW='''Adapt depth to the selection, in one coherent paragraph. For a simple word or action,
give one concise contextual meaning. For idioms or nuanced usage, explain the meaning
and the distinction that matters here. For difficult literary wording, give a richer
explanation of tone, implications, uncertainty and why the particular words matter,
using specific evidence from this passage. Use up to six sentences only when useful;
do not pad easy cases or repeat the paraphrase.'''
assert OLD in BASE
ADAPTIVE=BASE.replace(OLD,NEW)
CONTRAST=ADAPTIVE.replace('Read the ENTIRE passage before interpreting the selection.', 'Read the ENTIRE passage before interpreting the selection. Before answering, compare plausible literal, figurative, lexical or grammatical readings against specific textual evidence. Discard contradicted readings; preserve multiple readings only when the text leaves them open. Give the resulting explanation, not a list of your reasoning steps.')
PROMPTS={'baseline':BASE,'adaptive':ADAPTIVE,'contrast':CONTRAST}
SCHEMA={'type':'object','properties':{'meaning':{'type':'string','minLength':1,'maxLength':2048},'notes':{'type':'array','maxItems':0,'items':{'type':'object','properties':{'kind':{'type':'string','enum':['definition','usage','implication','tone','grammar','example','relatedExpression']},'text':{'type':'string','minLength':1,'maxLength':4096}},'required':['kind','text'],'additionalProperties':False}}},'required':['meaning','notes'],'additionalProperties':False}
OPENER=urllib.request.build_opener(urllib.request.ProxyHandler({}))
def http(port,path,body=None,timeout=90):
    data=None if body is None else json.dumps(body,ensure_ascii=False).encode()
    req=urllib.request.Request(f'http://127.0.0.1:{port}'+path,data=data,headers={'Content-Type':'application/json'})
    return OPENER.open(req,timeout=timeout)
def get(port,path,body=None):
    with http(port,path,body) as response:return json.load(response)
def sample(pid):return json.loads(subprocess.check_output([str(SAMPLE),str(pid)],text=True))
def evidence(query):
    row=json.loads(subprocess.check_output([str(DICTIONARY),query],text=True))
    txt=row['text']; origin=txt.find(' ORIGIN ')
    if origin>=0:txt=txt[:origin]
    return [] if not txt else [{'entryID':'macos:'+hashlib.sha256(txt.encode()).hexdigest(),'provider':'macOS active dictionaries; bounded reader-style excerpt, not a selected sense','query':row.get('headword',query),'text':txt}]
def messages(case,strategy,gemma3,ev):
    system=PROMPTS[strategy]
    user=json.dumps({'passage':case['passage'],'selectedText':case['selection'],'dictionaryEvidence':ev},ensure_ascii=False,separators=(',',':'))
    if gemma3:
        return [{'role':'user','content':system.replace('The next message is JSON','The reading material below is JSON')+'\n\n<reading_material>\n'+user+'\n</reading_material>'}]
    return [{'role':'system','content':system},{'role':'user','content':user}]
def complete(port,case,strategy,thinking,gemma3,ev):
    msg=messages(case,strategy,gemma3,ev)
    kwargs={'enable_thinking':thinking}
    rendered=get(port,'/apply-template',{'messages':msg,'chat_template_kwargs':kwargs})
    tokens=get(port,'/tokenize',{'content':rendered['prompt'],'add_special':True,'parse_special':True})['tokens']
    limit=1024 if thinking else 512
    if len(tokens)+limit+256>4096:raise ValueError('Context would overflow')
    body={'model':'sandpaper-local','messages':msg,'stream':True,'stream_options':{'include_usage':True},'temperature':0.2,'seed':42,'max_tokens':limit,'top_k':40,'top_p':0.95,'min_p':0.05,'cache_prompt':True,'chat_template_kwargs':kwargs,'reasoning_budget_tokens':512 if thinking else 0,'response_format':{'type':'json_schema','json_schema':{'name':'explanation','strict':True,'schema':SCHEMA}}}
    start=time.monotonic();content='';thought='';first=None;finish=None;usage=None;timings=None
    with http(port,'/v1/chat/completions',body) as stream:
        for line in stream:
            if time.monotonic()-start>90:raise TimeoutError('Request exceeded 90s')
            if not line.startswith(b'data: '):continue
            payload=line[6:].strip()
            if payload==b'[DONE]':break
            event=json.loads(payload)
            if event.get('error'):raise RuntimeError(event['error'])
            if event.get('usage'):usage=event['usage']
            if event.get('timings'):timings=event['timings']
            for choice in event.get('choices',[]):
                delta=choice.get('delta',{});content+=delta.get('content') or '';thought+=delta.get('reasoning_content') or ''
                if choice.get('finish_reason'):finish=choice['finish_reason']
            match=re.search(r'"meaning"\s*:\s*"((?:[^"\\]|\\.)*)',content,re.S)
            if first is None and match:
                try:visible=json.loads('"'+match[1]+'"')
                except ValueError:visible=''
                if len(visible)>=12:first=time.monotonic()-start
    seconds=time.monotonic()-start
    try:
        parsed=json.loads(content);valid=isinstance(parsed.get('meaning'),str) and bool(parsed['meaning'].strip()) and len(parsed['meaning'].encode('utf-16-le'))//2<=2048 and parsed.get('notes')==[] and set(parsed)=={'meaning','notes'} and finish=='stop'
    except ValueError:parsed=None;valid=False
    return dict(id=case['id'],split=case['split'],strategy=strategy,thinking=thinking,dictionary=bool(ev),dictionaryEvidence=ev,
                seconds=seconds,firstReadableSeconds=first,finish=finish,valid=valid,answer=parsed,raw=content,
                reasoningCharacters=len(thought),reasoningSHA256=hashlib.sha256(thought.encode()).hexdigest(),usage=usage,timings=timings,
                inputTokens=len(tokens),renderedPromptSHA256=hashlib.sha256(rendered['prompt'].encode()).hexdigest())

def main():
    p=argparse.ArgumentParser();p.add_argument('--model',required=True);p.add_argument('--name',required=True);p.add_argument('--gemma3',action='store_true');p.add_argument('--thinking',action='store_true');p.add_argument('--thinking-only',action='store_true');p.add_argument('--extras-only',action='store_true');p.add_argument('--quant-subset',action='store_true');p.add_argument('--smoke',action='store_true');p.add_argument('--no-dictionary',action='store_true');args=p.parse_args()
    directory=TMP/args.name;directory.mkdir(exist_ok=False)
    def interrupted(signum, frame):
        raise KeyboardInterrupt(f'Experiment interrupted by signal {signum}')
    signal.signal(signal.SIGTERM,interrupted)
    suite_path=ROOT/'docs/model-evaluation/suite.json';suite=json.loads(suite_path.read_text());byid={c['id']:c for c in suite}
    (directory/'protocol.json').write_text(json.dumps({'suiteSHA256':hashlib.sha256(suite_path.read_bytes()).hexdigest(),'prompts':PROMPTS,'promptSHA256':{k:hashlib.sha256(v.encode()).hexdigest() for k,v in PROMPTS.items()},'args':vars(args),'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())},indent=2))
    # Only record app identities and RSS, no window contents.
    apps=subprocess.check_output(['/bin/ps','-axo','pid,rss,comm'],text=True).splitlines()
    if any('llama-server' in a for a in apps):raise RuntimeError('Another llama-server is running; refusing simultaneous weights')
    (directory/'background-apps.txt').write_text('\n'.join(a for a in apps if any(s in a for s in ['Zen.app','Visual Studio Code.app','Codex.app']))+'\n')
    with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
    cmd=[str(WORKER),'--model',args.model,'--alias','sandpaper-local','--host','127.0.0.1','--port',str(port),'--ctx-size','4096','--parallel','1','--n-gpu-layers','99','--batch-size','512','--ubatch-size','128','--cache-type-k','q8_0','--cache-type-v','q8_0','--flash-attn','on','--cache-ram','0','--no-context-shift','--no-webui','--jinja','--reasoning-format','deepseek','-lv','4']
    (directory/'command.json').write_text(json.dumps(cmd,indent=2));before=sample(0);(directory/'before.json').write_text(json.dumps(before,indent=2))
    log=(directory/'server.log').open('w');server=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    stop=threading.Event();failure=[];start=time.monotonic();critical=None
    def monitor():
        nonlocal critical
        with (directory/'memory.jsonl').open('w') as out:
            while not stop.is_set():
                row=sample(server.pid);row.update(seconds=time.monotonic()-start);out.write(json.dumps(row)+'\n');out.flush()
                critical=critical or time.monotonic() if row['pressureLevel']==4 else None
                if critical and time.monotonic()-critical>10:failure.append('Critical pressure >10s')
                if row['swapUsedBytes']-before['swapUsedBytes']>3*1024**3:failure.append('Swap growth >3 GiB')
                if time.monotonic()-start>900:failure.append('Model session >15 minutes')
                if os.statvfs(TMP).f_bavail*os.statvfs(TMP).f_frsize<8*1024**3:failure.append('Disk headroom <8 GiB')
                if failure:server.terminate();return
                stop.wait(.5)
    def responsiveness():
        with (directory/'responsiveness.jsonl').open('w') as out:
            while not stop.is_set():
                t=time.monotonic()
                try:
                    data=json.loads(subprocess.check_output([str(DICTIONARY),'restive'],text=True,timeout=5));data={'dictionarySeconds':data['seconds'],'processAndDictionarySeconds':time.monotonic()-t,'seconds':t-start}
                except Exception as e:data={'error':str(e),'seconds':t-start}
                out.write(json.dumps(data)+'\n');out.flush();stop.wait(2)
    monitor_thread=threading.Thread(target=monitor,daemon=True);monitor_thread.start();response_thread=None
    try:
        while True:
            if server.poll() is not None:raise RuntimeError(f'Server exited {server.returncode}: {failure}')
            try:
                if get(port,'/health').get('status')=='ok':break
            except (OSError,ValueError):pass
            if time.monotonic()-start>120:raise TimeoutError('Startup >120s')
            time.sleep(.5)
        startup=time.monotonic()-start;(directory/'startup.json').write_text(json.dumps({'seconds':startup,'port':port},indent=2));print(args.name,'ready',round(startup,2),flush=True)
        props=get(port,'/props');(directory/'props.json').write_text(json.dumps(props,indent=2))
        # Render all three development templates; inspect special-token framing and enabled/disabled thinking.
        templates={}
        for thinking in ([False,True] if args.thinking else [False]):
            templates[str(thinking)]=get(port,'/apply-template',{'messages':messages(byid['d1'],'adaptive',args.gemma3,[]),'chat_template_kwargs':{'enable_thinking':thinking}})
        (directory/'templates.json').write_text(json.dumps(templates,indent=2))
        time.sleep(2)
        response_thread=threading.Thread(target=responsiveness,daemon=True);response_thread.start()
        todo=[]
        for c in suite:
            if c['split']=='development':
                if args.smoke:todo.append((c['id'],'adaptive',False,False))
                continue
            if args.smoke:continue
            if args.quant_subset:
                if c['id'] in QUANT:todo.append((c['id'],'adaptive',False,False))
            else:
                strategies=['baseline','adaptive'] if len(todo)%4==0 else ['adaptive','baseline']
                for strategy in strategies:todo.append((c['id'],strategy,False,False))
        main_count=len(todo)
        if not args.quant_subset and not args.smoke:
            for id in DIFFICULT:
                todo.append((id,'contrast',False,False))
                if args.thinking:todo.append((id,'adaptive',True,False))
            if not args.no_dictionary:
                for id in DICT:
                    if byid[id]['split']=='development':todo.append((id,'adaptive',False,False))
                    todo.append((id,'adaptive',False,True))
        if args.extras_only:
            todo=todo[main_count:]
        if args.thinking_only:
            todo=[(id,'adaptive',True,False) for id in DIFFICULT]
        with (directory/'results.jsonl').open('w') as out:
            for i,(id,strategy,thinking,with_dict) in enumerate(todo):
                if failure:raise RuntimeError(failure)
                c=byid[id];ev=evidence(c['selection']) if with_dict else []
                try:row=complete(port,c,strategy,thinking,args.gemma3,ev)
                except Exception as e:row={'id':id,'split':c['split'],'strategy':strategy,'thinking':thinking,'dictionary':with_dict,'valid':False,'error':str(e)}
                row['dictionaryRequested']=with_dict;out.write(json.dumps(row,ensure_ascii=False)+'\n');out.flush()
                print(f'{i+1}/{len(todo)} {id} {strategy} thinking={thinking} valid={row["valid"]} {row.get("seconds",0):.2f}s',flush=True)
        (directory/'exit.json').write_text(json.dumps({'success':True,'seconds':time.monotonic()-start,'failures':failure},indent=2))
    except BaseException as error:
        (directory/'exit.json').write_text(json.dumps({'success':False,'error':str(error),'seconds':time.monotonic()-start,'failures':failure},indent=2))
        raise
    finally:
        stop.set();monitor_thread.join(timeout=3)
        if response_thread:response_thread.join(timeout=6)
        if server.poll() is None:
            server.terminate()
            try:server.wait(timeout=10)
            except subprocess.TimeoutExpired:server.kill();server.wait()
        log.close();(directory/'after.json').write_text(json.dumps(sample(0),indent=2))
if __name__=='__main__':main()
