-- ============================================================
-- Interview Coach — Supabase Schema
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- 1. CATEGORIES
create table if not exists categories (
  id          serial primary key,
  name        text not null unique,
  description text,
  sort_order  int  default 0
);

insert into categories (name, description, sort_order) values
  ('Leadership & org design',    'Building, scaling, and restructuring teams',          1),
  ('Strategy & stakeholders',    'Business case, prioritisation, executive influence',  2),
  ('Behavioral / STAR',          'Past-experience stories with quantified outcomes',    3),
  ('Data & analytics strategy',  'Analytics operating model, tooling, ROI',            4),
  ('Product & cross-functional', 'Product thinking, roadmap, PM partnership',           5),
  ('Metrics & experimentation',  'Metric definition, A/B testing, causal inference',    6),
  ('Technical & execution',      'SQL, Python, architecture, delivery',                 7)
on conflict (name) do nothing;


-- 2. QUESTIONS (curated bank)
create table if not exists questions (
  id          serial primary key,
  category    text not null references categories(name) on update cascade,
  level       text not null check (level in ('Senior Manager','Director','VP','Head of','Any')),
  question    text not null,
  context     text,   -- "Why this is asked at this level"
  framework   text,   -- "How a great answer is structured"
  tags        text[], -- e.g. {'scaling','org-design','remote'}
  active      boolean default true,
  created_at  timestamptz default now()
);

-- Sample curated questions
insert into questions (category, level, question, context, framework, tags) values
  ('Leadership & org design','Director',
   'Walk me through how you have built and scaled an analytics function. What were the pivotal org design decisions?',
   'Interviewers want to see you own org outcomes, not just contribute to them. At Director level they expect 10–30+ person scope.',
   'STAR: start with org state you inherited → key inflection points → decisions made & trade-offs → measurable outcomes.',
   array['scaling','org-design']),

  ('Leadership & org design','VP',
   'You inherit a team that is perceived as a "report factory" by stakeholders. How do you shift toward strategic partnership in 90 days?',
   'Tests your ability to diagnose culture debt and drive rapid reorientation without losing the team.',
   'Diagnose → coalition build → quick wins → structural changes → sustained narrative shift.',
   array['transformation','stakeholders']),

  ('Strategy & stakeholders','Director',
   'How would you build the business case for doubling the analytics headcount to your CFO?',
   'Executives must be able to speak ROI fluently. This tests financial acumen and executive communication.',
   'Anchor to revenue or cost impact → current constraint → incremental capacity → expected return with timeline.',
   array['business-case','finance','headcount']),

  ('Strategy & stakeholders','VP',
   'A C-suite executive overrules one of your data-driven recommendations. How do you respond?',
   'Tests political maturity and ability to influence upward without damaging trust.',
   'Separate the decision from the relationship → seek to understand → reframe data → choose battles wisely.',
   array['influence','executive','conflict']),

  ('Behavioral / STAR','Any',
   'Tell me about the most difficult people decision you have made as a leader.',
   'At Director+ the bar is restructuring a team, exiting a senior person, or managing a high performer who is misaligned.',
   'STAR with emotional honesty: situation → your decision process → how you handled it → what you learned.',
   array['people','hard-decisions','leadership']),

  ('Behavioral / STAR','Any',
   'Describe a time a key initiative you championed significantly underperformed. What did you do?',
   'Tests self-awareness, accountability, and learning agility — critical differentiators at senior levels.',
   'Own it cleanly → root cause → pivots made → outcome → systemic changes you introduced afterward.',
   array['failure','accountability','learning']),

  ('Data & analytics strategy','Director',
   'How do you prevent analytical debt from accumulating as your team grows?',
   'Senior analytics leaders must balance speed of delivery with long-term maintainability.',
   'Define debt categories → triage → build governance rituals → create capacity allocation rules.',
   array['technical-debt','governance','scaling']),

  ('Metrics & experimentation','Director',
   'A major product metric drops 15% week-on-week. Walk me through your investigation framework.',
   'Tests structured thinking under pressure and command of the full analytics stack.',
   'Data sanity check → internal factors (feature releases, bugs) → external factors (seasonality, competition) → segment drill-down → hypothesis → resolution.',
   array['metrics','investigation','product']),

  ('Product & cross-functional','Director',
   'How do you decide which analytics requests to prioritise when every PM thinks their project is the most important?',
   'Tests prioritisation rigour and stakeholder management at scale.',
   'Align on value framework → score by impact × confidence ÷ effort → communicate trade-offs transparently → revisit cadence.',
   array['prioritisation','product','stakeholders']),

  ('Technical & execution','Senior Manager',
   'How do you ensure data quality across a pipeline that feeds executive dashboards?',
   'Even senior leaders must demonstrate operational credibility in data infrastructure.',
   'Define quality dimensions → instrument monitoring → SLA with owners → incident response → build vs buy decisions.',
   array['data-quality','infrastructure','reliability'])
