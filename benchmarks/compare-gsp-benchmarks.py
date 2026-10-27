import json,pathlib
p=pathlib.Path(__file__).resolve().parent
def seconds(name,label):
 rows=json.loads((p/f'{name}-{label}-results.json').read_text())
 out=[]
 for row in rows:
  events=row['history']['status']['messages']
  start=next(v['timestamp'] for k,v in events if k=='execution_start')
  end=next(v['timestamp'] for k,v in events if k=='execution_success')
  out.append((end-start)/1000)
 return out
report={}
for name in ['moss','zimage']:
 stock=seconds(name,'baseline'); current=seconds(name,'unlocked')
 a=sum(stock[1:])/2; b=sum(current[1:])/2
 report[name]={'stock_seconds':stock,'gsp_unlock_seconds':current,'stock_warm_mean':a,'gsp_unlock_warm_mean':b,'speedup_percent':(a/b-1)*100,'time_saved_percent':(1-b/a)*100}
(p/'gsp-benchmark-comparison.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
