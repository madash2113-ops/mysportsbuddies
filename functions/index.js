'use strict';

const { onDocumentWritten }  = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret }       = require('firebase-functions/params');
const functions              = require('firebase-functions'); // v1 compat for Auth trigger
const admin                  = require('firebase-admin');
const { getPool }            = require('./db');

admin.initializeApp();

// Declare secrets so Firebase injects them as environment variables at runtime
const SUPABASE_HOST     = defineSecret('SUPABASE_HOST');
const SUPABASE_PASSWORD = defineSecret('SUPABASE_PASSWORD');

// Shared options applied to every Supabase-sync trigger
const fnOpts = {
  secrets: [SUPABASE_HOST, SUPABASE_PASSWORD],
  timeoutSeconds: 60,
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

const ts = (v) => {
  if (!v) return null;
  if (v.toDate) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  return null;
};

const run = async (label, queryFn) => {
  try {
    await queryFn();
  } catch (err) {
    console.error(`[${label}] Supabase error:`, err.message);
    throw err;
  }
};

// ─── USERS ────────────────────────────────────────────────────────────────────

exports.syncUser = onDocumentWritten({ document: 'users/{userId}', ...fnOpts }, async (event) => {
  const pool = getPool();
  const uid  = event.params.userId;

  if (!event.data.after.exists) {
    await run('syncUser:delete', () =>
      pool.query('DELETE FROM users WHERE id = $1', [uid])
    );
    return;
  }

  const d = event.data.after.data();

  await run('syncUser:upsert', () =>
    pool.query(`
      INSERT INTO users (
        id, numeric_id, name, email, phone, location,
        dob, bio, image_url, is_premium, is_admin,
        plan_tier, subscription_status,
        tournaments_played, matches_played, matches_won,
        favorite_sports, updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,NOW()
      )
      ON CONFLICT (id) DO UPDATE SET
        numeric_id          = EXCLUDED.numeric_id,
        name                = EXCLUDED.name,
        email               = EXCLUDED.email,
        phone               = EXCLUDED.phone,
        location            = EXCLUDED.location,
        dob                 = EXCLUDED.dob,
        bio                 = EXCLUDED.bio,
        image_url           = EXCLUDED.image_url,
        is_premium          = EXCLUDED.is_premium,
        is_admin            = EXCLUDED.is_admin,
        plan_tier           = EXCLUDED.plan_tier,
        subscription_status = EXCLUDED.subscription_status,
        tournaments_played  = EXCLUDED.tournaments_played,
        matches_played      = EXCLUDED.matches_played,
        matches_won         = EXCLUDED.matches_won,
        favorite_sports     = EXCLUDED.favorite_sports,
        updated_at          = NOW()
    `, [
      uid,
      d.numericId          ?? null,
      d.name               ?? null,
      d.email              ?? null,
      d.phone              ?? null,
      d.location           ?? null,
      d.dob                ?? null,
      d.bio                ?? null,
      d.imageUrl           ?? null,
      d.isPremium          ?? false,
      d.isAdmin            ?? false,
      d.planTier           ?? 'free',
      d.subscriptionStatus ?? 'none',
      d.tournamentsPlayed  ?? 0,
      d.matchesPlayed      ?? 0,
      d.matchesWon         ?? 0,
      d.favoriteSports     ?? [],
    ])
  );
});

// ─── VENUES ───────────────────────────────────────────────────────────────────

exports.syncVenue = onDocumentWritten({ document: 'venues/{venueId}', ...fnOpts }, async (event) => {
  const pool = getPool();
  const vid  = event.params.venueId;

  if (!event.data.after.exists) {
    await run('syncVenue:delete', () =>
      pool.query('DELETE FROM venues WHERE id = $1', [vid])
    );
    return;
  }

  const d = event.data.after.data();

  await run('syncVenue:upsert', () =>
    pool.query(`
      INSERT INTO venues (
        id, owner_id, name, description, address,
        lat, lng, sports, photo_urls, phone, email,
        price_per_hour, timings, status, is_verified,
        rating, review_count, created_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18
      )
      ON CONFLICT (id) DO UPDATE SET
        name           = EXCLUDED.name,
        description    = EXCLUDED.description,
        address        = EXCLUDED.address,
        lat            = EXCLUDED.lat,
        lng            = EXCLUDED.lng,
        sports         = EXCLUDED.sports,
        photo_urls     = EXCLUDED.photo_urls,
        status         = EXCLUDED.status,
        is_verified    = EXCLUDED.is_verified,
        rating         = EXCLUDED.rating,
        review_count   = EXCLUDED.review_count,
        price_per_hour = EXCLUDED.price_per_hour,
        timings        = EXCLUDED.timings
    `, [
      vid,
      d.ownerId       ?? null,
      d.name          ?? null,
      d.description   ?? null,
      d.address       ?? null,
      d.lat           ?? null,
      d.lng           ?? null,
      d.sports        ?? [],
      d.photoUrls     ?? [],
      d.phone         ?? null,
      d.email         ?? null,
      d.pricePerHour  ?? 0,
      JSON.stringify(d.timings ?? {}),
      d.status        ?? 'active',
      d.isVerified    ?? false,
      d.rating        ?? 0,
      d.reviewCount   ?? 0,
      ts(d.createdAt) ?? new Date().toISOString(),
    ])
  );
});

// ─── TOURNAMENTS ──────────────────────────────────────────────────────────────

exports.syncTournament = onDocumentWritten(
  { document: 'tournaments/{tournamentId}', ...fnOpts },
  async (event) => {
    const pool = getPool();
    const tid  = event.params.tournamentId;

    if (!event.data.after.exists) {
      await run('syncTournament:delete', () =>
        pool.query('DELETE FROM tournaments WHERE id = $1', [tid])
      );
      return;
    }

    const d = event.data.after.data();

    await run('syncTournament:upsert', () =>
      pool.query(`
        INSERT INTO tournaments (
          id, name, sport, format, status, location,
          created_by, created_by_name,
          max_teams, players_per_team,
          entry_fee, service_fee, registered_teams,
          enrolled_team_names, prize_pool, rules, description,
          banner_url, is_private, join_code,
          bracket_generated, has_groups, group_count,
          scoring_type, best_of, points_to_win,
          win_points, draw_points, loss_points,
          start_date, end_date, created_at, updated_at
        ) VALUES (
          $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
          $11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
          $21,$22,$23,$24,$25,$26,$27,$28,$29,
          $30,$31,$32,NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
          name                = EXCLUDED.name,
          status              = EXCLUDED.status,
          registered_teams    = EXCLUDED.registered_teams,
          enrolled_team_names = EXCLUDED.enrolled_team_names,
          bracket_generated   = EXCLUDED.bracket_generated,
          has_groups          = EXCLUDED.has_groups,
          group_count         = EXCLUDED.group_count,
          banner_url          = EXCLUDED.banner_url,
          rules               = EXCLUDED.rules,
          description         = EXCLUDED.description,
          start_date          = EXCLUDED.start_date,
          end_date            = EXCLUDED.end_date,
          updated_at          = NOW()
      `, [
        tid,
        d.name, d.sport, d.format, d.status, d.location,
        d.createdBy         ?? null,
        d.createdByName     ?? null,
        d.maxTeams          ?? 0,
        d.playersPerTeam    ?? 0,
        d.entryFee          ?? 0,
        d.serviceFee        ?? 0,
        d.registeredTeams   ?? 0,
        d.enrolledTeamNames ?? [],
        d.prizePool         ?? null,
        d.rules             ?? null,
        d.description       ?? null,
        d.bannerUrl         ?? null,
        d.isPrivate         ?? false,
        d.joinCode          ?? null,
        d.bracketGenerated  ?? false,
        d.hasGroups         ?? false,
        d.groupCount        ?? 0,
        d.scoringType       ?? 'standard',
        d.bestOf            ?? 3,
        d.pointsToWin       ?? 21,
        d.winPoints         ?? 3,
        d.drawPoints        ?? 1,
        d.lossPoints        ?? 0,
        ts(d.startDate),
        ts(d.endDate),
        ts(d.createdAt) ?? new Date().toISOString(),
      ])
    );
  }
);

// ─── TEAMS ────────────────────────────────────────────────────────────────────

exports.syncTeam = onDocumentWritten(
  { document: 'tournaments/{tournamentId}/teams/{teamId}', ...fnOpts },
  async (event) => {
    const pool   = getPool();
    const teamId = event.params.teamId;
    const tournId = event.params.tournamentId;

    if (!event.data.after.exists) {
      await run('syncTeam:delete', async () => {
        await pool.query('DELETE FROM team_players WHERE team_id = $1', [teamId]);
        await pool.query('DELETE FROM teams WHERE id = $1', [teamId]);
      });
      return;
    }

    const d          = event.data.after.data();
    const players    = d.players    ?? [];
    const playerUids = d.playerUserIds ?? [];

    await run('syncTeam:upsert', async () => {
      await pool.query(`
        INSERT INTO teams (
          id, tournament_id, team_name,
          captain_name, captain_user_id, captain_phone,
          vice_captain_name, vice_captain_user_id,
          enrolled_by, seed, payment_confirmed, enrolled_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
        ON CONFLICT (id) DO UPDATE SET
          team_name            = EXCLUDED.team_name,
          captain_name         = EXCLUDED.captain_name,
          vice_captain_name    = EXCLUDED.vice_captain_name,
          seed                 = EXCLUDED.seed,
          payment_confirmed    = EXCLUDED.payment_confirmed
      `, [
        teamId, tournId,
        d.teamName          ?? null,
        d.captainName       ?? null,
        d.captainUserId     || null,
        d.captainPhone      ?? null,
        d.viceCaptainName   || null,
        d.viceCaptainUserId || null,
        d.enrolledBy        || null,
        d.seed              ?? null,
        d.paymentConfirmed  ?? false,
        ts(d.enrolledAt) ?? new Date().toISOString(),
      ]);

      await pool.query('DELETE FROM team_players WHERE team_id = $1', [teamId]);
      for (let i = 0; i < players.length; i++) {
        await pool.query(`
          INSERT INTO team_players (team_id, tournament_id, user_id, player_name, position)
          VALUES ($1,$2,$3,$4,$5)
        `, [
          teamId, tournId,
          playerUids[i] || null,
          players[i]    || null,
          i,
        ]);
      }
    });
  }
);

// ─── MATCHES ──────────────────────────────────────────────────────────────────

exports.syncMatch = onDocumentWritten(
  { document: 'tournaments/{tournamentId}/matches/{matchId}', ...fnOpts },
  async (event) => {
    const pool    = getPool();
    const matchId = event.params.matchId;
    const tournId = event.params.tournamentId;

    if (!event.data.after.exists) {
      await run('syncMatch:delete', () =>
        pool.query('DELETE FROM matches WHERE id = $1', [matchId])
      );
      return;
    }

    const d = event.data.after.data();

    await run('syncMatch:upsert', () =>
      pool.query(`
        INSERT INTO matches (
          id, tournament_id, round, match_index,
          team_a_id, team_a_name, team_b_id, team_b_name,
          winner_id, winner_name,
          score_a, score_b, result,
          is_bye, is_live, note, group_id,
          venue_id, venue_name, live_stream_url,
          scorecard_data, scheduled_at, updated_at
        ) VALUES (
          $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
          $11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
          $21,$22,NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
          team_a_id      = EXCLUDED.team_a_id,
          team_a_name    = EXCLUDED.team_a_name,
          team_b_id      = EXCLUDED.team_b_id,
          team_b_name    = EXCLUDED.team_b_name,
          winner_id      = EXCLUDED.winner_id,
          winner_name    = EXCLUDED.winner_name,
          score_a        = EXCLUDED.score_a,
          score_b        = EXCLUDED.score_b,
          result         = EXCLUDED.result,
          is_live        = EXCLUDED.is_live,
          scorecard_data = EXCLUDED.scorecard_data,
          scheduled_at   = EXCLUDED.scheduled_at,
          updated_at     = NOW()
      `, [
        matchId, tournId,
        d.round         ?? 1,
        d.matchIndex    ?? 0,
        d.teamAId       || null,
        d.teamAName     || null,
        d.teamBId       || null,
        d.teamBName     || null,
        d.winnerId      || null,
        d.winnerName    || null,
        d.scoreA        ?? null,
        d.scoreB        ?? null,
        d.result        ?? 'pending',
        d.isBye         ?? false,
        d.isLive        ?? false,
        d.note          ?? null,
        d.groupId       || null,
        d.venueId       || null,
        d.venueName     || null,
        d.liveStreamUrl || null,
        d.scorecardData ? JSON.stringify(d.scorecardData) : null,
        ts(d.scheduledAt),
      ])
    );
  }
);

// ─── SCOREBOARDS ──────────────────────────────────────────────────────────────

exports.syncScoreboard = onDocumentWritten(
  { document: 'matches/{matchId}', ...fnOpts },
  async (event) => {
    const pool    = getPool();
    const matchId = event.params.matchId;

    if (!event.data.after.exists) {
      await run('syncScoreboard:delete', () =>
        pool.query('DELETE FROM scoreboards WHERE id = $1', [matchId])
      );
      return;
    }

    const d = event.data.after.data();

    await run('syncScoreboard:upsert', () =>
      pool.query(`
        INSERT INTO scoreboards (
          id, tournament_id, sport, score_data,
          team_a_id, team_a_name, team_b_id, team_b_name,
          score_a, score_b, winner_id, is_live, updated_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,NOW())
        ON CONFLICT (id) DO UPDATE SET
          score_data = EXCLUDED.score_data,
          score_a    = EXCLUDED.score_a,
          score_b    = EXCLUDED.score_b,
          winner_id  = EXCLUDED.winner_id,
          is_live    = EXCLUDED.is_live,
          updated_at = NOW()
      `, [
        matchId,
        d.tournamentId || null,
        d.sport        || null,
        d.scoreData ? JSON.stringify(d.scoreData) : null,
        d.teamAId      || null,
        d.teamAName    || null,
        d.teamBId      || null,
        d.teamBName    || null,
        d.scoreA       ?? null,
        d.scoreB       ?? null,
        d.winnerId     || null,
        d.isLive       ?? false,
      ])
    );
  }
);

// ─── GAME LISTINGS ────────────────────────────────────────────────────────────

exports.syncGameListing = onDocumentWritten(
  { document: 'game_listings/{listingId}', ...fnOpts },
  async (event) => {
    const pool = getPool();
    const lid  = event.params.listingId;

    if (!event.data.after.exists) {
      await run('syncGameListing:delete', () =>
        pool.query('DELETE FROM game_listings WHERE id = $1', [lid])
      );
      return;
    }

    const d = event.data.after.data();

    await run('syncGameListing:upsert', () =>
      pool.query(`
        INSERT INTO game_listings (
          id, organizer_id, organizer_name, sport,
          venue_name, address, lat, lng,
          scheduled_at, max_players, current_players,
          fee, description, status, created_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
        ON CONFLICT (id) DO UPDATE SET
          current_players = EXCLUDED.current_players,
          status          = EXCLUDED.status,
          max_players     = EXCLUDED.max_players,
          fee             = EXCLUDED.fee
      `, [
        lid,
        d.organizerId   || null,
        d.organizerName || null,
        d.sport         || null,
        d.venueName     || null,
        d.address       || null,
        d.lat           ?? null,
        d.lng           ?? null,
        ts(d.scheduledAt),
        d.maxPlayers    ?? null,
        d.currentPlayers ?? 0,
        d.fee           ?? 0,
        d.description   || null,
        d.status        || 'open',
        ts(d.createdAt) ?? new Date().toISOString(),
      ])
    );
  }
);

// ─── FOLLOWS ─────────────────────────────────────────────────────────────────

exports.syncFollow = onDocumentWritten(
  { document: 'follows/{followId}', ...fnOpts },
  async (event) => {
    const pool     = getPool();
    const followId = event.params.followId;
    const parts    = followId.split('_');
    if (parts.length < 2) return;
    const [followerId, followedId] = parts;

    if (!event.data.after.exists) {
      await run('syncFollow:delete', () =>
        pool.query(
          'DELETE FROM follows WHERE follower_id = $1 AND followed_id = $2',
          [followerId, followedId]
        )
      );
      return;
    }

    const d = event.data.after.data();

    await run('syncFollow:upsert', () =>
      pool.query(`
        INSERT INTO follows (follower_id, followed_id, created_at)
        VALUES ($1, $2, $3)
        ON CONFLICT (follower_id, followed_id) DO NOTHING
      `, [
        followerId,
        followedId,
        ts(d.createdAt) ?? new Date().toISOString(),
      ])
    );
  }
);

// ─── NUMERIC USER IDs ─────────────────────────────────────────────────────────

const db = admin.firestore();
const COUNTER_DOC = 'config/numericIdCounter';
const USERS_COL = 'users';

/**
 * Atomically claims the next sequential 6-digit app user ID and writes it to
 * the user's Firestore document.  Idempotent: returns the existing ID if the
 * user already has one.
 */
async function assignNumericId(uid) {
  const userRef = db.collection(USERS_COL).doc(uid);

  // Idempotent check — avoid a transaction if the ID already exists
  const userSnap = await userRef.get();
  if (userSnap.exists) {
    const existing = userSnap.data()?.numericId;
    if (existing) return existing;
  }

  // Atomically claim the next counter value
  const counterRef = db.doc(COUNTER_DOC);
  const newId = await db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const next = (snap.data()?.next) ?? 100000; // 6-digit floor
    tx.set(counterRef, { next: next + 1 }, { merge: true });
    return next;
  });

  // Write the ID to the user document (merge so we never overwrite other fields)
  await userRef.set(
    { numericId: newId, numericIdStr: String(newId) },
    { merge: true },
  );

  console.log(`Assigned numericId ${newId} to ${uid}`);
  return newId;
}

// Auth trigger — fires when a new Firebase Auth account is created.
// Anonymous accounts are skipped; they receive an ID only if they later
// upgrade to a real account via reloadForUser().
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
  if (!user.providerData || user.providerData.length === 0) return null;
  try {
    await assignNumericId(user.uid);
  } catch (err) {
    console.error('onUserCreated: numericId assignment failed', user.uid, err);
  }
  return null;
});

// Callable fallback — the Flutter app calls this on every sign-in.
// For new users the Auth trigger has already written the ID; the idempotent
// check makes this a no-op.  For older accounts created before the trigger
// existed, this is the only path that will generate the missing ID.
exports.ensureNumericId = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  try {
    const numericId = await assignNumericId(uid);
    return { numericId };
  } catch (err) {
    console.error('ensureNumericId: failed for', uid, err);
    throw new HttpsError('internal', 'Failed to generate numeric ID.');
  }
});
