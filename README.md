[README.md](https://github.com/user-attachments/files/34294727/README.md)
# Campus Gig — Work. Learn. Grow.

Campus Gig connects university and college students with flexible part-time work, casual gigs, internships, tutoring and local employers. This project is a reworked version of the supplied Community Store Vue application.

## Technology

- Vue 3 + Vite
- Supabase Auth (email/password + verification)
- Supabase PostgreSQL with Row Level Security
- Responsive CSS with persistent Light / Dark appearance setting

## Run locally

1. Install Node.js 20.19+ or 22.12+.
2. Install dependencies: `npm install`
3. Copy `.env.example` to `.env.local` and add your Supabase project URL and publishable key.
4. Start: `npm run dev`
5. Build: `npm run build`

## Supabase setup

Use a **new Supabase project** for Campus Gig. The original Community Store project has marketplace tables and payment workflows that are not the Campus Gig data model. Do not run the Campus Gig schema over the old marketplace database.

1. Create a Supabase project.
2. In Authentication → Providers → Email, enable email/password and email confirmation.
3. In Authentication → URL Configuration, add your local URL (for example `http://localhost:5173`) and production URL to the allowed redirect URLs.
4. Open SQL Editor and run the complete `supabase/schema.sql` file.
5. Copy `.env.example` to `.env.local` and add `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` from Project Settings → API.
6. Register your own account, verify your email, then promote it to admin by running the final SQL statement in `supabase/schema.sql` with your email address substituted.
7. Test with two accounts: one student account using an institution `.ac.za` email, and one employer account.

## Main features

### Student accounts
- Institution email validation during registration
- Student profile, course, year of study, location and skills
- Browse and search active jobs by keyword, location and job type
- View full job descriptions, requirements, pay and closing date
- Apply with an optional cover letter
- Save and remove jobs from a shortlist
- Track application status
- In-app notifications when an application status changes
- Community feed

### Employer accounts
- Employer profile and organisation name
- Optional business registration details and admin-controlled verified employer badge
- Create, pause, reactivate and delete job posts
- Specify job category, type, location, work mode, pay, hours, requirements and closing date
- View applicants and update their status
- In-app notifications when a student applies
- New job alerts for students who have enabled them
- Opening an applicant list automatically marks new applications as being reviewed and notifies the student

### Platform and account features
- Admin centre for members and job posts
- Suspend/reactivate members
- Admin-only access enforced by database functions and policies
- Light and Dark theme switch, saved on the device
- Settings for appearance, notification preferences, public profile visibility and password reset
- Responsive desktop and mobile layouts
- Supabase Row Level Security policies for data access

## Important implementation notes

- The project uses Supabase, not the PHP/MySQL backend from the earlier Campus Gig prototype. Do not mix the two without a deliberate migration.
- The schema includes the core job/application/notification workflows and RLS policies. Email delivery for custom notifications, CV file uploads, employer document verification, in-platform messaging, calendar integrations and production moderation workflows require additional provider/setup work and are not silently simulated.
- The `emailAlerts` preference is stored for future email integration; the included notifications are in-app notifications.
- The current student email rule checks the `.ac.za` domain. If your institution uses a different approved domain, adjust the validation in `src/views/RegisterView.vue`.
- For a production launch, add rate limiting/abuse controls, a support contact, privacy policy, terms of use, backup strategy, and review the RLS policies with your project owner.
