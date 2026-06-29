import { supabase } from '../lib/supabase.js';

// TODO Phase 4: Load all daily_entries rows for a given date (ISO string)
export async function getDailyEntries(entryDate) {}

// TODO Phase 4: Upsert a single daily_entries row (morning / midday / evening)
export async function saveDailyEntry(entryDate, period, fields) {}

// TODO Phase 4: Load the authenticated user's commitments, newest first
export async function getCommitments() {}

// TODO Phase 4: Upsert a commitments row for the given period_start and period_weeks
export async function saveCommitment(periodStart, periodWeeks, fields) {}
