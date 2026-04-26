'use strict';

const { Pool } = require('pg');

// Single pool instance — Cloud Functions reuse warm containers, so one
// pool is shared across all invocations on the same instance.
const pool = new Pool({
  host:     process.env.SUPABASE_HOST,
  port:     parseInt(process.env.SUPABASE_PORT || '5432', 10),
  database: process.env.SUPABASE_DATABASE || 'postgres',
  user:     process.env.SUPABASE_USER     || 'postgres',
  password: process.env.SUPABASE_PASSWORD,
  ssl:      { rejectUnauthorized: false }, // required for Supabase
  max:      5,    // max connections per Cloud Function instance
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  console.error('Supabase pool error:', err.message);
});

module.exports = pool;
