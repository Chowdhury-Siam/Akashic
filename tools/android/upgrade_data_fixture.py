#!/usr/bin/env python3
"""Seed and verify a deterministic finance dataset for Android in-place upgrade CI.

The fixture is inserted into a database created by the *previous published app*.
After installing the new APK over that app, the same script verifies that every
sentinel row and important value survived startup/migration unchanged.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sqlite3
import sys

NOW = 1760000000000
FUTURE = 1900000000000
EXPECTED = {
    "accounts": {
        "upgrade-account-cash": {"name": "Upgrade Cash", "amount": 4321.25, "type": "regular"},
        "upgrade-account-bank": {"name": "Upgrade Bank", "amount": 9876.5, "type": "regular"},
    },
    "categories": {
        "upgrade-category-expense": {"name": "Upgrade Expense", "type": "expense"},
        "upgrade-category-income": {"name": "Upgrade Income", "type": "income"},
    },
    "transactions": {
        "upgrade-tx-expense": {"type": "expense", "amount": 123.45, "title": "Upgrade Expense Transaction", "notes": "must survive update"},
        "upgrade-tx-income": {"type": "income", "amount": 999.99, "title": "Upgrade Income Transaction", "notes": "must survive update"},
        "upgrade-tx-transfer": {"type": "transfer", "amount": 50.0, "title": "Upgrade Transfer", "notes": "must survive update"},
    },
    "budgets": {"upgrade-budget": {"amount": 777.0, "selected_month": "2026-10"}},
    "planned_purchases": {"upgrade-plan": {"name": "Upgrade Laptop", "amount": 1500.0}},
    "notes": {"upgrade-note": {"title": "Upgrade sentinel note", "body": "This note must survive an in-place Android update."}},
    "subscriptions": {"upgrade-subscription": {"name": "Upgrade Subscription", "amount": 19.99}},
    "loan_contacts": {"upgrade-contact": {"name": "Upgrade Contact"}},
    "loans": {"upgrade-loan": {"principal": 1200.0, "direction": "lent", "note": "upgrade sentinel loan"}},
    "loan_payments": {"upgrade-loan-payment": {"amount": 200.0, "note": "upgrade sentinel repayment"}},
    "sync_outbox": {"upgrade-sync-operation": {"entity_type": "transactions", "entity_id": "upgrade-tx-expense", "operation": "upsert"}},
    "sync_state": {"upgradeSentinel": {"value": "keep-me"}},
}


def columns(db: sqlite3.Connection, table: str) -> set[str]:
    return {row[1] for row in db.execute(f"PRAGMA table_info({table})")}


def tables(db: sqlite3.Connection) -> set[str]:
    return {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def insert(db: sqlite3.Connection, table: str, values: dict[str, object]) -> None:
    cols = columns(db, table)
    filtered = {k: v for k, v in values.items() if k in cols}
    if not filtered:
        raise RuntimeError(f"No compatible fixture columns for {table}")
    names = ", ".join(filtered)
    marks = ", ".join("?" for _ in filtered)
    db.execute(f"INSERT OR REPLACE INTO {table} ({names}) VALUES ({marks})", tuple(filtered.values()))


def seed(path: pathlib.Path, manifest: pathlib.Path | None) -> None:
    db = sqlite3.connect(path)
    try:
        db.execute("PRAGMA foreign_keys=OFF")
        available = tables(db)
        required = set(EXPECTED)
        missing = sorted(required - available)
        if missing:
            raise RuntimeError(f"Previous app database is missing required finance tables: {missing}")

        insert(db, "accounts", {"id":"upgrade-account-cash","name":"Upgrade Cash","type":"regular","icon_name":"wallet","icon_color":"#00BD91","amount":4321.25,"credit_limit":0.0,"sequence":0,"created_on":NOW,"updated_on":NOW})
        insert(db, "accounts", {"id":"upgrade-account-bank","name":"Upgrade Bank","type":"regular","icon_name":"bank","icon_color":"#27C6A0","amount":9876.5,"credit_limit":0.0,"sequence":1,"created_on":NOW,"updated_on":NOW})
        insert(db, "categories", {"id":"upgrade-category-expense","name":"Upgrade Expense","type":"expense","icon_name":"food","icon_color":"#FBC879","created_on":NOW,"updated_on":NOW})
        insert(db, "categories", {"id":"upgrade-category-income","name":"Upgrade Income","type":"income","icon_name":"salary","icon_color":"#A6E3A1","created_on":NOW,"updated_on":NOW})
        common_tx = {"base_amount":0.0,"service_charge_enabled":0,"service_charge_mode":"number","service_charge_value":0.0,"service_charge_amount":0.0,"image_path":"","exclude_from_reports":0,"created_on":NOW,"updated_on":NOW}
        insert(db, "transactions", {**common_tx,"id":"upgrade-tx-expense","type":"expense","amount":123.45,"base_amount":123.45,"title":"Upgrade Expense Transaction","notes":"must survive update","category_id":"upgrade-category-expense","from_account_id":"upgrade-account-cash","to_account_id":None})
        insert(db, "transactions", {**common_tx,"id":"upgrade-tx-income","type":"income","amount":999.99,"base_amount":999.99,"title":"Upgrade Income Transaction","notes":"must survive update","category_id":"upgrade-category-income","from_account_id":"upgrade-account-bank","to_account_id":None})
        insert(db, "transactions", {**common_tx,"id":"upgrade-tx-transfer","type":"transfer","amount":50.0,"base_amount":50.0,"title":"Upgrade Transfer","notes":"must survive update","category_id":"","from_account_id":"upgrade-account-cash","to_account_id":"upgrade-account-bank"})
        insert(db, "budgets", {"id":"upgrade-budget","selected_month":"2026-10","amount":777.0,"all_accounts_selected":0,"all_categories_selected":0,"created_on":NOW,"updated_on":NOW})
        insert(db, "budget_accounts", {"budget_id":"upgrade-budget","account_id":"upgrade-account-cash"})
        insert(db, "budget_categories", {"budget_id":"upgrade-budget","category_id":"upgrade-category-expense"})
        insert(db, "planned_purchases", {"id":"upgrade-plan","name":"Upgrade Laptop","amount":1500.0,"category_id":"upgrade-category-expense","reminder_on":FUTURE,"created_on":NOW,"updated_on":NOW})
        insert(db, "notes", {"id":"upgrade-note","title":"Upgrade sentinel note","body":"This note must survive an in-place Android update.","bookmarked":1,"draft":0,"created_on":NOW,"updated_on":NOW})
        insert(db, "subscriptions", {"id":"upgrade-subscription","name":"Upgrade Subscription","amount":19.99,"category_id":"upgrade-category-expense","account_id":"upgrade-account-cash","next_due_on":FUTURE,"frequency":"monthly","notes":"upgrade sentinel subscription","auto_pay":1,"last_processed_on":None,"created_on":NOW,"updated_on":NOW})
        insert(db, "loan_contacts", {"id":"upgrade-contact","name":"Upgrade Contact","phone":"0123456789","note":"upgrade sentinel contact","icon_name":"exchange","icon_color":"#FBC879","archived":0,"created_on":NOW,"updated_on":NOW})
        insert(db, "loans", {"id":"upgrade-loan","contact_id":"upgrade-contact","direction":"lent","principal":1200.0,"interest_type":"simple","interest_rate":5.0,"interest_period":"yearly","start_date":NOW,"due_date":NOW + 2592000000,"installment_count":6,"interest_accrual_stop":"settled","note":"upgrade sentinel loan","status":"active","closed_on":None,"disbursal_transaction_id":None,"created_on":NOW,"updated_on":NOW})
        insert(db, "loan_payments", {"id":"upgrade-loan-payment","loan_id":"upgrade-loan","amount":200.0,"interest_component":10.0,"principal_component":190.0,"paid_on":NOW + 86400000,"note":"upgrade sentinel repayment","transaction_id":None,"created_on":NOW,"updated_on":NOW})
        insert(db, "sync_outbox", {"id":"upgrade-sync-operation","entity_type":"transactions","entity_id":"upgrade-tx-expense","operation":"upsert","payload_json":"{\"sentinel\":true}","base_version":7,"created_at":NOW,"attempt_count":2,"last_attempt_at":NOW,"last_error":"offline-upgrade-sentinel"})
        insert(db, "sync_state", {"key":"upgradeSentinel","value":"keep-me"})

        old_user_version = db.execute("PRAGMA user_version").fetchone()[0]
        db.commit()
        integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise RuntimeError(f"Seed database integrity_check failed: {integrity}")
        # Collapse any WAL content into the main file so adb only needs one file.
        try:
            db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
            db.execute("PRAGMA journal_mode=DELETE")
        except sqlite3.DatabaseError:
            pass
        db.commit()
        info = {"old_user_version": old_user_version, "sentinel_tables": sorted(EXPECTED)}
        if manifest:
            manifest.write_text(json.dumps(info, indent=2), encoding="utf-8")
        print(json.dumps(info))
    finally:
        db.close()


def assert_equal(actual: object, expected: object, label: str) -> None:
    if isinstance(expected, float):
        if actual is None or abs(float(actual) - expected) > 1e-6:
            raise RuntimeError(f"{label}: expected {expected!r}, got {actual!r}")
    elif actual != expected:
        raise RuntimeError(f"{label}: expected {expected!r}, got {actual!r}")


def verify(path: pathlib.Path, manifest: pathlib.Path | None) -> None:
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    try:
        integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise RuntimeError(f"Upgraded database integrity_check failed: {integrity}")
        available = tables(db)
        for table, rows in EXPECTED.items():
            if table not in available:
                raise RuntimeError(f"Upgraded database lost table {table}")
            key_col = "key" if table == "sync_state" else "id"
            for key, fields in rows.items():
                row = db.execute(f"SELECT * FROM {table} WHERE {key_col} = ?", (key,)).fetchone()
                if row is None:
                    raise RuntimeError(f"Data loss: {table}.{key_col}={key!r} disappeared during upgrade")
                present = set(row.keys())
                for field, expected in fields.items():
                    if field in present:
                        assert_equal(row[field], expected, f"{table}[{key}].{field}")

        # Relationship rows are important because losing them silently corrupts budgets.
        for table, where, args in (
            ("budget_accounts", "budget_id=? AND account_id=?", ("upgrade-budget", "upgrade-account-cash")),
            ("budget_categories", "budget_id=? AND category_id=?", ("upgrade-budget", "upgrade-category-expense")),
        ):
            if db.execute(f"SELECT COUNT(*) FROM {table} WHERE {where}", args).fetchone()[0] != 1:
                raise RuntimeError(f"Data loss: {table} relationship disappeared during upgrade")

        user_version = db.execute("PRAGMA user_version").fetchone()[0]
        if manifest and manifest.exists():
            old = json.loads(manifest.read_text(encoding="utf-8"))["old_user_version"]
            if user_version < int(old):
                raise RuntimeError(f"Database schema version regressed from {old} to {user_version}")
        print(f"[OK] Upgrade fixture preserved; SQLite user_version={user_version}, integrity_check=ok")
    finally:
        db.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("seed", "verify"):
        p = sub.add_parser(name)
        p.add_argument("--database", required=True, type=pathlib.Path)
        p.add_argument("--manifest", type=pathlib.Path)
    args = parser.parse_args()
    if not args.database.is_file():
        raise RuntimeError(f"Database not found: {args.database}")
    if args.command == "seed":
        seed(args.database, args.manifest)
    else:
        verify(args.database, args.manifest)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"::error::Android upgrade data-loss fixture failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
