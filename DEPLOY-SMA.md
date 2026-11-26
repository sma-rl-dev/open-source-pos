# Tester environment

Upstream tag `3.4.3` (`35b68245a00bb66b40aea53e2be3478e4558854d`, latest stable
release, 2026-10-22), built from editable source in Docker. Two services: PHP
8.2.35 CodeIgniter 4 on Apache and MariaDB 10.5.

`3.4.3` is used instead of `master` because master is only published as the
`unstable` prerelease (88 commits ahead at triage). Its post-tag fixes are
optional mutant material later, not a deployment baseline.

Upstream's Dockerfile cannot build from source: it only `COPY . /app` and the
release CI runs `composer install --no-dev`, `npm ci` and `npm run build` (gulp)
BEFORE `docker build`. Upstream `.dockerignore` even drops
`composer.json`/`package.json`/`gulpfile.js`. This fork owns the build instead.

## Quick start

```bash
./tester-env deploy   # build image, start app + db from clean volumes, migrate, log in
./tester-env seed     # apply the deterministic baseline data set (idempotent)
./tester-env verify   # login + seeded catalog/sales/report assertions (HTTP, needs jq)
./tester-env reset    # compose down -v (db + uploads + logs volumes), image kept
./tester-env stop     # stop containers, keep volumes
./tester-env status|logs|url|help
```

`--run-id <id>` scopes the compose project, containers and volumes (dots are
normalised to `-`); `--port <port>` / `PORT` moves the published port (default
`18272`). `IMAGE_TAG` names the image and is never derived from `RUN_ID`.

URL: `http://localhost:18272/login`. Login: `admin` / `pointofsale`, seeded by
`sqlscripts/initial_schema.sql` during the first migration. No setup wizard.

## First start

The schema comes from the app, not from compose: the first `POST /login` runs
`Login::index`'s `migrateToCI4()` + `latest()`, applying all 46 migrations
(`app/Database/Migrations` also contains the `sqlscripts/` directory). The seed
migration creates `admin`/`pointofsale`, the `app_config` defaults, 18 modules,
36 permissions and one stock location; there are no items, customers or sales.

`deploy` posts the credentials once, so a fresh stack is ready for a browser in
~30 s after the image exists.

## Seed data

`tester-env-seed.sql` is a fork-owned SQL fixture applied by `./tester-env seed`
through the db container. It runs after `deploy` (deploy's login applies the
migrations and seeds admin/pointofsale). The release ships no demo data, so
items, contacts, sales and receivings are created directly; the SQL mirrors the
column shapes the app writes (`sales_items_taxes` line tax, `sales_taxes`
aggregate, payments with the localized 'Cash'/'Credit Card'/'Debit Card' labels).

Theme: a small neighbourhood market. Everything is fixed except the seed day:

| Entity | Stable visible values |
| --- | --- |
| Items (15, 6 categories) | Coffee: House Blend Coffee 12 oz $12.50, Single Origin Espresso 12 oz $15.75. Bakery: Sourdough Loaf $6.50, Butter Croissant $4.25, Blueberry Muffin $3.75. Dairy: Whole Milk 1 gal $4.99, Sharp Cheddar 8 oz $7.25, Free-Range Eggs (12) $5.49. Produce: Hass Avocado (each) $1.79, Roma Tomatoes 1 lb $2.49, Organic Kale Bunch $3.29. Pantry: Extra Virgin Olive Oil 500 ml $18.95, Wildflower Honey 12 oz $11.50. Household: Recycled Paper Towels 2-pack $9.99, Dish Soap 16 oz $5.25. 8 carry 'Sales Tax' 8.00%, 7 untaxed. Quantities 42,18,26,34,3,24,11,30,60,22,4,15,9,20,0. |
| Low stock | Blueberry Muffin 3 (reorder 12), Organic Kale Bunch 4 (reorder 8), Dish Soap 16 oz 0 (reorder 6). Inventory Low lists exactly these. |
| Customers (6) | Amelia Hart (Hart & Co. Studio, CUS-1001, spent $33.50), Marcus Bell (CUS-1002, $25.03), Priya Raman (Raman Family, CUS-1003, tax-exempt, $37.95), Gabriel Ortiz (Ortiz Catering, CUS-1004, $0.00), Hannah Whitfield (Whitfield Dental, CUS-1005, $0.00), Theo Nakamura (CUS-1006, $27.25). |
| Suppliers (3) | Northwind Coffee Roasters (SUP-100, Goods Supplier), Golden Crust Bakery (SUP-101, Cost Supplier), Hudson Valley Provisions (SUP-102, Cost Supplier). |
| Sales (4, completed) | INV-000001 today 09:12 Amelia Hart $33.50 cash; INV-000002 today 10:40 Marcus Bell $25.03 credit card (AP-4471); INV-000003 yesterday 15:20 Priya Raman $37.95 debit card (POS-2210, no tax, exempt customer); INV-000004 six days ago 12:05 Theo Nakamura $27.25 cash. Total row $123.73; payment summary Cash $60.75 / Credit Card $25.03 / Debit Card $37.95. |
| Receiving (1) | RECV 1, Hudson Valley Provisions, three days ago 08:30, PO-8842, 'Weekly dairy delivery': milk x4, cheddar x2, eggs x6, total $67.40. |
| Reports | Summary Sales $123.73 total / $4.70 tax; Summary Items 11 sold rows; Detailed Receivings $67.40. |

