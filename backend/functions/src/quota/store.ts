/**
 * QuotaStore: persistence behind the quota module. Firestore in production
 * (quota/firestoreStore.ts), in-memory in unit tests (quota/memoryStore.ts). The quota logic
 * itself is pure (ledger.ts) and runs inside `runUserTx`, which must be atomic per user.
 *
 * Only counters, timestamps and idempotency keys are stored. Never financial data.
 */

import type { RateClass, TaskName } from "../config/tasks.js";

/** An in-flight call holding a concurrency slot and reserved credits. */
export interface Lease {
  id: string;
  kind: RateClass;
  task: TaskName;
  credits: number;
  /** Whether the reserved credits count toward the first-24h cap. */
  firstDay: boolean;
  expiresAt: number;
}

/** `usage/{uid}` */
export interface UsageDoc {
  /** UTC month "YYYY-MM" the counters below belong to. */
  period: string;
  /** Settled credits this period (in-flight reservations live in `leases`). */
  creditsUsed: number;
  /** Actual Claude cost this period in micro-USD (hidden cap). */
  costMicros: number;
  /** First AI request ever (epoch ms): starts the first-24h window. */
  firstSeenAt: number;
  /** Credits reserved or charged inside the first-24h window. */
  firstDayCredits: number;
  leases: Lease[];
  /** Request timestamps (epoch ms) inside the rate window, per class. */
  rate: Record<RateClass, number[]>;
  updatedAt: number;
}

export type IdemState = "pending" | "done" | "refunded";

/** `usage/{uid}/idem/{key}`: the key plus bookkeeping, never the request or response. */
export interface IdemRecord {
  task: TaskName;
  state: IdemState;
  replays: number;
  createdAt: number;
  /** While pending: when the call is considered abandoned (its lease expiry). */
  pendingUntil: number;
  /** TTL: the key is forgotten after this time. */
  expiresAt: number;
}

export interface UserTxState {
  usage: UsageDoc | null;
  idem: IdemRecord | null;
}

export interface UserTxOutcome<T> {
  /** New usage doc to write (omit to leave unchanged). */
  usage?: UsageDoc;
  /** New idempotency record (omit to leave unchanged). */
  idem?: IdemRecord;
  result: T;
}

export interface QuotaStore {
  /**
   * Reads `usage/{uid}` (and `usage/{uid}/idem/{idemKey}` when given), runs `fn` and writes
   * its outcome atomically. `fn` must be pure: it may run more than once on contention. An
   * error thrown by `fn` aborts the transaction and is rethrown.
   */
  runUserTx<T>(uid: string, idemKey: string | null, fn: (state: UserTxState) => UserTxOutcome<T>): Promise<T>;
  readUsage(uid: string): Promise<UsageDoc | null>;
  /** Deletes the usage doc and every idempotency key of the user. */
  deleteUserData(uid: string): Promise<void>;
  /** Adds to today's global spend (sharded counter). */
  addDailySpend(day: string, micros: number): Promise<void>;
  readDailySpend(day: string): Promise<number>;
  /** Raw `config/ai` document (validated by the breaker), or null. */
  readAiConfig(): Promise<unknown>;
}
