-- 피드백 게시판 (web/feedback/). Supabase 대시보드 → SQL Editor에 통째로 붙여 넣고 Run.
-- 다시 실행해도 된다 (함수는 바꾸고, 테이블·글은 그대로 둔다).
--
-- 로그인 없이 쓰고, 글마다 비밀번호를 받아 그 비밀번호로만 수정·삭제한다.
-- 공개 키(anon/publishable)로는 테이블에 직접 접근할 수 없고, 아래 함수만 부를 수 있다.
-- 비밀번호는 bcrypt 해시로만 저장하고, 목록 함수는 해시를 돌려주지 않는다.
-- 관리자는 대시보드 Table Editor에서 아무 글이나 지울 수 있다.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.feedback (
  id bigint generated always as identity primary key,
  nickname text not null check (char_length(nickname) between 1 and 20),
  title text not null check (char_length(title) between 1 and 100),
  body text not null check (char_length(body) between 1 and 3000),
  password_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

-- 정책이 없으므로 공개 키로는 테이블을 읽거나 쓸 수 없다 (아래 security definer 함수로만).
alter table public.feedback enable row level security;
revoke all on public.feedback from anon, authenticated;

-- 목록: 최신 글부터. total은 전체 글 수.
create or replace function public.list_feedback(p_limit int default 20, p_offset int default 0)
returns table (id bigint, nickname text, title text, body text, created_at timestamptz, updated_at timestamptz, total bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select f.id, f.nickname, f.title, f.body, f.created_at, f.updated_at, count(*) over ()
  from public.feedback f
  order by f.id desc
  limit least(greatest(p_limit, 1), 50)
  offset greatest(p_offset, 0);
$$;

create or replace function public.create_feedback(p_nickname text, p_title text, p_body text, p_password text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_id bigint;
begin
  if char_length(coalesce(p_password, '')) not between 4 and 72 then
    raise exception '비밀번호는 4~72자로 입력하세요.';
  end if;
  insert into public.feedback (nickname, title, body, password_hash)
  values (btrim(p_nickname), btrim(p_title), btrim(p_body), extensions.crypt(p_password, extensions.gen_salt('bf')))
  returning feedback.id into new_id;
  return new_id;
end;
$$;

-- 비밀번호가 맞으면 true. 틀리거나 글이 없으면 false.
create or replace function public.update_feedback(p_id bigint, p_password text, p_title text, p_body text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.feedback f
  set title = btrim(p_title), body = btrim(p_body), updated_at = now()
  where f.id = p_id and f.password_hash = extensions.crypt(p_password, f.password_hash);
  return found;
end;
$$;

create or replace function public.delete_feedback(p_id bigint, p_password text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.feedback f
  where f.id = p_id and f.password_hash = extensions.crypt(p_password, f.password_hash);
  return found;
end;
$$;

revoke all on function public.list_feedback(int, int) from public;
revoke all on function public.create_feedback(text, text, text, text) from public;
revoke all on function public.update_feedback(bigint, text, text, text) from public;
revoke all on function public.delete_feedback(bigint, text) from public;
grant execute on function public.list_feedback(int, int) to anon, authenticated;
grant execute on function public.create_feedback(text, text, text, text) to anon, authenticated;
grant execute on function public.update_feedback(bigint, text, text, text) to anon, authenticated;
grant execute on function public.delete_feedback(bigint, text) to anon, authenticated;