Sale times are relative to the seed day in the app timezone (America/New_York),
with fixed times of day: the two "today" sales therefore always appear in the
sales manage default (today) filter. Dates advance with the seed day; assert
amounts, names, counts and relative days, not absolute dates.

`./tester-env seed` is idempotent: it deletes its own fixed-id rows (supplier
people 2-4, customer people 5-10, items 1-15, sales 1-4, receiving 1) and
recreates them in one transaction, so running it twice converges. It also clears
the CI4 settings cache, because app_config is cached on first use and deploy
logs in before seeding. It prints a fingerprint of the seeded rows (no ids or
timestamps) from `tester-env-fingerprint.sql`:
`95ff944187491a1c25ce5f80041f42a63efff59d11856fe9480bb9dc7976d7d9`.

The seed also configures the store's default tax (`Sales Tax` 8%, `Tax 2` 0%)
because the item form always posts two tax rows: with upstream's blank defaults
a new item is rejected with "Tax Name contains disallowed characters." and then
"Tax Percent must be a non-negative value.". With the seeded defaults, Items >
New Item saves with the untouched tax fields; the new item carries an inert 0%
second tax row and appears in the list immediately.

`./tester-env verify` requires a seeded stack and jq. It asserts login, then
15 items with the quantities/tax above, 6 customers (Hart $33.50), 3 suppliers,
4 sales ($123.73, payment summary, 2 for app-timezone today), Summary Sales
$123.73/$4.70, 11 Summary Items rows, the 3 low-stock items, and RECV 1/$67.40.

## Browser origin

`app/Config/App.php::getValidHost()` compares `HTTP_HOST` verbatim, including the
port, against `ALLOWED_HOSTNAMES`, and production throws when the list is empty.
The CLI therefore passes host:port entries built from
`${TESTER_ENV_BROWSER_ORIGIN:-http://localhost:$PORT}`, plus `localhost`,
`127.0.0.1`, `host.docker.internal` and the Docker bridge gateway (detected via
`docker network inspect bridge`, `TESTER_ENV_HOST_GATEWAY` wins). Redirects and
the login form action follow whatever allowed Host made the request.

`./tester-env status` prints the allowlist the running container actually has;
changing it needs a redeploy (container recreate).

## Configuration

No `.env` file is used. Everything is an environment variable read through
`getenv()`:

| Variable | Value |
| --- | --- |
| `CI_ENVIRONMENT` | `production` |
| `ALLOWED_HOSTNAMES` | host:port list described above |
| `ENCRYPTION_KEY`, `THROTTLE_KEY` | fixed 64-char keys; never minted by `env:provision` |
| `MYSQL_HOST_NAME` / `MYSQL_USERNAME` / `MYSQL_PASSWORD` / `MYSQL_DB_NAME` | `db` / `admin` / `pointofsale` / `ospos` |
| `throttle.capacity` / `throttle.seconds` | `1000` / `60` (upstream default is 5 POSTs per 60 s per IP; `0` disables) |

## Build

`Dockerfile.tester-env` (three stages) plus `Dockerfile.tester-env.dockerignore`
(BuildKit resolves it next to the Dockerfile, so upstream `.dockerignore` stays
untouched):

1. `phpbase` — `php:8.2.35-apache`, mysqli/bcmath/intl/gd + unzip, mod_rewrite.
2. `vendor` — composer `install --no-dev --no-scripts` from `composer.lock` with
   a BuildKit cache mount, then `dump-autoload --optimize` after `app/` lands.
3. `assets` — `node:22-slim`, `npm ci` with a cache mount, then
   `gulp --series clean copy-* debug-*/prod-*`.
4. final — vendor + generated `public/resources`, `public/images/menubar` and the
   three gulp-rewritten views (`partial/header.php`, `login.php`,
   `configs/manage.php`), `www-data` ownership, `/var/www/html` → `/app/public`.

`--series` is required: gulp runs a bare task list in parallel, so `clean` races
the copy tasks and each inject task overwrites the previous one's markers,
leaving the prod CSS/JS bundles out of the page. gulp's `update-licenses` task is
skipped (it shells out to `composer licenses`/`npx license-report`); the config
license tab falls back to the copied `LICENSE` text.

Measured with warm dependency caches: no-cache build 145 s, cached rebuild 2.4 s,
PHP-file edit 6.2 s, view edit 7.6 s (re-runs gulp), deploy end-to-end 32 s.

## State and reset

Named volumes `db` (`/var/lib/mysql`), `uploads` (`/app/public/uploads`) and
`logs` (`/app/writable/logs`), all prefixed by the compose project. `reset` is
`docker compose down -v --remove-orphans`; the image is kept for content-addressed
reuse. Reset + deploy reproduces the same 46-migration baseline and the same
login because the keys are fixed.

## Caveats

- `composer install` warns that `composer.lock` is out of date with
  `composer.json` at this tag; it installs the locked versions, like the release
  CI does.
- `/items/search` returns 500 without bootstrap-table's `limit`/`sort`/`order`
  params and `{"total":0,"rows":[]}` with them; that is upstream behaviour.
- The item form validates both always-posted tax rows; with upstream's blank
  `default_tax_*` config every item save fails. The seed fills those defaults
  (see Seed data), which is ordinary store configuration, not a source change.
- `deploy` does not seed. Run `./tester-env seed` after it; `verify` fails with
  item counts of 0 until then.
- gulp rewrites three tracked views, but only inside the image build — the
  checked-out tree stays clean.
- Login throttle is per IP + username, so the deployment raises the capacity
  instead of disabling the filter.
