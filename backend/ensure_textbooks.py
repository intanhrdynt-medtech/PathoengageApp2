from app import app, db, User, AcademicTask

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
        'title': 'Cibas and Ducatman\u2019s Cytology',
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
    # Ensure live DB config from inject script (keeps same behavior)
    app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres.xlhajqkmemzirwhafdnc:pathoengage123@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres'
    db.engine.dispose()

    users = User.query.filter_by(role='ppds').all()
    if not users:
        print('No ppds users found')

    total_added = 0
    for u in users:
        added_for_user = 0
        for b in books:
            existing = AcademicTask.query.filter_by(user_id=u.id, task_type='Textbook Reading', title=b['title']).first()
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
                added_for_user += 1
                total_added += 1
        if added_for_user > 0:
            print(f'Added {added_for_user} textbooks for user {u.email} (id={u.id})')
    db.session.commit()
    print(f'Total added: {total_added}')
