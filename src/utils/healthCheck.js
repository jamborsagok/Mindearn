import { supabase } from '../lib/supabase.js';

export async function checkSupabaseConnection() {
  try {
    const { error } = await supabase.auth.getSession();
    if (error) throw error;
    console.log('[MindEarn] Supabase connection OK');
  } catch (err) {
    console.error('[MindEarn] Supabase connection FAILED:', err.message);
  }
}
