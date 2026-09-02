from app import app, db
from models import User
from werkzeug.security import generate_password_hash

NEW_PASSWORD = 'admin1234'

with app.app_context():
    # target the live DB same as other scripts
    app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres.xlhajqkmemzirwhafdnc:pathoengage123@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres'
    db.engine.dispose()

    user = User.query.filter_by(email='admin@pathoengage.com').first()
    if not user:
        print('Admin user not found')
    else:
        user.password_hash = generate_password_hash(NEW_PASSWORD)
        db.session.commit()
        print(f"Password for {user.email} updated to '{NEW_PASSWORD}'")
