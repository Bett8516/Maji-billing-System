# Maji Bill

A mobile-first water billing portal for Kenyan utilities, built with Next.js App Router, TypeScript, Tailwind CSS, Supabase and Leaflet/OpenStreetMap.

## Project structure

```text
src/
  app/                 Pages, server actions and API routes
    admin/             Tariffs, meters, readings, billing and faults
    api/                Protected OCR and reading submission routes
    auth/               Supabase email/password auth actions
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
4. The app uses Supabase's built-in **Email** provider; Phone can remain disabled, so no SMS provider or SMS charges are needed. For first-time testing, turn off **Confirm email** in **Authentication → Sign In / Providers → Email** so accounts are created immediately. Email confirmation is supported through `/auth/callback`; Supabase's built-in email sender is restricted and rate-limited, so configure custom SMTP before production email delivery.
5. Copy the project URL and anon/publishable key from **Project Settings → API**.

The seed meters are intentionally unassigned so that a customer account can claim one. Meter claiming is atomic and only works once. The demo readings are visible after the meter is assigned to an account.

## 2. Configure environment

Copy `.env.example` to `.env.local` and fill in:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
GEMINI_API_KEY=your-google-ai-studio-api-key
```

The Google Gemini API key is only read by `/api/read-meter`; it is never exposed to the browser. Meter OCR uses Gemini 3.8 Flash, which supports images and has a free tier with usage limits. Google states that free-tier content may be used to improve its products. Meter images are resized in the browser before OCR and upload. See Google's current [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing) and [data use terms](https://ai.google.dev/gemini-api/terms).

## 3. Run locally

Install Node.js 20 or later, then from this folder:

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). Register with your email address, phone number (stored on your profile), and one of the unassigned seed meter numbers. With Confirm email off, the account and meter link are created immediately. If email confirmation is on, confirm the email to finish meter linking.

To create an admin for development, register a separate account, then run this in the Supabase SQL editor using that account's auth UUID:

```sql
update public.profiles set role = 'admin' where id = 'AUTH_USER_UUID';
```

Sign in with that email and password; admins are redirected to `/admin`. The admin page can add/assign meters, manage tariffs, review readings, create monthly bills, and update fault reports.

## 4. Deploy to Vercel

1. Push this folder to a Git repository and import it in Vercel.
2. Add the three `.env.example` variables to the Vercel project environment settings.
3. Deploy. Vercel detects Next.js automatically.
4. In Supabase **Authentication → URL Configuration**, add the deployed domain to allowed redirect URLs.
5. In Supabase **Authentication → URL Configuration**, allow the Vercel domain's `/auth/callback` URL. Confirm the `meter-photos` private Storage bucket exists (the migration creates it). Configure custom SMTP and enable email confirmations before production use.

## Billing and data notes

- All customer data is read and written through Supabase with row-level security. Only an administrator profile can enter `/admin` or mutate utility-wide records.
- Readings are checked against the previous accepted reading and recent average usage. Falling or unusually high readings are marked pending for admin review.
- Billing uses the latest accepted reading inside the selected month and the latest earlier accepted reading. Tier prices are charged incrementally; bills retain a tariff snapshot and the fixed charge/rate applied at generation time. A billing run is safe to repeat for the same meter/month.
- Currency formatting uses KES and displayed report dates use `en-KE`; stored reading dates are calculated in `Africa/Nairobi`.
- Map tiles are served by OpenStreetMap. Ensure the deployment follows the tile provider's usage policy.
- Payment status is currently maintained by an administrator through the database; the included scope does not integrate a payment provider.
