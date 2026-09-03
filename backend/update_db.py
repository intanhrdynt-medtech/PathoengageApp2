import os
from flask import Flask
from models import db
from dotenv import load_dotenv

# Load production env vars if available, else local
load_dotenv('.env.production', override=True)
load_dotenv('.env', override=False)

db_url = os.getenv('DATABASE_URL')
if db_url and db_url.startswith('postgres://'):
    db_url = 'postgresql://' + db_url[len('postgres://'):]

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = db_url or 'sqlite:///local.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)

def update_db():
    with app.app_context():
        # This will create any missing tables based on models.py
        # Existing tables will NOT be dropped
        db.create_all()
        print("✅ Database update completed! New tables created successfully.")

if __name__ == '__main__':
    if not db_url:
        print("⚠️ Warning: DATABASE_URL not found. Running on sqlite:///local.db")
    else:
        print(f"Connecting to database: {db_url[:30]}...")
    
    update_db()
