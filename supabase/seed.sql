-- Run after creating two customer auth users and one admin in Supabase Auth.
-- Set profile roles/customer links by replacing the example UUIDs below.
insert into public.meters(meter_number,location,status,installed_at) values
 ('MAJI-1001','Kilimani, Nairobi','active','2024-01-15'),
 ('MAJI-1002','Westlands, Nairobi','active','2024-02-01'),
 ('MAJI-1003','Langata, Nairobi','active','2024-03-12') on conflict(meter_number) do nothing;
insert into public.tariffs(name,rate_per_unit,fixed_charge,effective_from,is_active)
select 'Residential Standard',85,150,'2026-01-01',true
where not exists(select 1 from public.tariffs where name='Residential Standard' and effective_from='2026-01-01');
insert into public.tariff_tiers(tariff_id,from_units,to_units,rate)
select t.id,x.f,x.t,x.r from public.tariffs t cross join (values(0::numeric,10::numeric,65::numeric),(10::numeric,30::numeric,85::numeric),(30::numeric,null::numeric,110::numeric)) x(f,t,r)
where t.name='Residential Standard' and t.effective_from='2026-01-01'
and not exists(select 1 from public.tariff_tiers tt where tt.tariff_id=t.id);
-- Demo readings become visible to the relevant customer after a meter is linked to their profile.
insert into public.readings(meter_id,reading_value,reading_date,source,status)
select m.id,v.reading_value,v.reading_date,'manual','accepted'
from public.meters m cross join (values (100::numeric,'2026-08-01'::date),(112::numeric,'2026-09-01'::date),(126::numeric,'2026-10-01'::date)) v(reading_value,reading_date)
where m.meter_number='MAJI-1001'
and not exists(select 1 from public.readings r where r.meter_id=m.id and r.reading_date=v.reading_date);
