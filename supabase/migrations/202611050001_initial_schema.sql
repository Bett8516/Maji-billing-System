create extension if not exists pgcrypto;
create type public.user_role as enum ('customer','admin');
create type public.reading_source as enum ('photo','manual');
create type public.reading_status as enum ('pending','accepted','rejected');
create type public.meter_status as enum ('active','inactive','faulty');
create type public.bill_status as enum ('paid','unpaid');
create type public.fault_status as enum ('open','assigned','resolved');
create type public.fault_kind as enum ('no_display','leaking','damaged','tampered','other');

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null,
 phone text not null unique,
 role public.user_role not null default 'customer',
 created_at timestamptz not null default now()
);
create table public.meters (
 id uuid primary key default gen_random_uuid(), meter_number text not null unique,
 customer_id uuid references public.profiles(id) on delete set null,
 location text, status public.meter_status not null default 'active',
 installed_at date not null default current_date, created_at timestamptz not null default now()
);
create table public.readings (
 id uuid primary key default gen_random_uuid(), meter_id uuid not null references public.meters(id) on delete cascade,
 reading_value numeric(12,2) not null check (reading_value >= 0), reading_date date not null default (now() at time zone 'Africa/Nairobi')::date,
 photo_url text, source public.reading_source not null default 'manual', ocr_confidence numeric(5,4),
 status public.reading_status not null default 'pending', reviewed_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
create index readings_meter_date_idx on public.readings(meter_id,reading_date desc);
create table public.tariffs (
 id uuid primary key default gen_random_uuid(), name text not null,
 rate_per_unit numeric(12,2) not null check(rate_per_unit >= 0), fixed_charge numeric(12,2) not null default 0 check(fixed_charge >= 0),
 effective_from date not null, is_active boolean not null default true, created_at timestamptz not null default now()
);
create table public.tariff_tiers (
 id uuid primary key default gen_random_uuid(), tariff_id uuid not null references public.tariffs(id) on delete cascade,
 from_units numeric(12,2) not null check(from_units >= 0), to_units numeric(12,2), rate numeric(12,2) not null check(rate >= 0),
 check(to_units is null or to_units > from_units)
);
create table public.bills (
 id uuid primary key default gen_random_uuid(), meter_id uuid not null references public.meters(id) on delete cascade,
 month date not null, units_consumed numeric(12,2) not null, rate_applied numeric(12,2) not null,
 amount numeric(12,2) not null, status public.bill_status not null default 'unpaid',
 fixed_charge_applied numeric(12,2) not null default 0, tariff_snapshot jsonb not null default '{}'::jsonb,
 generated_at timestamptz not null default now(), unique(meter_id,month)
);
create table public.fault_reports (
 id uuid primary key default gen_random_uuid(), meter_id uuid not null references public.meters(id) on delete cascade,
 reported_by uuid not null references public.profiles(id) on delete cascade, fault_type public.fault_kind not null,
 description text not null, photo_url text, latitude double precision, longitude double precision,
 status public.fault_status not null default 'open', admin_notes text, created_at timestamptz not null default now()
);

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin') $$;
create or replace function public.owns_meter(mid uuid) returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.meters where id=mid and customer_id=auth.uid()) $$;
create or replace function public.meter_available(meter_number_input text) returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.meters where meter_number=meter_number_input and customer_id is null and status='active') $$;
create or replace function public.claim_meter(meter_number_input text) returns boolean language plpgsql security definer set search_path=public
as $$ begin if auth.uid() is null then raise exception 'Authentication required'; end if; update public.meters set customer_id=auth.uid() where meter_number=meter_number_input and customer_id is null and status='active'; if not found then raise exception 'Meter unavailable'; end if; return true; end $$;
create or replace function public.submit_reading(meter_id_input uuid, reading_value_input numeric, source_input public.reading_source, photo_url_input text default null, ocr_confidence_input numeric default null) returns table(id uuid,status public.reading_status) language plpgsql security definer set search_path=public
as $$ declare previous_value numeric; avg_usage numeric; reading_status public.reading_status := 'accepted'; current_date_kenya date := (now() at time zone 'Africa/Nairobi')::date; begin
 if auth.uid() is null or not public.owns_meter(meter_id_input) then raise exception 'Meter access denied'; end if;
 if reading_value_input < 0 or (ocr_confidence_input is not null and (ocr_confidence_input<0 or ocr_confidence_input>1)) then raise exception 'Invalid reading values'; end if;
 if photo_url_input is not null and split_part(photo_url_input,'/',1)<>auth.uid()::text then raise exception 'Photo path does not belong to this account'; end if;
 select r.reading_value into previous_value from public.readings r where r.meter_id=meter_id_input and r.status='accepted' order by r.reading_date desc,r.created_at desc limit 1;
 with recent as (select reading_value,lag(reading_value) over(order by reading_date,created_at) as prior from (select reading_value,reading_date,created_at from public.readings where meter_id=meter_id_input and status='accepted' order by reading_date desc,created_at desc limit 13) x)
 select avg(reading_value-prior) into avg_usage from recent where prior is not null and reading_value>=prior;
 if previous_value is not null and (reading_value_input<previous_value or (avg_usage is not null and reading_value_input-previous_value>3*avg_usage)) then reading_status:='pending'; end if;
 return query insert into public.readings(meter_id,reading_value,reading_date,source,photo_url,ocr_confidence,status) values(meter_id_input,reading_value_input,current_date_kenya,source_input,photo_url_input,ocr_confidence_input,reading_status) returning readings.id,readings.status;