on conflict do nothing;


-- 3. KNOWLEDGE BASES (system prompt sections — editable from Supabase dashboard)
create table if not exists knowledge_bases (
  id          serial primary key,
  key         text not null unique,  -- e.g. 'coaching_philosophy', 'seniority_bar'
  title       text not null,
  content     text not null,
  active      boolean default true,
  sort_order  int     default 0,
  updated_at  timestamptz default now()
);

insert into knowledge_bases (key, title, content, sort_order) values
  ('role_definition', 'Role Definition', 'You are an expert interview coach for senior data analytics and product leadership roles (Senior Manager, Director, VP, Head of) at top tech companies.', 1),

  ('coaching_philosophy', 'Coaching Philosophy', 'You have deep knowledge of real leadership situations drawn from senior analytics and product roles. Use this knowledge to inform the QUALITY and DEPTH of your coaching — but never reference specific companies, people, project names, or proprietary metrics in your responses. Your coaching should speak in themes, patterns, and frameworks that any senior leader could apply.', 2),

  ('domain_knowledge', 'Domain Knowledge', E'WHAT YOU KNOW (use as coaching intelligence, never quote directly):\n- How high-performing analytics teams are structured and scaled (from small specialist teams to 30+ person global orgs)\n- How fraud and trust & safety analytics work at scale — detection systems, metric trade-offs, policy enforcement pipelines\n- How to drive cross-functional influence across product, engineering, policy, legal, and vendor operations\n- How to navigate org redesigns — moving from vertical to pod models, managing redundancy and transition\n- How to reduce operational drag — cutting reporting latency, automating manual workflows, rebuilding backlogs\n- How pre-authorization, chargeback management, and payment fraud controls work in practice\n- How to build executive-level business cases with clear ROI framing\n- What VP and Director-level interviews actually test — and what separates good answers from great ones', 3),

  ('coaching_style', 'Coaching Style', E'- Speak in universal leadership principles, not specific anecdotes\n- Use phrases like "a strong answer here would show...", "at Director level, interviewers want to see...", "the pattern that works well is..."\n- When giving examples, invent plausible generic scenarios rather than referencing real situations\n- Always connect feedback to the seniority level — what''s acceptable at manager level is insufficient at Director/VP', 4),

  ('key_frameworks', 'Key Frameworks', E'- STAR with quantified outcomes and org-level impact\n- Product thinking: define customer → problem → metrics → options → prioritise → execute → risks\n- A/B testing: metric definition → hypothesis → design → statistical analysis\n- Metric investigation: data sanity → internal factors → external factors → scope & segment\n- Leadership goal-setting: 3 buckets — company-aligned projects, personal growth goals, process improvement\n- Org design thinking: span of control, specialisation vs generalisation, build vs buy vs borrow', 5),

  ('seniority_bar', 'Seniority Bar (Director+)', E'- Org-level thinking, not individual contributor thinking\n- Managing teams of 10-50+ people across functions or geographies\n- VP-level stakeholder influence and executive communication\n- Strategic tradeoffs, managing ambiguity, leading through change\n- Answers should demonstrate you''ve owned outcomes, not just contributed to them', 6)
on conflict (key) do nothing;


-- 4. SESSIONS (optional — stores practice session history)
create table if not exists sessions (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz default now(),
  company       text,
  role          text,
  level         text,
  function      text,
  categories    text[],
  question_ids  int[],   -- references questions.id if from curated bank
  answers       jsonb,   -- [{question, answer, feedback, score}]
  completed     boolean  default false
);


-- ── Row Level Security (enable after testing) ──
-- alter table questions     enable row level security;
-- alter table categories    enable row level security;
-- alter table knowledge_bases enable row level security;
-- alter table sessions      enable row level security;
-- create policy "public read" on questions     for select using (true);
-- create policy "public read" on categories    for select using (true);
-- create policy "public read" on knowledge_bases for select using (true);
-- create policy "own sessions" on sessions for all using (auth.uid() = user_id);
