'use strict';

const { Pool } = require('pg');

// Pool is created lazily on first use so that Firebase secrets are already
// injected into process.env before we try to read them.
let _pool = null;

function getPool() {
  if (!_pool) {
    _pool = new Pool({
      host:     process.env.SUPABASE_HOST,
      port:     parseInt(process.env.SUPABASE_PORT || '5432', 10),
      database: process.env.SUPABASE_DATABASE || 'postgres',
      user:     process.env.SUPABASE_USER     || 'postgres',
      password: process.env.SUPABASE_PASSWORD,
      ssl:      { rejectUnauthorized: false },
      max:      5,
      idleTimeoutMillis:       10000,
      connectionTimeoutMillis: 5000,
    });
    _pool.on('error', (err) => {
      console.error('Supabase pool error:', err.message);
    });
  }
  return _pool;
}

module.exports = { getPool };
