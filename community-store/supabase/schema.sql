-- CAMPUS GIG — complete Supabase schema
-- Run this in a NEW Supabase project's SQL Editor. Do not run over the old CampusLink marketplace database.
extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  account_type text not null default 'student' check (account_type in ('student','employer')),
  role text not null default 'user' check (role in ('user','admin')),
  status text not null default 'active' check (status in ('active','suspended','banned')),
  company_name text,
  business_registration text,
  verification_status text not null default 'unverified' check(verification_status in ('unverified','pending','verified','rejected')),
  location text,
  phone text,
  course text,
  year_of_study text,
  bio text,
  skills text[] not null default '{}',
  preferences jsonb not null default '{}'::jsonb,
  public_profile boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name,account_type,company_name,business_registration)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',split_part(new.email,'@',1)),coalesce(new.raw_user_meta_data->>'account_type','student'),nullif(new.raw_user_meta_data->>'company_name',''),nullif(new.raw_user_meta_data->>'business_registration',''))
 on conflict(id) do nothing; return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
insert into public.profiles(id,full_name) select id,coalesce(raw_user_meta_data->>'full_name',split_part(email,'@',1)) from auth.users on conflict(id) do nothing;

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and status='active'); $$;
create or replace function public.protect_profile() returns trigger language plpgsql security definer set search_path=public as $$
begin if auth.uid() is not null and not public.is_admin() then if new.role is distinct from old.role or new.status is distinct from old.status or new.account_type is distinct from old.account_type then raise exception 'You cannot change protected account fields'; end if; end if; new.updated_at=now(); return new; end; $$;
drop trigger if exists protect_profile_fields on public.profiles;
create trigger protect_profile_fields before update on public.profiles for each row execute function public.protect_profile();

create table if not exists public.jobs (
 id uuid primary key default gen_random_uuid(),
 employer_id uuid not null references public.profiles(id) on delete cascade,
 title text not null,
 category text not null default 'Other',
 job_type text not null check(job_type in ('Part-time','Casual','Internship','Freelance','Once-off','Tutoring')),
 location text not null,
 work_mode text not null default 'On-site' check(work_mode in ('On-site','Hybrid','Remote')),
 pay_amount numeric(12,2) check(pay_amount is null or pay_amount>=0),
 pay_period text not null default 'hourly' check(pay_period in ('hourly','daily','weekly','monthly','fixed')),
 hours_per_week integer check(hours_per_week is null or hours_per_week between 1 and 80),
 description text not null,
 requirements text,
 closing_date date,
 status text not null default 'active' check(status in ('active','paused','closed','removed')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists jobs_active_created_idx on public.jobs(status,created_at desc);
create index if not exists jobs_employer_idx on public.jobs(employer_id,created_at desc);

create table if not exists public.applications (
 id uuid primary key default gen_random_uuid(),
 job_id uuid not null references public.jobs(id) on delete cascade,
 student_id uuid not null references public.profiles(id) on delete cascade,
 cover_letter text,
 status text not null default 'submitted' check(status in ('submitted','reviewing','shortlisted','accepted','rejected','withdrawn')),
 employer_note text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(job_id,student_id)
);
create index if not exists applications_student_idx on public.applications(student_id,created_at desc);
create index if not exists applications_job_idx on public.applications(job_id,created_at desc);

create table if not exists public.saved_jobs (
 student_id uuid not null references public.profiles(id) on delete cascade,
 job_id uuid not null references public.jobs(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(student_id,job_id)
);
create table if not exists public.notifications (
 id bigint generated always as identity primary key,
 user_id uuid not null references public.profiles(id) on delete cascade,
 type text not null default 'info',
 title text not null,
 message text,
 link text,
 is_read boolean not null default false,
 created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications(user_id,created_at desc);

create table if not exists public.community_posts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 content text not null check(length(trim(content)) between 1 and 1000),
 created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;
alter table public.saved_jobs enable row level security;
alter table public.notifications enable row level security;
alter table public.community_posts enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated using(id=auth.uid() or public_profile=true or public.is_admin());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated using(id=auth.uid() or public.is_admin()) with check(id=auth.uid() or public.is_admin());

drop policy if exists jobs_read on public.jobs;
create policy jobs_read on public.jobs for select to authenticated using(status in ('active','closed') or employer_id=auth.uid() or public.is_admin());
drop policy if exists jobs_insert on public.jobs;
create policy jobs_insert on public.jobs for insert to authenticated with check((employer_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.account_type='employer' and p.status='active')) or public.is_admin());
drop policy if exists jobs_update on public.jobs;
create policy jobs_update on public.jobs for update to authenticated using(employer_id=auth.uid() or public.is_admin()) with check(employer_id=auth.uid() or public.is_admin());
drop policy if exists jobs_delete on public.jobs;
create policy jobs_delete on public.jobs for delete to authenticated using(employer_id=auth.uid() or public.is_admin());

drop policy if exists applications_read on public.applications;
create policy applications_read on public.applications for select to authenticated using(student_id=auth.uid() or exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid()) or public.is_admin());
drop policy if exists applications_insert on public.applications;
create policy applications_insert on public.applications for insert to authenticated with check(student_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.account_type='student' and p.status='active') and exists(select 1 from public.jobs j where j.id=job_id and j.status='active'));
drop policy if exists applications_update on public.applications;
create policy applications_update on public.applications for update to authenticated using(student_id=auth.uid() or exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid()) or public.is_admin()) with check(student_id=auth.uid() or exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid()) or public.is_admin());

