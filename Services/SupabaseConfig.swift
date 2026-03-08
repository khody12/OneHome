import Supabase
import Foundation

// MARK: - Fill in your Supabase project URL and anon key
// These come from your Supabase dashboard (or local self-hosted instance)
enum SupabaseConfig {
    static let url = URL(string: "http://localhost:54321")!  // local Supabase default
    static let anonKey = "YOUR_SUPABASE_ANON_KEY"
}

// Shared Supabase client — use this everywhere
let supabase = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
