import sqlite3
import os
import sys

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    db_path = os.path.normpath(os.path.join(script_dir, '..', 'app', 'db', 'fixmate.db'))
    print(f"Using database: {db_path}")
    if not os.path.exists(db_path):
        print(f"DB not found: {db_path}")
        return 2

    conn = sqlite3.connect(db_path)
    try:
        cur = conn.cursor()
        cur.execute("PRAGMA table_info(tickets);")
        cols = [row[1] for row in cur.fetchall()]
        if 'address' in cols:
            print("Column 'address' already exists")
            return 0

        cur.execute("ALTER TABLE tickets ADD COLUMN address TEXT;")
        conn.commit()
        print("Added 'address' column to 'tickets' table")
        return 0
    except Exception as e:
        print("Failed to add 'address' column:", e)
        return 1
    finally:
        conn.close()

if __name__ == '__main__':
    sys.exit(main())