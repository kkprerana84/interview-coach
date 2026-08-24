const SUPABASE_URL  = 'https://jillixkvzzxfgctvryrw.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImppbGxpeGt2enp4ZmdjdHZyeXJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExMjk5MjQsImV4cCI6MjA5NjcwNTkyNH0.UsoE9qCzkKe4yYC8pLYbwN-FzvT7uv_sTD3wJC45g_8';

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
  console.log('[DEBUG] fetchQuestions entered', {categories, level, limit, company});
  try {
    // Build query params as a plain string — Supabase REST needs unencoded filter operators
    // Use individual eq params for each category — avoids in.() space/encoding issues
    const catParams = categories.map(c => `category=eq.${encodeURIComponent(c)}`).join('&');
    const levelParam = `level=in.(${encodeURIComponent(level)},Any)`;

    async function queryQuestions(companyFilter, rowLimit) {
      // Fetch each category separately and merge — sidesteps in.() multi-value encoding
      const allResults = [];
      const perCat = Math.ceil(rowLimit / categories.length);
      for (const cat of categories) {
        if (allResults.length >= rowLimit) break;
        const encodedCat = encodeURIComponent(cat);
        const encodedLevel = encodeURIComponent(level);
        const url = `${SUPABASE_URL}/rest/v1/questions?select=id,question,category,context,framework,company&active=eq.true&category=eq.${encodedCat}&level=in.(${encodedLevel},Any)&${companyFilter}&limit=${perCat}`;
        console.log('[DEBUG] loop url:', url);
        const res = await fetch(url, {
          headers: {
            'apikey': SUPABASE_ANON,
            'Authorization': `Bearer ${SUPABASE_ANON}`,
            'Accept': 'application/json',
          },
        });
        if (!res.ok) throw new Error(`${res.status}: ${await res.text()}`);
        const rows = await res.json();
        allResults.push(...rows);
      }
      return allResults.slice(0, rowLimit);
    }

    let results = [];

    // 1 — Company-specific questions (skip if "Other" or empty)
    if (company && company !== 'Other') {
      try {
        results = await queryQuestions(`company=eq.${company}`, limit);
        console.log('[DEBUG] company results:', results);
      } catch(err) {
        console.log('[DEBUG] company fetch error:', err.message);
      }
    }

    // 2 — Fill remaining slots with generic questions (null company)
    const remaining = limit - results.length;
    if (remaining > 0) {
      try {
        const generic = await queryQuestions('company=is.null', remaining);
        console.log('[DEBUG] generic results:', generic);
        results = [...results, ...generic];
      } catch(err) {
        console.log('[DEBUG] generic fetch error:', err.message);
      }
    }

    return results;
  } catch (e) {
    console.warn('[DEBUG] Supabase question fetch outer catch:', e.message, e);
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