end $$;
revoke all on function public.submit_reading(uuid,numeric,public.reading_source,text,numeric) from public;
grant execute on function public.submit_reading(uuid,numeric,public.reading_source,text,numeric) to authenticated;
revoke all on function public.claim_meter(text) from public;
grant execute on function public.claim_meter(text) to authenticated;
grant execute on function public.meter_available(text) to anon,authenticated;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public
as $$ begin insert into public.profiles(id,full_name,phone) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),coalesce(new.raw_user_meta_data->>'phone','')); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.meters enable row level security;
alter table public.readings enable row level security;
alter table public.tariffs enable row level security;
alter table public.tariff_tiers enable row level security;
alter table public.bills enable row level security;
alter table public.fault_reports enable row level security;
create policy "profiles own or admin read" on public.profiles for select using(id=auth.uid() or public.is_admin());
create policy "profiles own update" on public.profiles for update using(id=auth.uid() or public.is_admin()) with check(id=auth.uid() or public.is_admin());
revoke update on public.profiles from authenticated;
grant update(full_name,phone) on public.profiles to authenticated;
create policy "admin manage profiles" on public.profiles for all using(public.is_admin()) with check(public.is_admin());
create policy "meters customer or admin read" on public.meters for select using(customer_id=auth.uid() or public.is_admin());
create policy "admin manage meters" on public.meters for all using(public.is_admin()) with check(public.is_admin());
create policy "own readings read" on public.readings for select using(public.owns_meter(meter_id) or public.is_admin());
create policy "own readings submit" on public.readings for insert with check(public.owns_meter(meter_id) and status='pending');
create policy "admin manage readings" on public.readings for all using(public.is_admin()) with check(public.is_admin());
create policy "tariffs readable" on public.tariffs for select to authenticated using(true);
create policy "admin manage tariffs" on public.tariffs for all using(public.is_admin()) with check(public.is_admin());
create policy "tiers readable" on public.tariff_tiers for select to authenticated using(true);
create policy "admin manage tiers" on public.tariff_tiers for all using(public.is_admin()) with check(public.is_admin());
create policy "own bills read" on public.bills for select using(public.owns_meter(meter_id) or public.is_admin());
create policy "admin manage bills" on public.bills for all using(public.is_admin()) with check(public.is_admin());
create policy "own faults read" on public.fault_reports for select using(reported_by=auth.uid() or public.is_admin());
create policy "own faults insert" on public.fault_reports for insert with check(reported_by=auth.uid() and public.owns_meter(meter_id));
create policy "admin manage faults" on public.fault_reports for all using(public.is_admin()) with check(public.is_admin());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('meter-photos','meter-photos',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
create policy "authenticated upload meter photos" on storage.objects for insert to authenticated with check(bucket_id='meter-photos' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "admin or owner read meter photos" on storage.objects for select to authenticated using(bucket_id='meter-photos' and (public.is_admin() or (storage.foldername(name))[1]=auth.uid()::text));

