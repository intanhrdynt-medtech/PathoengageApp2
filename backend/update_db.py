import os
from flask import Flask
from models import db
from dotenv import load_dotenv

# Load production env vars if available, else local
load_dotenv('.env.production', override=True)
load_dotenv('.env', override=False)

SUPABASE_DB_URL = 'postgresql://postgres.xlhajqkmemzirwhafdnc:pathoengage123@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres'
db_url = os.getenv('DATABASE_URL') or SUPABASE_DB_URL
if db_url and db_url.startswith('postgres://'):
    db_url = 'postgresql://' + db_url[len('postgres://'):]

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = db_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)

from sqlalchemy import text

def update_db():
    with app.app_context():
        # This will create any missing tables based on models.py
        # Existing tables will NOT be dropped
        db.create_all()
        print("[SUCCESS] Database update completed! New tables created successfully.")

        # Ensure new columns on existing 'user' table exist
        alter_statements = [
            'ALTER TABLE "user" ADD COLUMN IF NOT EXISTS angkatan VARCHAR(10);',
            'ALTER TABLE "user" ADD COLUMN IF NOT EXISTS dosen_wali VARCHAR(200);',
            'ALTER TABLE "user" ADD COLUMN IF NOT EXISTS pembimbing_1 VARCHAR(200);',
            'ALTER TABLE "user" ADD COLUMN IF NOT EXISTS pembimbing_2 VARCHAR(200);',
            'ALTER TABLE "user" ADD COLUMN IF NOT EXISTS pembimbing_retrospektif VARCHAR(200);',
            'ALTER TABLE "user" ADD COLUMN IF NOT EXISTS warning_active BOOLEAN DEFAULT FALSE;',
            'ALTER TABLE "user" ADD COLUMN IF NOT EXISTS warning_message TEXT;',
        ]
        with db.engine.connect() as conn:
            for stmt in alter_statements:
                try:
                    conn.execute(text(stmt))
                except Exception as e:
                    print(f"Error executing {stmt}: {e}")
            conn.commit()
        print("[SUCCESS] User table columns updated successfully.")

if __name__ == '__main__':
    if not db_url:
        print("[WARNING] DATABASE_URL not found. Running on sqlite:///local.db")
    else:
        print(f"Connecting to database: {db_url[:30]}...")
    
    update_db()
