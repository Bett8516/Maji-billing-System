# Maji Bill

A mobile-first water billing portal for Kenyan utilities, built with Next.js App Router, TypeScript, Tailwind CSS, Supabase and Leaflet/OpenStreetMap.

## Project structure

```text
src/
  app/                 Pages, server actions and API routes
    admin/             Tariffs, meters, readings, billing and faults
    api/                Protected OCR and reading submission routes
    auth/               Supabase phone/password auth actions
    dashboard/          Customer overview, bill history and faults
  components/            Customer forms, charts, Leaflet map and admin panels
  lib/                   Supabase clients, date and currency helpers
supabase/
  migrations/            Schema, constraints, triggers, storage and RLS
  seed.sql                Example meters, tariff tiers and readings
```

## 1. Create Supabase project

1. Create a project at [supabase.com](https://supabase.com) and select a region suitable for your Kenyan customers.
2. In **SQL Editor**, run `supabase/migrations/202611050001_initial_schema.sql`.
3. Run `supabase/seed.sql` to add three unassigned demo meters, a residential tariff with sample tiers, and demo readings for `MAJI-1001`.
4. In **Authentication → Providers → Phone**, enable phone/password sign-in. For the included registration flow, turn off phone confirmation while testing. Before production, configure an SMS provider and add an OTP confirmation step to registration.
5. Copy the project URL and anon/publishable key from **Project Settings → API**.

The seed meters are intentionally unassigned so that a customer account can claim one. Meter claiming is atomic and only works once. The demo readings are visible after the meter is assigned to an account.

## 2. Configure environment

Copy `.env.example` to `.env.local` and fill in:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
ANTHROPIC_API_KEY=your-anthropic-api-key
```

The Anthropic key is only read by `/api/read-meter`; it is never exposed to the browser. The app uses a current Claude vision model. Meter images are resized in the browser before OCR and upload.

## 3. Run locally

Install Node.js 20 or later, then from this folder:

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). Register with an E.164 phone number (for example `+2547…`) and one of the unassigned seed meter numbers. If SMS confirmation is enabled, finish phone confirmation before signing in; otherwise the account will be created and linked immediately.

To create an admin for development, register a separate account, then run this in the Supabase SQL editor using that account's auth UUID:

```sql
update public.profiles set role = 'admin' where id = 'AUTH_USER_UUID';
```

Sign in with that phone and password; admins are redirected to `/admin`. The admin page can add/assign meters, manage tariffs, review readings, create monthly bills, and update fault reports.

## 4. Deploy to Vercel

1. Push this folder to a Git repository and import it in Vercel.
2. Add the three `.env.example` variables to the Vercel project environment settings.
3. Deploy. Vercel detects Next.js automatically.
4. In Supabase **Authentication → URL Configuration**, add the deployed domain to allowed redirect URLs.
5. Confirm the `meter-photos` private Storage bucket exists (the migration creates it). Configure phone/SMS verification before production use.

## Billing and data notes

- All customer data is read and written through Supabase with row-level security. Only an administrator profile can enter `/admin` or mutate utility-wide records.
- Readings are checked against the previous accepted reading and recent average usage. Falling or unusually high readings are marked pending for admin review.
- Billing uses the latest accepted reading inside the selected month and the latest earlier accepted reading. Tier prices are charged incrementally; bills retain a tariff snapshot and the fixed charge/rate applied at generation time. A billing run is safe to repeat for the same meter/month.
- Currency formatting uses KES and displayed report dates use `en-KE`; stored reading dates are calculated in `Africa/Nairobi`.
- Map tiles are served by OpenStreetMap. Ensure the deployment follows the tile provider's usage policy.
- Payment status is currently maintained by an administrator through the database; the included scope does not integrate a payment provider.
