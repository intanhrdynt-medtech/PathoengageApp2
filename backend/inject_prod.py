"""
Script to inject 8 textbook tasks directly to production database via Vercel env.
Run: python inject_prod.py
"""
import os
import sys
from dotenv import load_dotenv

# Load production env vars
load_dotenv('.env.production', override=True)

db_url = os.getenv('DATABASE_URL')
print(f"DB URL starts with: {db_url[:30] if db_url else 'NOT FOUND'}")

if not db_url:
    print("ERROR: DATABASE_URL not found in .env.production")
    sys.exit(1)

# Fix postgres:// -> postgresql:// for SQLAlchemy
if db_url.startswith('postgres://'):
    db_url = 'postgresql://' + db_url[len('postgres://'):]

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from models import db, User, AcademicTask

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = db_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)

books = [
    {
      'title': 'Classification of Tumor',
      'url': 'https://tumourclassification.iarc.who.int/home',
    },
    {
      'title': 'Pathologic Basic of Disease',
      'url': 'https://shop.elsevier.com/books/robbins-cotran-and-kumar-pathologic-basis-of-disease/kumar/978-0-443-26452-',
    },
    {
      'title': 'Basic Pathology',
      'url': 'https://shop.elsevier.com/books/robbins-and-kumar-basic-pathology/kumar/978-0-323-79018-5',
    },
    {
      'title': "Enzinger and Weiss's Soft Tissue Tumors",
      'url': 'https://shop.elsevier.com/books/enzinger-and-weisss-soft-tissue-tumors/goldblum/978-0-323-61096-4',
    },
    {
      'title': "Cibas and Ducatman's Cytology",
      'url': 'https://shop.elsevier.com/books/cibas-and-ducatman-s-cytology/cibas/978-0-323-93434-3',
    },
    {
      'title': 'Pathology',
      'url': 'https://innocentbalti.wordpress.com/wp-content/uploads/2015/01/harsh-mohan-textbook-of-pathology-6th-ed.pdf',
    },
    {
      'title': "Silva's Diagnostic Renal Pathology",
      'url': 'https://www.amazon.com/Silvas-Diagnostic-Renal-Pathology-Joseph/dp/1316613984',
    },
    {
      'title': "Weedon's Skin Pathology",
      'url': 'https://www.sciencedirect.com/book/monograph/9780702034855/weedons-skin-pathology',
    },
]

with app.app_context():
    users = User.query.filter_by(role='ppds').all()
    print(f"Found {len(users)} PPDS users: {[u.email for u in users]}")
    
    count = 0
    for u in users:
        for b in books:
            existing = AcademicTask.query.filter_by(
                user_id=u.id, task_type='Textbook Reading', title=b['title']
            ).first()
            if not existing:
                task = AcademicTask(
                    user_id=u.id,
                    task_type='Textbook Reading',
                    title=b['title'],
                    description='Tugas membaca buku teks',
                    target_semester=u.current_semester or 1,
                    is_completed=False,
                    status='not_started',
                    link_url=b['url']
                )
                db.session.add(task)
                count += 1
                print(f"  Adding: {b['title']} for {u.email}")
            else:
                print(f"  Skipping (exists): {b['title']} for {u.email}")
    
    db.session.commit()
    print(f"\nDone. Inserted {count} new Textbook Reading tasks.")
    
    # Verify
    all_textbooks = AcademicTask.query.filter_by(task_type='Textbook Reading').all()
    print(f"Total Textbook Reading tasks in DB: {len(all_textbooks)}")
    for t in all_textbooks:
        print(f"  - {t.title} (user {t.user_id})")
