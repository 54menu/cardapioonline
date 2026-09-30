window.menuClock = function(now=new Date()) {
 const parts=Object.fromEntries(new Intl.DateTimeFormat('en-US',{timeZone:'America/Fortaleza',weekday:'short',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(now).map(p=>[p.type,p.value]));
 return {day:['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].indexOf(parts.weekday),minute:Number(parts.hour)*60+Number(parts.minute)};
};
window.scheduleActive = function(rows,now=new Date()) {
 const {day,minute}=window.menuClock(now);const minutes=t=>Number(String(t).slice(0,2))*60+Number(String(t).slice(3,5));
 return rows.some(s=>{if(!s.start_time||!s.end_time)return false;const start=minutes(s.start_time),end=minutes(s.end_time),wd=Number(s.weekday);
  return end<start?(wd===day&&minute>=start)||((wd+1)%7===day&&minute<=end):wd===day&&minute>=start&&minute<=end;});
};
window.storeOpenNow = function(schedule,status,now=new Date()) {
 if(status!=='open') return false;
 const keys=['dom','seg','ter','qua','qui','sex','sab'];
 if(!schedule||!keys.some(k=>schedule[k]))return true;
 const rows=keys.flatMap((k,weekday)=>{const d=schedule[k];if(!d||d.closed)return [];return [{weekday,start_time:d.open,end_time:d.close},...(schedule.hasLunchClosure?[{weekday,start_time:d.open2,end_time:d.close2}]:[])];});
 return window.scheduleActive(rows,now);
};
