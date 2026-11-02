import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://campus-gig-not-configured.supabase.co'
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || 'campus-gig-not-configured'
export const supabase = createClient(supabaseUrl, supabaseKey)
