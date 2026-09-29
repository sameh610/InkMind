(async()=>{
  const selection=JSON.stringify({strokes:[{id:'stroke-1',label:'line',bounds:[0,0,120,8]}],objects:[{kind:'text',text:'y = 3x^2 - 1'}]});
  const cases=[
    ['explain','Explain this'],['quiz','Create a quiz'],['debug','Check this work'],
    ['createVisual','make y = 3x^2 - 1 a graph'],['animateInk','animate this ink'],
  ];
  const results=[];
  for(const [action,text] of cases){
    const response=await fetch('http://127.0.0.1:8787/generate',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({action,text,selection,model:'spark-x2.5-1.7b',quant:'Auto'})});
    const body=await response.json();results.push({action,status:response.status,nonempty:!!body.text?.trim(),fallback:body.fallback,preview:String(body.text||'').slice(0,100)});
  }
  console.log(JSON.stringify(results,null,2));
  if(results.some(x=>x.status!==200||!x.nonempty))process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
