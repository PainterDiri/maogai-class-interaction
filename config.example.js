// 复制为 config.js，然后填入 Supabase 项目的 URL 和 anon/publishable key。
// 不要填 service_role key；它不能出现在浏览器端。
window.APP_CONFIG = {
  supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
  supabaseAnonKey: 'YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY',
  defaultSessionId: 'main',
  siteTitle: '先判断，再调查，再判断',
};
