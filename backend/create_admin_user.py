from app import app, db
from models import User
from werkzeug.security import generate_password_hash

EMAIL = 'admin2@pathoengage.com'
PASSWORD = 'admin1234'
FULL_NAME = 'Admin 2'

with app.app_context():
    app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres.xlhajqkmemzirwhafdnc:pathoengage123@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres'
    db.engine.dispose()

    existing = User.query.filter_by(email=EMAIL).first()
    if existing:
        print(f"User {EMAIL} already exists (id={existing.id})")
    else:
        user = User(
            email=EMAIL,
            password_hash=generate_password_hash(PASSWORD),
            full_name=FULL_NAME,
            nim='-',
            role='admin',
        )
        db.session.add(user)
        db.session.commit()
        print(f"Created admin user {EMAIL} with id={user.id}")
