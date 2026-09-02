from app import app, db, User, AcademicTask

with app.app_context():
    app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres.xlhajqkmemzirwhafdnc:pathoengage123@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres'
    db.engine.dispose()
    
    users = User.query.all()
    print("Users:")
    for u in users:
        print(f" - {u.id}: {u.email} (role: {u.role})")
        
    tasks = AcademicTask.query.all()
    print(f"\nTasks (Total {len(tasks)}):")
    for t in tasks:
        print(f" - Task {t.id}: {t.title} (User {t.user_id})")
