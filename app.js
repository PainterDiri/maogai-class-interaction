import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cfg = window.APP_CONFIG;
if (!cfg?.supabaseUrl || cfg.supabaseUrl.includes('YOUR_')) throw new Error('请先配置 config.js');
export const supabase = createClient(cfg.supabaseUrl, cfg.supabaseAnonKey);
export const sessionId = new URLSearchParams(location.search).get('session') || cfg.defaultSessionId || 'main';
export const labels = { A:'军事保护', B:'土地与群众', C:'基层组织' };
export function participantId(){let id=localStorage.getItem(`participant:${sessionId}`);if(!id){id=crypto.randomUUID?.()||Math.random().toString(36).slice(2);localStorage.setItem(`participant:${sessionId}`,id)}return id}
export async function fetchState(){const {data,error}=await supabase.from('session_state').select('*').eq('id',sessionId).single();if(error)throw error;return data}
export async function fetchVotes(){const {data,error}=await supabase.from('votes').select('participant_id,round,choice').eq('session_id',sessionId);if(error)throw error;return data||[]}
export function counts(votes,round){return ['A','B','C'].reduce((a,k)=>(a[k]=votes.filter(v=>v.round===round&&v.choice===k).length,a),{})}
export function paired(votes){const a=new Map(),b=new Map();votes.forEach(v=>(v.round===1?a:b).set(v.participant_id,v.choice));let both=0,retained=0,toA=0,toB=0,toC=0;for(const [id,x] of a){if(!b.has(id))continue;both++;const y=b.get(id);if(x===y)retained++;else if(y==='A')toA++;else if(y==='B')toB++;else toC++}return{both,retained,toA,toB,toC}}
export function subscribe(onChange){const channel=supabase.channel(`session-${sessionId}`).on('postgres_changes',{event:'*',schema:'public',table:'session_state',filter:`id=eq.${sessionId}`},onChange).on('postgres_changes',{event:'*',schema:'public',table:'votes',filter:`session_id=eq.${sessionId}`},onChange).subscribe();return()=>supabase.removeChannel(channel)}
