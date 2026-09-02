from app import app
from models import db, User, AcademicTask

with app.app_context():
    users = User.query.filter_by(role='ppds').all()
    if not users:
        print('No ppds users found')
    for u in users:
        tasks = AcademicTask.query.filter_by(user_id=u.id, task_type='Textbook Reading').all()
        print(f'User: {u.id} {u.email} (semester: {u.current_semester})')
        print(f' Textbook count: {len(tasks)}')
        for t in tasks:
            print('  -', t.title)
