// In-memory stand-in for the supabase-js client, covering only the query-builder calls
// the handlers make, so whole sessions can be driven through the real handler code
// without a database. Primary keys and column defaults mirror the migration.
// deno-lint-ignore-file no-explicit-any

type Row = Record<string, any>;

const PK: Record<string, string[]> = {
  profiles: ["id"], sessions: ["id"], responses: ["session_id", "seq"], section_scores: ["session_id", "sec"],
  blitz_best: ["user_id", "scope", "dur_s", "season"], daily: ["user_id", "day"], duels: ["code"],
  duel_results: ["code", "user_id"], certificates: ["token"],
};
const DEFAULTS: Record<string, () => Row> = {
  profiles: () => ({ minor: false, lang: "es", created_at: new Date().toISOString() }),
  sessions: () => ({ id: crypto.randomUUID(), kind: "normal", status: "live", flags: {}, result: null, state: {}, started_at: new Date().toISOString() }),
  section_scores: () => ({ created_at: new Date().toISOString() }),
};

function get(row: Row, col: string) {
  const m = col.match(/^(\w+)->>(\w+)$/);
  if (m) { const v = row[m[1]]?.[m[2]]; return v == null ? null : String(v); }
  return row[col];
}

class Query implements PromiseLike<{ data: any; error: any }> {
  private filters: ((r: Row) => boolean)[] = [];
  private op: "select" | "insert" | "update" | "upsert" = "select";
  private payload: Row[] = [];
  private patch: Row = {};
  private returning = false;
  private one = false;
  private max = Infinity;
  private sort: [string, boolean] | null = null;
  private upsertOpts: { onConflict?: string; ignoreDuplicates?: boolean } = {};

  constructor(private db: FakeDb, private table: string) {}

  select(_cols?: string) { if (this.op !== "select") this.returning = true; return this; }
  insert(rows: Row | Row[]) { this.op = "insert"; this.payload = Array.isArray(rows) ? rows : [rows]; return this; }
  upsert(rows: Row | Row[], opts: { onConflict?: string; ignoreDuplicates?: boolean } = {}) { this.op = "upsert"; this.payload = Array.isArray(rows) ? rows : [rows]; this.upsertOpts = opts; return this; }
  update(patch: Row) { this.op = "update"; this.patch = patch; return this; }
  eq(c: string, v: any) { this.filters.push((r) => get(r, c) === v); return this; }
  is(c: string, v: null) { this.filters.push((r) => (r[c] ?? null) === v); return this; }
  not(c: string, op: string, v: null) { if (op !== "is") throw new Error("fake: not() only supports is"); this.filters.push((r) => (r[c] ?? null) !== v); return this; }
  in(c: string, vs: any[]) { this.filters.push((r) => vs.includes(r[c])); return this; }
  gte(c: string, v: any) { this.filters.push((r) => r[c] >= v); return this; }
  order(c: string, o: { ascending?: boolean } = {}) { this.sort = [c, o.ascending !== false]; return this; }
  limit(n: number) { this.max = n; return this; }
  single() { this.one = true; return this; }

  private rows() { return (this.db.tables[this.table] ??= []); }
  private key(r: Row, cols: string[]) { return cols.map((c) => JSON.stringify(r[c])).join("|"); }

  private run(): any {
    const t = this.rows();
    if (this.op === "insert" || this.op === "upsert") {
      const pk = this.upsertOpts.onConflict?.split(",") ?? PK[this.table];
      const out: Row[] = [];
      for (const p of this.payload) {
        const row = { ...(DEFAULTS[this.table]?.() ?? {}), ...structuredClone(p) };
        const i = t.findIndex((x) => this.key(x, pk) === this.key(row, pk));
        if (i >= 0) {
          if (this.op === "insert") throw { message: `duplicate key in ${this.table}`, code: "23505" };
          if (this.upsertOpts.ignoreDuplicates) continue;
          t[i] = { ...t[i], ...structuredClone(p) };
          out.push(t[i]);
        } else { t.push(row); out.push(row); }
      }
      return out;
    }
    let rows = t.filter((r) => this.filters.every((f) => f(r)));
    if (this.op === "update") { for (const r of rows) Object.assign(r, structuredClone(this.patch)); return rows; }
    if (this.sort) { const [c, asc] = this.sort; rows = rows.slice().sort((a, b) => (a[c] < b[c] ? -1 : a[c] > b[c] ? 1 : 0) * (asc ? 1 : -1)); }
    return rows.slice(0, this.max);
  }

  then<A, B>(ok?: (v: { data: any; error: any }) => A | PromiseLike<A>, bad?: (e: any) => B | PromiseLike<B>): PromiseLike<A | B> {
    let res: { data: any; error: any };
    try {
      let data = this.run();
      if (this.op !== "select" && !this.returning) data = null;
      else data = structuredClone(data);
      if (this.one) {
        if (!data || data.length !== 1) res = { data: null, error: { message: `single() got ${data?.length ?? 0} rows` } };
        else res = { data: data[0], error: null };
      } else res = { data, error: null };
    } catch (e) { res = { data: null, error: e }; }
    return Promise.resolve(res).then(ok, bad);
  }
}

export class FakeDb {
  tables: Record<string, Row[]> = {};
  from(table: string) { return new Query(this, table); }
}
