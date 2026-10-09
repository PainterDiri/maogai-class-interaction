-- 常驻互动网站后端：在 Supabase Dashboard -> SQL Editor 中完整执行。
-- 执行前只需要把 CHANGE_ME_LONG_RANDOM_HOST_TOKEN 替换成你自己生成的随机长字符串。
-- 不要把这个 host token 写入公开仓库；主持人链接中再带上它。

create extension if not exists pgcrypto;

drop function if exists public.submit_vote(text, text, integer, text);
drop function if exists public.host_control(text, text, text);

drop table if exists public.votes cascade;
drop table if exists public.session_hosts cascade;
drop table if exists public.session_state cascade;

create table public.session_state (
  id text primary key,
  phase text not null default 'waiting' check (phase in ('waiting','round1','revealed','round2','closed')),
  scenario jsonb not null,
  updated_at timestamptz not null default now()
);

create table public.session_hosts (
  session_id text primary key references public.session_state(id) on delete cascade,
  host_token text not null
);

create table public.votes (
  session_id text not null references public.session_state(id) on delete cascade,
  participant_id text not null,
  round integer not null check (round in (1,2)),
  choice text not null check (choice in ('A','B','C')),
  created_at timestamptz not null default now(),
  primary key (session_id, participant_id, round)
);

insert into public.session_state (id, scenario) values (
  'main',
  jsonb_build_object(
    'title', '一个农村革命根据地出现了粮食募集困难、新兵补充缓慢。有限的新增工作力量，你会优先安排到哪项工作？',
    'options', jsonb_build_object(
      'A', jsonb_build_object('label','军事保护','detail','加强武装与保卫工作'),
      'B', jsonb_build_object('label','土地与群众','detail','回应土地要求，开展群众工作'),
      'C', jsonb_build_object('label','基层组织','detail','健全基层政权和办事组织')
    ),
    'survey', jsonb_build_array(
      '现有武装暂时能够保卫根据地，交通尚可。',
      '农民的土地要求迟迟没有回应，持续支持意愿较弱。',
      '基层已经有组织，但推进土地工作仍需具体落实。'
    )
  )
);

insert into public.session_hosts (session_id, host_token)
values ('main', 'CHANGE_ME_LONG_RANDOM_HOST_TOKEN');

alter table public.session_state enable row level security;
alter table public.session_hosts enable row level security;
alter table public.votes enable row level security;

-- 参与者和主持人都可以读取不含主持人令牌的状态，以及匿名投票记录。
create policy "public can read session state" on public.session_state
  for select to anon, authenticated using (true);
create policy "public can read anonymous votes" on public.votes
  for select to anon, authenticated using (true);
-- session_hosts 没有公开读取策略。

-- 允许 Realtime 根据这些表的变化推送更新。
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='session_state') then
    alter publication supabase_realtime add table public.session_state;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='votes') then
    alter publication supabase_realtime add table public.votes;
  end if;
end $$;

create or replace function public.submit_vote(
  p_session_id text,
  p_participant_id text,
  p_round integer,
  p_choice text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_phase text;
begin
  if length(coalesce(p_participant_id,'')) < 8 then
    return jsonb_build_object('ok',false,'error','invalid participant id');
  end if;
  if p_round not in (1,2) or p_choice not in ('A','B','C') then
    return jsonb_build_object('ok',false,'error','invalid vote');
  end if;
  select phase into current_phase from public.session_state where id = p_session_id;
  if current_phase is null then
    return jsonb_build_object('ok',false,'error','session not found');
  end if;
  if (p_round = 1 and current_phase <> 'round1') or (p_round = 2 and current_phase <> 'round2') then
    return jsonb_build_object('ok',false,'error','round is not open');
  end if;
  insert into public.votes(session_id, participant_id, round, choice)
  values (p_session_id, p_participant_id, p_round, p_choice)
  on conflict (session_id, participant_id, round) do nothing;
  if not found then
    return jsonb_build_object('ok',false,'error','already voted');
  end if;
  return jsonb_build_object('ok',true);
end;
$$;

grant execute on function public.submit_vote(text,text,integer,text) to anon, authenticated;

create or replace function public.host_control(
  p_session_id text,
  p_host_token text,
  p_action text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_phase text;
begin
  if not exists (select 1 from public.session_hosts where session_id = p_session_id and host_token = p_host_token) then
    return jsonb_build_object('ok',false,'error','invalid host token');
  end if;
  select phase into current_phase from public.session_state where id = p_session_id;
  if p_action = 'reset' then
    delete from public.votes where session_id = p_session_id;
    update public.session_state set phase='waiting', updated_at=now() where id=p_session_id;
  elsif p_action = 'start' and current_phase = 'waiting' then
    update public.session_state set phase='round1', updated_at=now() where id=p_session_id;
  elsif p_action = 'reveal' and current_phase = 'round1' then
    update public.session_state set phase='revealed', updated_at=now() where id=p_session_id;
  elsif p_action = 'round2' and current_phase in ('revealed','round1') then
    update public.session_state set phase='round2', updated_at=now() where id=p_session_id;
  elsif p_action = 'close' and current_phase <> 'waiting' then
    update public.session_state set phase='closed', updated_at=now() where id=p_session_id;
  else
    return jsonb_build_object('ok',false,'error','invalid action for current phase');
  end if;
  return jsonb_build_object('ok',true);
end;
$$;

grant execute on function public.host_control(text,text,text) to anon, authenticated;
