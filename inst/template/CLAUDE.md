# PM Surveillance Data Model

This project analyzes prediction market data from the `pm_surveillance` MotherDuck database.
Use the `pmsurveillance` R package for connection and discovery.

## Quick Start

```r
library(pmsurveillance)
con <- pm_connect()        # Connect to MotherDuck
pm_catalog(con)            # See all available tables and views
pm_disconnect(con)         # Clean up when done
```

All data is in MotherDuck (cloud DuckDB). No local data storage. Credentials via `MOTHERDUCK_TOKEN` in `~/.Renviron`.

## Exchanges

6 exchanges are tracked, covering all US-regulated prediction markets:

| Exchange | Name | Volume | Notes |
|----------|------|--------|-------|
| kalshi | Kalshi | ~500K trades/day | Largest US prediction market, REST API |
| polymarket | Polymarket | ~150K+ events/day | On-chain via Goldsky subgraph |
| polymarket_us | Polymarket US | ~63K trades/day | QCX LLC DCM, CSV reports |
| forecastex | ForecastEx | ~20K trades/day | Robinhood-connected, CSV reports |
| cme_events | CME Events | markets+settlements only | Event contracts, PDF bulletin, no trades |
| nadex | Nadex | varies | Binary options, PDF reports |

## Taxonomy System

Every market is classified into structured dimensions via `market_taxonomy`. These fields power all cross-exchange analysis:

- **asset_class**: crypto, equity_index, sports, politics, economics, weather, entertainment, fixed_income
- **subcategory**: btc, eth, sol, nba, nfl, mlb, presidential, fed_rates, cpi, temperature, etc.
- **product_type**: daily_price, game_outcome, player_prop, moneyline, over_under, series_winner, etc.
- **sport**: nba, nfl, mlb, nhl, soccer, etc.
- **underlying_ticker**: BTC, ETH, SPX, NDX, etc.
- **team_home**, **team_away**: team names for sports
- **player_name**, **prop_stat**: for player props
- **event_date**: when the event occurs
- **strike_value**, **strike_unit**: for threshold contracts (e.g., BTC > $100,000)

## Canonical Events (Cross-Exchange Matching)

Markets across exchanges are matched to **canonical events** — the real-world thing a trader thinks about:

- "Bitcoin daily price — Feb 27, 2026" (all BTC strike contracts on that date = one event)
- "Bills at Patriots — NFL 2026-02-28" (moneyline, spread, totals for the same game = one event)

Two matching tiers:
- **Tier 1** (confidence=1.0): Same underlying_ticker + event_date across exchanges
- **Tier 2** (confidence=0.95): Same teams + event_date across exchanges

Tables: `canonical_events`, `market_event_links`, `event_relationships`

Current scale: ~300 canonical events, ~80K market-event links across 5 asset classes.

## Key Analysis Views

### Trades & Volume

| View | Description | Key Columns |
|------|-------------|-------------|
| `v_trades_enriched` | Trades + market title/category. Handles Polymarket token mapping automatically. | exchange, market_id, price_prob, notional_usd, source_date, market_title, market_category |
| `v_trades_taxonomized` | Trades + all taxonomy fields. **The go-to view for analysis by asset class, sport, etc.** | exchange, market_id, price_prob, notional_usd, source_date, asset_class, subcategory, product_type, sport, underlying_ticker |
| `v_daily_volume` | Daily aggregates by exchange + market category. | source_date, exchange, category, trade_count, total_contracts, total_notional_usd |
| `v_daily_exchange_summary` | Daily exchange stats. Lightweight, no joins. Good for time series. | source_date, exchange, trade_count, total_notional_usd, active_markets |
| `v_hourly_prices` | Hourly OHLC per market/contract. For price charting. | exchange, market_id, hour_utc, open, high, low, close, volume_usd |
| `v_volume_by_taxonomy` | Daily volume by taxonomy dimensions. | source_date, exchange, asset_class, subcategory, product_type, trades, notional |

### Cross-Exchange Intelligence

| View | Description | Key Columns |
|------|-------------|-------------|
| `v_market_pairs` | Cross-exchange market pairs matched via canonical events. Each row = two markets on different exchanges referencing the same event. | event_id, description, exchange_a, title_a, exchange_b, title_b, asset_class |
| `v_exchange_gaps` | Events listed on only one exchange. Reveals competitive gaps. | event_id, description, listed_on, asset_class, market_count |
| `v_cross_exchange` | Volume comparison across exchanges by taxonomy subcategory. | asset_class, subcategory, exchange, trades, notional, markets |

