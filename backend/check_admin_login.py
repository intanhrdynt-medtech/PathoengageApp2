from app import app, db
from models import User
from werkzeug.security import check_password_hash

EMAIL = 'admin2@pathoengage.com'
PASSWORD = 'admin1234'

with app.app_context():
    app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres.xlhajqkmemzirwhafdnc:pathoengage123@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres'
    db.engine.dispose()

    user = User.query.filter_by(email=EMAIL).first()
    if not user:
        print('User not found')
    else:
        ok = check_password_hash(user.password_hash, PASSWORD)
        print('Found user id=', user.id, 'role=', user.role)
        print('Password match:', ok)
