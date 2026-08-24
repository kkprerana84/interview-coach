const SUPABASE_URL  = 'https://jillixkvzzxfgctvryrw.supabase.co';
const SUPABASE_ANON = 'sb_publishable_Qwdosc14AL5K-viSPPwQwg_57lF-yOu';

async function sbFetch(path, opts = {}) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...opts,
    headers: {
      'apikey':        SUPABASE_ANON,
      'Authorization': `Bearer ${SUPABASE_ANON}`,
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      ...(opts.headers || {}),
    },
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Supabase ${res.status}: ${err}`);
  }
  return res.json();
}

// Build Supabase query string without encoding filter operators
function buildQuery(table, filters, extra = '') {
  const parts = Object.entries(filters).map(([k, v]) => `${k}=${v}`);
  return `${table}?${parts.join('&')}${extra ? '&' + extra : ''}`;
}

window.fetchCategories = async function() {
  return sbFetch('categories?select=id,name,description&active=eq.true&order=sort_order.asc');
};

/**
 * Fetches curated questions for the given categories, level, and optionally company.
 * Prioritises company-specific questions, then fills remaining slots with generic ones.
 * Returns [] if Supabase is unreachable.
 */
window.fetchQuestions = async function(categories, level, limit, company) {
  limit = limit || 3;
  try {
    const catFilter = categories.map(c => `"${c}"`).join(',');
    const base = {
      select:   'id,question,category,context,framework,company',
      active:   'eq.true',
      level:    `in.(${level},Any)`,
      category: `in.(${catFilter})`,
    };

    let results = [];

    // 1 — Company-specific questions (skip if "Other" or empty)
    if (company && company !== 'Other') {
      const path = buildQuery('questions', { ...base, company: `eq.${company}` }, `limit=${limit}`);
      console.log('[DEBUG] Supabase company query:', `${SUPABASE_URL}/rest/v1/${path}`);
      results = await sbFetch(path);
      console.log('[DEBUG] company results:', results);
    }

    // 2 — Fill remaining slots with generic questions (null company)
    const remaining = limit - results.length;
    if (remaining > 0) {
      const path = buildQuery('questions', { ...base, company: 'is.null' }, `limit=${remaining}`);
      const generic = await sbFetch(path);
      results = [...results, ...generic];
    }

    return results;
  } catch (e) {
    console.warn('Supabase question fetch failed, will use AI-generated:', e.message);
    return [];
  }
};

/**
 * Assembles the coaching system prompt from knowledge_base rows.
 * Returns null if Supabase is unreachable.
 */
window.fetchSystemPrompt = async function() {
  try {
    const rows = await sbFetch('knowledge_bases?select=content&active=eq.true&order=sort_order.asc');
    return rows.map(r => r.content).join('\n\n');
  } catch (e) {
    console.warn('Supabase knowledge base fetch failed, using bundled prompt:', e.message);
    return null;
  }
};

/**
 * Saves a completed session. Fire-and-forget.
 */
window.saveSession = async function(session) {
  try {
    await sbFetch('sessions', {
      method: 'POST',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({
        company:      session.company,
        role:         session.role,
        level:        session.level,
        function:     session.fn,
        categories:   session.categories,
        question_ids: session.questions.map(q => q.id).filter(Boolean),
        answers:      session.answered,
        completed:    true,
      }),
    });
  } catch (e) {
    console.warn('Session save failed:', e.message);
  }
};