### Portfolio & Risk

| View | Description | Key Columns |
|------|-------------|-------------|
| `v_event_portfolio` | Trades linked to canonical events. For exposure/position analysis. | event_id, description, exchange, market_id, quantity, notional_usd, price_prob |
| `v_factor_exposure` | Event correlation graph. For risk decomposition. | relationship_type, correlation_est, event_a, event_b, rationale |

### Operational

| View | Description |
|------|-------------|
| `v_exchange_coverage` | Data completeness per exchange (date range, market count, notional) |
| `v_backfill_progress` | Historical backfill completion status per exchange |
| `v_series_coverage` | Kalshi series classification coverage |

## Core Tables

### trades
- **Primary key**: trade_uid (MD5 of exchange+market_id+contract_id+timestamp+price+qty)
- **Key columns**: exchange, market_id, contract_id, price_prob (0-1 probability), quantity, notional_usd, source_date, trade_time_utc
- **Scale**: ~15M+ rows
- **Join to markets**: `ON t.exchange = m.exchange AND t.market_id = m.market_id`
- **Join to taxonomy**: `ON t.exchange = tx.exchange AND t.market_id = tx.market_id`

### markets
- **Primary key**: market_uid (MD5 of exchange+market_id)
- **Key columns**: exchange, market_id, title, category, subcategory, status, volume_usd, series_id, meta_json
- **Scale**: ~300K+ rows

### market_taxonomy
- **Primary key**: market_uid
- **Key columns**: exchange, market_id, asset_class, subcategory, product_type, sport, underlying_ticker, team_home, team_away, player_name, event_date, strike_value
- **Join to trades**: `ON tx.exchange = t.exchange AND tx.market_id = t.market_id`

### canonical_events
- **Primary key**: event_id (deterministic hash)
- **Key columns**: event_type (strike_ladder, binary_outcome, multi_outcome), underlying, description, event_date, asset_class, subcategory, sport, market_count, exchange_count

### market_event_links
- **Primary key**: (market_uid, event_id)
- **Key columns**: exchange, market_id, title, link_confidence, link_method (structural, ai_validated, ai_discovered), side

### settlements
- **Primary key**: settlement_uid
- **Key columns**: exchange, market_id, contract_id, result, settlement_value, settlement_time_utc

## Common Query Patterns

### Cross-exchange pairs for a sport
```sql
SELECT * FROM v_market_pairs
WHERE sport = 'nba'
ORDER BY event_date DESC
```

### What's on Kalshi but not Polymarket
```sql
SELECT * FROM v_exchange_gaps
WHERE listed_on = 'kalshi'
  AND asset_class = 'crypto'
ORDER BY market_count DESC
```

### Daily volume by taxonomy
```sql
SELECT source_date, exchange, subcategory,
       SUM(notional) as total_notional
FROM v_volume_by_taxonomy
WHERE asset_class = 'sports'
  AND source_date >= CURRENT_DATE - 30
GROUP BY ALL
ORDER BY source_date, total_notional DESC
```

### Net exposure across exchanges
```sql
SELECT event_id, description,
  SUM(CASE WHEN exchange = 'kalshi' THEN notional_usd ELSE 0 END) as kalshi_notional,
  SUM(CASE WHEN exchange = 'polymarket' THEN notional_usd ELSE 0 END) as poly_notional
FROM v_event_portfolio
GROUP BY event_id, description
HAVING COUNT(DISTINCT exchange) > 1
ORDER BY kalshi_notional + poly_notional DESC
```

### Volume time series for a specific market type
```sql
SELECT source_date, exchange,
       COUNT(*) as trades,
       SUM(notional_usd) as notional
FROM v_trades_taxonomized
WHERE asset_class = 'weather'
  AND subcategory = 'temperature'
GROUP BY source_date, exchange
ORDER BY source_date
```

### Exchange market share over time
```sql
SELECT source_date, exchange,
       total_notional_usd,
       total_notional_usd / SUM(total_notional_usd) OVER (PARTITION BY source_date) as market_share
FROM v_daily_exchange_summary
WHERE source_date >= CURRENT_DATE - 90
ORDER BY source_date, exchange
```

## R Conventions

- Use **targets** pipeline (`_targets.R`) for reproducibility
- Query MotherDuck views — don't duplicate transformation logic locally
- `R/` directory for analysis functions, `output/` for generated artifacts
- `pm_catalog(con)` to discover available data at any time
- DuckDB SQL is compatible with most PostgreSQL syntax
- Use `dbGetQuery(con, sql)` for read queries, returns a data.frame