drop policy if exists saved_jobs_own on public.saved_jobs;
create policy saved_jobs_own on public.saved_jobs for all to authenticated using(student_id=auth.uid()) with check(student_id=auth.uid());
drop policy if exists notifications_own on public.notifications;
create policy notifications_own on public.notifications for select to authenticated using(user_id=auth.uid());
drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists community_read on public.community_posts;
create policy community_read on public.community_posts for select to authenticated using(true);
drop policy if exists community_insert on public.community_posts;
create policy community_insert on public.community_posts for insert to authenticated with check(user_id=auth.uid());
drop policy if exists community_delete on public.community_posts;
create policy community_delete on public.community_posts for delete to authenticated using(user_id=auth.uid() or public.is_admin());

create or replace function public.notify_application_created() returns trigger language plpgsql security definer set search_path=public as $$
declare v_employer uuid; v_title text;
begin
 select employer_id,title into v_employer,v_title from public.jobs where id=new.job_id;
 if coalesce((select (preferences->>'applicationAlerts')::boolean from public.profiles where id=v_employer),true) then
  insert into public.notifications(user_id,type,title,message,link) values(v_employer,'application','New job application','A student has applied for “'||v_title||'”.','/applicants');
 end if;
 return new;
end; $$;
drop trigger if exists application_created_notice on public.applications;
create trigger application_created_notice after insert on public.applications for each row execute function public.notify_application_created();

create or replace function public.protect_application_update() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.job_id is distinct from old.job_id or new.student_id is distinct from old.student_id then raise exception 'Application ownership cannot be changed'; end if;
 if auth.uid()=old.student_id then
  if new.status is distinct from old.status and new.status<>'withdrawn' then raise exception 'Students may only withdraw their own application'; end if;
  if new.employer_note is distinct from old.employer_note then raise exception 'Students cannot edit employer notes'; end if;
 end if;
 return new;
end; $$;
drop trigger if exists protect_application_fields on public.applications;
create trigger protect_application_fields before update on public.applications for each row execute function public.protect_application_update();

create or replace function public.notify_application_status() returns trigger language plpgsql security definer set search_path=public as $$
declare v_title text;
begin
 if new.status is distinct from old.status then
  select title into v_title from public.jobs where id=new.job_id;
  if coalesce((select (preferences->>'applicationAlerts')::boolean from public.profiles where id=new.student_id),true) then
   insert into public.notifications(user_id,type,title,message,link) values(new.student_id,'application','Application status updated','Your application for “'||v_title||'” is now '||new.status||'.','/applications');
  end if;
 end if;
 return new;
end; $$;
drop trigger if exists application_status_notice on public.applications;
create trigger application_status_notice after update of status on public.applications for each row execute function public.notify_application_status();

create or replace function public.notify_students_new_job() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.notifications(user_id,type,title,message,link)
 select p.id,'job','New opportunity: '||new.title,'A new '||new.job_type||' opportunity has been posted in '||new.location||'.','/jobs/'||new.id::text
 from public.profiles p
 where p.account_type='student' and p.status='active'
   and coalesce((p.preferences->>'jobAlerts')::boolean,true);
 return new;
end; $$;
drop trigger if exists job_created_notice on public.jobs;
create trigger job_created_notice after insert on public.jobs for each row execute function public.notify_students_new_job();

create or replace function public.admin_list_users() returns table(id uuid,email text,full_name text,account_type text,role text,status text,verification_status text,created_at timestamptz) language plpgsql stable security definer set search_path=public as $$
begin if not public.is_admin() then raise exception 'Admins only'; end if; return query select p.id,u.email::text,p.full_name,p.account_type,p.role,p.status,p.verification_status,p.created_at from public.profiles p join auth.users u on u.id=p.id order by p.created_at desc; end; $$;
grant execute on function public.admin_list_users() to authenticated;

-- Promote your own verified account to admin after registering (replace the email):
-- update public.profiles set role='admin' where id=(select id from auth.users where email='your@email.com');

-- Application updates are restricted: students can only withdraw; employers can
-- update review status but cannot change the applicant or linked job.
