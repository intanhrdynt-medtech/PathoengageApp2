import os
import datetime
from functools import wraps
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import jwt
from werkzeug.security import generate_password_hash, check_password_hash

from models import db, User, Reminder, CompetencyLog, Exam, AcademicTask, ExternalRotation

load_dotenv()
SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-ppds-pa-unair')
DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///./backend_data.db')

app = Flask(__name__)
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URL
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = SECRET_KEY

db.init_app(app)


# ── Helpers ──────────────────────────────────────────────────────────────────

def encode_token(user_id):
    payload = {
        'user_id': user_id,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(days=7)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm='HS256')


def decode_token(token):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        return payload.get('user_id')
    except Exception:
        return None


def auth_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.headers.get('Authorization', '')
        if not auth.startswith('Bearer '):
            return jsonify({'error': 'Missing token'}), 401
        token = auth.split(' ', 1)[1]
        user_id = decode_token(token)
        if not user_id:
            return jsonify({'error': 'Invalid or expired token'}), 401
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        request.user = user
        return f(*args, **kwargs)
    return decorated


def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.headers.get('Authorization', '')
        if not auth.startswith('Bearer '):
            return jsonify({'error': 'Missing token'}), 401
        token = auth.split(' ', 1)[1]
        user_id = decode_token(token)
        if not user_id:
            return jsonify({'error': 'Invalid or expired token'}), 401
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        if user.role != 'admin':
            return jsonify({'error': 'Admin access required'}), 403
        request.user = user
        return f(*args, **kwargs)
    return decorated


def user_dict(user):
    return {
        'id': user.id,
        'email': user.email,
        'full_name': user.full_name,
        'nim': user.nim,
        'phase': user.phase,
        'current_semester': user.current_semester,
        'role': user.role,
    }


# ── Inline Curriculum Assignment (no dynamic import needed) ──────────────────

def assign_standard_curriculum(user_id):
    competencies = [
        # Tahap Merah
        ('red', 'Metodologi Penelitian & Statistik', 'Dasar & Metodologi'),
        ('red', 'Imunologi Dasar', 'Dasar & Metodologi'),
        ('red', 'Epidemiologi Klinik', 'Dasar & Metodologi'),
        ('red', 'Farmakologi Klinik', 'Dasar & Metodologi'),
        ('red', 'Dasar Pertolongan Darurat', 'Dasar & Metodologi'),
        ('red', 'Biologi Molekuler', 'Dasar & Metodologi'),
        ('red', 'Filsafat Ilmu', 'Dasar & Metodologi'),
        ('red', 'Etika Hukum Kedokteran & Hubungan Antar Manusia', 'Dasar & Metodologi'),
        ('red', 'Metode Belajar Mengajar', 'Dasar & Metodologi'),
        ('red', 'Penulisan Karya Ilmiah', 'Dasar & Metodologi'),
        ('red', 'Teknik Laboratorium Histologi & Histokimia', 'Laboratorium Dasar'),
        ('red', 'Patologi Kepala & Leher', 'Sistem Organ'),
        ('red', 'Sitologi Aspiratif II', 'Sitologi'),
        ('red', 'Patologi Kulit', 'Sistem Organ'),
        ('red', 'Patologi Mediastinum & Kardiovaskuler', 'Sistem Organ'),
        ('red', 'Patologi Sistem Saraf & Mata', 'Sistem Organ'),
        ('red', 'Patologi Muskuloskeletal II', 'Sistem Organ'),
        ('red', 'Patologi Integrated II', 'Integrated'),
        ('red', 'Otopsi Klinik', 'Diagnostik Khusus'),
        ('red', 'Diagnostik Histopatologi', 'Diagnostik Khusus'),
        ('red', 'Diagnostik FNAB', 'Diagnostik Khusus'),
        # Tahap Kuning
        ('yellow', 'Teknik Sitologi & Teknik Potong Beku', 'Teknik Khusus'),
        ('yellow', 'Dasar Imunohistokimia & Patologi Molekuler', 'Patologi Molekuler'),
        ('yellow', 'Dasar Penelitian Bidang Patologi & Patologi Eksperimental', 'Metodologi'),
        ('yellow', 'Patologi Umum', 'Dasar Patologi'),
        ('yellow', 'Etika Dokter Spesialis Patologi', 'Etika & Profesi'),
        ('yellow', 'Dasar Patologi Organ', 'Sistem Organ'),
        ('yellow', 'Proposal Karya Akhir (Target Mandatori)', 'Akademik & Penelitian'),
        ('yellow', 'Diagnostik Imunohistokimia', 'Diagnostik Khusus'),
        # Tahap Hijau
        ('green', 'Patologi Genetalia Wanita I & II', 'Sistem Organ'),
        ('green', 'Patologi Payudara', 'Sistem Organ'),
        ('green', 'Patologi Sistem Respirasi', 'Sistem Organ'),
        ('green', 'Patologi Ginjal', 'Sistem Organ'),
        ('green', 'Patologi Saluran Cerna', 'Sistem Organ'),
        ('green', 'Patologi Endokrin', 'Sistem Organ'),
        ('green', 'Patologi Hepatobilier & Pankreas', 'Sistem Organ'),
        ('green', 'Patologi Saluran Kemih & Genitalia Pria', 'Sistem Organ'),
        ('green', 'Patologi Hematolimfoid', 'Sistem Organ'),
        ('green', 'Patologi Muskuloskeletal I', 'Sistem Organ'),
        ('green', 'Sitologi Exfoliatif', 'Sitologi'),
        ('green', 'Sitologi Aspiratif I', 'Sitologi'),
        ('green', 'Patologi Integrated I, II & III', 'Integrated'),
        ('green', 'Diagnostik Potong Beku', 'Diagnostik Khusus'),
        ('green', 'Pengelolaan Laboratorium PA', 'Manajemen'),
        ('green', 'Diagnostik PA Luar', 'Stase Luar'),
        ('green', 'Pendidikan Patologi Anatomi', 'Edukasi'),
        ('green', 'Karya Akhir & Publikasi Scopus', 'Akademik & Penelitian'),
    ]
    for phase, name, organ in competencies:
        db.session.add(CompetencyLog(
            user_id=user_id,
            phase_category=phase,
            competency_name=name,
            organ_system=organ,
            status='not_started',
        ))

    exams = [
        ('Ujian Organ I', 'Lokal', 'red', 'Syarat maju ke Ujian Lokal Tahap 1'),
        ('Ujian Lokal Tahap 1', 'Lokal', 'red', 'Diikuti saat transisi Kalung Merah ke Kuning'),
        ('Ujian Organ II', 'Lokal', 'yellow', 'Syarat maju ke Ujian Nasional Tahap 1 / Hijau'),
        ('Ujian Nasional Tahap 1', 'Nasional', 'yellow', 'Syarat: Wajib Lulus Ujian Lokal Tahap 1'),
        ('Ujian Lokal Tahap 2', 'Lokal', 'green', 'Diikuti di akhir masa Kalung Hijau'),
        ('Ujian Nasional Tahap 2', 'Nasional', 'green', 'Syarat: Lulus Ujian Lokal Tahap 2 & Punya LOA Publikasi Scopus'),
    ]
    for name, etype, phase, notes in exams:
        db.session.add(Exam(
            user_id=user_id,
            phase_category=phase,
            exam_name=name,
            exam_type=etype,
            result='terjadwal',
            notes=notes,
        ))

    tasks = [
        ('Textbook Reading', 'Robbins Basic Pathology', 'Wajib 1 Textbook Reading di Semester 1', 1, 'https://elsevier.com/books/robbins-basic-pathology'),
        ('Journal Reading', 'WHO Classification of Tumours', 'Wajib 1 Journal Reading di Semester 1', 1, 'https://publications.iarc.fr/'),
        ('Tugas Ilmiah', 'Case Report 1', 'Penyusunan laporan kasus', 1, None),
        ('Tugas Ilmiah', 'Case Report 2', 'Penyusunan laporan kasus', 1, None),
        ('Tugas Ilmiah', 'Tinjauan Pustaka / Referat', 'Penyusunan tinjauan pustaka', 1, None),
        ('Penelitian', 'Telaah Retrospektif', 'Harus memiliki ethical clearance jika menggunakan data klinis', 1, None),
        ('Journal Reading', 'Journal of Pathology', 'Review jurnal ilmiah tambahan', 1, 'https://pathsocjournals.onlinelibrary.wiley.com/journal/10969896'),
        ('Penelitian', 'Proposal Karya Akhir', 'Sering bergeser ke semester 5/6', 4, None),
        ('Etik', 'Pengajuan Persetujuan Etik (Ethical Clearance)', 'Wajib diajukan setelah proposal disetujui', 4, None),
        ('Penelitian', 'Karya Akhir Selesai', 'Wajib disubmit ke jurnal terakreditasi', 7, None),
        ('Publikasi', 'Dapatkan LOA Publikasi', 'Syarat mutlak mendaftar Ujian Nasional Tahap 2', 7, None),
        ('Publikasi', 'Publikasi Jurnal Terindeks Scopus', 'Syarat Mutlak Kelulusan Universitas', 8, None),
        ('Etik', 'Laporan Penutupan Etik (Tutup Etik)', 'Wajib dilakukan ke komite etik setelah naskah dipublikasikan', 8, None),
    ]
    for ttype, title, desc, sem, link in tasks:
        db.session.add(AcademicTask(
            user_id=user_id,
            task_type=ttype,
            title=title,
            description=desc,
            target_semester=sem,
            is_completed=False,
            status='not_started',
            link_url=link
        ))

    textbooks = [
        ('Classification of Tumor',          'https://tumourclassification.iarc.who.int/home'),
        ('Pathologic Basic of Disease',       'https://shop.elsevier.com/books/robbins-cotran-and-kumar-pathologic-basis-of-disease/kumar/978-0-443-26452-'),
        ('Basic Pathology',                   'https://shop.elsevier.com/books/robbins-and-kumar-basic-pathology/kumar/978-0-323-79018-5'),
        ("Enzinger and Weiss's Soft Tissue Tumors", 'https://shop.elsevier.com/books/enzinger-and-weisss-soft-tissue-tumors/goldblum/978-0-323-61096-4'),
        ("Cibas and Ducatman's Cytology",     'https://shop.elsevier.com/books/cibas-and-ducatman-s-cytology/cibas/978-0-323-93434-3'),
        ('Pathology',                         'https://innocentbalti.wordpress.com/wp-content/uploads/2015/01/harsh-mohan-textbook-of-pathology-6th-ed.pdf'),
        ("Silva's Diagnostic Renal Pathology",'https://www.amazon.com/Silvas-Diagnostic-Renal-Pathology-Joseph/dp/1316613984'),
        ("Weedon's Skin Pathology",           'https://www.sciencedirect.com/book/monograph/9780702034855/weedons-skin-pathology'),
    ]
    for title, link in textbooks:
        db.session.add(AcademicTask(
            user_id=user_id,
            task_type='Textbook Reading',
            title=title,
            description='Tugas membaca buku teks',
            target_semester=1,
            is_completed=False,
            status='not_started',
            link_url=link
        ))

    rotations = [
        ('RS Universitas Airlangga (RSUA)', 'Departemen Patologi Anatomi', 'Surabaya', 'Prof. Dr. Soemarsono, Sp.PA(K)'),
        ('RSUD Dr. Soetomo', 'Patologi Anatomi', 'Surabaya', 'Dr. Ratna Kusuma, Sp.PA'),
        ('RSPAL Dr. Ramelan', 'Lab Patologi', 'Surabaya', 'Dr. Adi Purnomo, Sp.PA'),
        ('RSUD Haji Surabaya', 'Patologi Anatomi', 'Surabaya', None),
    ]
    for hname, dept, city, sup in rotations:
        db.session.add(ExternalRotation(
            user_id=user_id,
            hospital_name=hname,
            department=dept,
            city=city,
            supervisor=sup,
            status='terjadwal',
        ))


# ── Auth ──────────────────────────────────────────────────────────────────────

@app.route('/')
def index():
    return jsonify({'status': 'success', 'message': 'PathoEngage API is running!'})

@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'app': 'PathoEngage PPDS PA UNAIR'})

@app.route('/seed')
def run_seed():
    try:
        db.drop_all()
        db.create_all()

        u = User(
            email='ppds@unair.ac.id',
            password_hash=generate_password_hash('password'),
            full_name='Dr. Budi Santoso',
            nim='012345678',
            current_semester=4,
            phase='yellow',
            role='ppds',
        )
        db.session.add(u)
        db.session.flush()
        assign_standard_curriculum(u.id)

        admin = User(
            email='admin@pathoengage.com',
            password_hash=generate_password_hash('admin123'),
            full_name='Admin PathoEngage',
            nim='-',
            role='admin',
        )
        db.session.add(admin)
        db.session.commit()
        return jsonify({'status': 'success', 'message': 'Database seeded!'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json() or {}
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        full_name = data.get('full_name', '').strip()
        nim = data.get('nim', '').strip()

        if not email or not password:
            return jsonify({'error': 'Email dan password wajib diisi'}), 400
        if len(password) < 6:
            return jsonify({'error': 'Password minimal 6 karakter'}), 400
        if User.query.filter_by(email=email).first():
            return jsonify({'error': 'Email sudah terdaftar'}), 400

        user = User(
            email=email,
            password_hash=generate_password_hash(password),
            full_name=full_name or email,
            nim=nim or '-',
        )
        db.session.add(user)
        db.session.flush()

        assign_standard_curriculum(user.id)
        db.session.commit()

        token = encode_token(user.id)
        return jsonify({'token': token, 'user': user_dict(user)}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': 'Registrasi gagal: ' + str(e)}), 500


@app.route('/login', methods=['POST'])
def login():
    data = request.get_json() or {}
    email = data.get('email', '').strip().lower()
    password = data.get('password', '').strip()

    if not email or not password:
        return jsonify({'error': 'Email dan password wajib diisi'}), 400

    user = User.query.filter_by(email=email).first()
    if not user or not check_password_hash(user.password_hash, password):
        return jsonify({'error': 'Email atau password salah'}), 401

    token = encode_token(user.id)
    return jsonify({'token': token, 'user': user_dict(user)})


@app.route('/me', methods=['GET'])
@auth_required
def me():
    return jsonify(user_dict(request.user))


# ── Competencies ──────────────────────────────────────────────────────────────

def comp_dict(c):
    return {
        'id': c.id,
        'phase_category': c.phase_category,
        'competency_name': c.competency_name,
        'organ_system': c.organ_system,
        'status': c.status,
        'evidence_url': c.evidence_url,
        'notes': c.notes,
        'completed_at': c.completed_at.isoformat() if c.completed_at else None,
    }


@app.route('/competencies', methods=['GET'])
@auth_required
def get_competencies():
    return jsonify([comp_dict(c) for c in request.user.competency_logs])


@app.route('/competencies/<int:cid>', methods=['PUT'])
@auth_required
def update_competency(cid):
    comp = CompetencyLog.query.filter_by(id=cid, user_id=request.user.id).first()
    if not comp:
        return jsonify({'error': 'Tidak ditemukan'}), 404
    data = request.get_json() or {}
    if 'status' in data:
        comp.status = data['status']
        comp.completed_at = datetime.datetime.utcnow() if comp.status == 'completed' else None
    if 'evidence_url' in data:
        comp.evidence_url = data['evidence_url']
    if 'notes' in data:
        comp.notes = data['notes']
    db.session.commit()
    return jsonify(comp_dict(comp))


# ── Exams ─────────────────────────────────────────────────────────────────────

def exam_dict(e):
    return {
        'id': e.id,
        'phase_category': e.phase_category,
        'exam_name': e.exam_name,
        'exam_type': e.exam_type,
        'scheduled_date': e.scheduled_date.isoformat() if e.scheduled_date else None,
        'result': e.result,
        'evidence_url': e.evidence_url,
        'score': e.score,
        'notes': e.notes,
    }


@app.route('/exams', methods=['GET'])
@auth_required
def get_exams():
    return jsonify([exam_dict(e) for e in request.user.exams])


@app.route('/exams/<int:eid>', methods=['PUT'])
@auth_required
def update_exam(eid):
    exam = Exam.query.filter_by(id=eid, user_id=request.user.id).first()
    if not exam:
        return jsonify({'error': 'Tidak ditemukan'}), 404
    data = request.get_json() or {}
    for field in ['result', 'score', 'notes', 'scheduled_date', 'evidence_url']:
        if field in data:
            setattr(exam, field, data[field])
    db.session.commit()
    return jsonify(exam_dict(exam))


# ── Academic Tasks ────────────────────────────────────────────────────────────

def task_dict(t):
    return {
        'id': t.id,
        'task_type': t.task_type,
        'title': t.title,
        'description': t.description,
        'target_semester': t.target_semester,
        'deadline': t.deadline.isoformat() if t.deadline else None,
        'is_completed': t.is_completed,
        'status': t.status,
        'document_proof_url': t.document_proof_url,
        'link_url': t.link_url,
        'notes': t.notes,
    }


@app.route('/academic-tasks', methods=['GET'])
@auth_required
def get_academic_tasks():
    return jsonify([task_dict(t) for t in request.user.academic_tasks])


@app.route('/academic-tasks/<int:tid>', methods=['PUT'])
@auth_required
def update_academic_task(tid):
    task = AcademicTask.query.filter_by(id=tid, user_id=request.user.id).first()
    if not task:
        return jsonify({'error': 'Tidak ditemukan'}), 404
    data = request.get_json() or {}
    for field in ['is_completed', 'status', 'document_proof_url', 'description', 'notes', 'link_url']:
        if field in data:
            setattr(task, field, data[field])
    db.session.commit()
    return jsonify(task_dict(task))


# ── External Rotations ────────────────────────────────────────────────────────

def rotation_dict(r):
    return {
        'id': r.id,
        'hospital_name': r.hospital_name,
        'department': r.department,
        'city': r.city,
        'supervisor': r.supervisor,
        'start_date': r.start_date.isoformat() if r.start_date else None,
        'end_date': r.end_date.isoformat() if r.end_date else None,
        'status': r.status,
        'notes': r.notes,
    }


@app.route('/rotations', methods=['GET'])
@auth_required
def get_rotations():
    return jsonify([rotation_dict(r) for r in request.user.external_rotations])


@app.route('/rotations/<int:rid>', methods=['PUT'])
@auth_required
def update_rotation(rid):
    rot = ExternalRotation.query.filter_by(id=rid, user_id=request.user.id).first()
    if not rot:
        return jsonify({'error': 'Tidak ditemukan'}), 404
    data = request.get_json() or {}
    for field in ['status', 'notes', 'supervisor', 'start_date', 'end_date', 'hospital_name', 'department', 'city']:
        if field in data:
            setattr(rot, field, data[field])
    db.session.commit()
    return jsonify(rotation_dict(rot))


# ── Reminders ─────────────────────────────────────────────────────────────────

@app.route('/reminders', methods=['GET', 'POST'])
@auth_required
def handle_reminders():
    user = request.user
    if request.method == 'GET':
        return jsonify([{
            'id': r.id, 'title': r.title, 'description': r.description,
            'time': r.time, 'completed': r.completed
        } for r in user.reminders])
    data = request.get_json() or {}
    if not data.get('title'):
        return jsonify({'error': 'title required'}), 400
    reminder = Reminder(user_id=user.id, title=data['title'],
                        description=data.get('description'), time=data.get('time'))
    db.session.add(reminder)
    db.session.commit()
    return jsonify({'id': reminder.id, 'title': reminder.title}), 201


@app.route('/reminders/<int:rid>', methods=['PUT', 'DELETE'])
@auth_required
def update_reminder(rid):
    reminder = Reminder.query.filter_by(id=rid, user_id=request.user.id).first()
    if not reminder:
        return jsonify({'error': 'not found'}), 404
    if request.method == 'DELETE':
        db.session.delete(reminder)
        db.session.commit()
        return jsonify({'deleted': rid})
    data = request.get_json() or {}
    reminder.title = data.get('title', reminder.title)
    reminder.description = data.get('description', reminder.description)
    reminder.time = data.get('time', reminder.time)
    if 'completed' in data:
        reminder.completed = data['completed']
    db.session.commit()
    return jsonify({'id': reminder.id, 'title': reminder.title, 'completed': reminder.completed})


# ── User Phase Update ─────────────────────────────────────────────────────────

@app.route('/me/phase', methods=['PUT'])
@auth_required
def update_phase():
    data = request.get_json() or {}
    phase = data.get('phase')
    if phase not in ('MKDU', 'red', 'yellow', 'green'):
        return jsonify({'error': "phase harus salah satu dari: MKDU, red, yellow, green"}), 400
    request.user.phase = phase
    db.session.commit()
    return jsonify(user_dict(request.user))


# ── Admin ───────────────────────────────────────────────────────────────────────

@app.route('/admin/users', methods=['GET'])
@admin_required
def get_users():
    users = User.query.filter(User.role != 'admin').all()
    return jsonify([user_dict(u) for u in users])


@app.route('/admin/users', methods=['POST'])
@admin_required
def create_user_by_admin():
    data = request.get_json() or {}
    email = data.get('email', '').strip().lower()
    password = data.get('password', '')
    full_name = data.get('full_name', '').strip()
    nim = data.get('nim', '').strip()
    role = data.get('role', 'ppds').strip()

    if not email or not password:
        return jsonify({'error': 'Email dan password wajib diisi'}), 400
    if len(password) < 6:
        return jsonify({'error': 'Password minimal 6 karakter'}), 400
    if User.query.filter_by(email=email).first():
        return jsonify({'error': 'Email sudah terdaftar'}), 400

    user = User(
        email=email,
        password_hash=generate_password_hash(password),
        full_name=full_name or email,
        nim=nim or '-',
        role=role,
    )
    db.session.add(user)
    db.session.flush()
    if role == 'ppds':
        assign_standard_curriculum(user.id)
    db.session.commit()
    return jsonify(user_dict(user)), 201


@app.route('/admin/users/<int:uid>', methods=['PUT'])
@admin_required
def update_user_by_admin(uid):
    user = User.query.get(uid)
    if not user:
        return jsonify({'error': 'User tidak ditemukan'}), 404
    data = request.get_json() or {}
    for field in ['full_name', 'nim', 'phase', 'current_semester']:
        if field in data:
            setattr(user, field, data[field])
    if 'password' in data and data['password']:
        user.password_hash = generate_password_hash(data['password'])
    db.session.commit()
    return jsonify(user_dict(user))


@app.route('/admin/users/<int:uid>', methods=['DELETE'])
@admin_required
def delete_user_by_admin(uid):
    user = User.query.get(uid)
    if not user:
        return jsonify({'error': 'User tidak ditemukan'}), 404
    db.session.delete(user)
    db.session.commit()
    return jsonify({'deleted': uid})


@app.route('/admin/pending_verifications', methods=['GET'])
@admin_required
def get_pending_verifications():
    pending_academic = AcademicTask.query.filter_by(status='pending_verification').all()
    pending_exams = Exam.query.filter_by(result='pending_verification').all()
    pending_comps = CompetencyLog.query.filter_by(status='pending_verification').all()

    def enrich_task(t):
        d = task_dict(t)
        d['user_name'] = t.user.full_name
        d['user_id'] = t.user_id
        d['type_category'] = 'academic'
        return d

    def enrich_exam(e):
        d = exam_dict(e)
        d['user_name'] = e.user.full_name
        d['user_id'] = e.user_id
        d['type_category'] = 'exam'
        return d

    def enrich_comp(c):
        d = comp_dict(c)
        d['user_name'] = c.user.full_name
        d['user_id'] = c.user_id
        d['type_category'] = 'competency'
        return d

    results = []
    results.extend([enrich_task(t) for t in pending_academic])
    results.extend([enrich_exam(e) for e in pending_exams])
    results.extend([enrich_comp(c) for c in pending_comps])

    return jsonify(results)


@app.route('/admin/verify/<type_category>/<int:item_id>', methods=['PUT'])
@admin_required
def verify_item(type_category, item_id):
    data = request.get_json() or {}
    action = data.get('action', 'approve')  # approve or reject

    if type_category == 'academic':
        item = AcademicTask.query.get(item_id)
        if not item:
            return jsonify({'error': 'Not found'}), 404
        item.status = 'completed' if action == 'approve' else 'not_started'
        if action == 'approve':
            item.is_completed = True
    elif type_category == 'exam':
        item = Exam.query.get(item_id)
        if not item:
            return jsonify({'error': 'Not found'}), 404
        item.result = 'lulus' if action == 'approve' else 'tidak_lulus'
    elif type_category == 'competency':
        item = CompetencyLog.query.get(item_id)
        if not item:
            return jsonify({'error': 'Not found'}), 404
        item.status = 'completed' if action == 'approve' else 'not_started'
        if action == 'approve':
            item.completed_at = datetime.datetime.utcnow()
    else:
        return jsonify({'error': 'Invalid category'}), 400

    db.session.commit()
    return jsonify({'success': True, 'id': item_id, 'type_category': type_category})


@app.route('/admin/progress/<int:uid>', methods=['GET'])
@admin_required
def get_user_progress(uid):
    user = User.query.get(uid)
    if not user:
        return jsonify({'error': 'User tidak ditemukan'}), 404

    competencies = user.competency_logs
    exams = user.exams
    tasks = user.academic_tasks
    rotations = user.external_rotations

    total_comp = len(competencies)
    done_comp = sum(1 for c in competencies if c.status == 'completed')
    pending_comp = sum(1 for c in competencies if c.status == 'pending_verification')

    total_exam = len(exams)
    passed_exam = sum(1 for e in exams if e.result == 'lulus')

    total_task = len(tasks)
    done_task = sum(1 for t in tasks if t.is_completed)
    pending_task = sum(1 for t in tasks if t.status == 'pending_verification')

    total_rot = len(rotations)
    done_rot = sum(1 for r in rotations if r.status == 'selesai')

    return jsonify({
        'user': user_dict(user),
        'competencies': {
            'total': total_comp,
            'completed': done_comp,
            'pending': pending_comp,
            'not_started': total_comp - done_comp - pending_comp,
            'items': [comp_dict(c) for c in competencies],
        },
        'exams': {
            'total': total_exam,
            'passed': passed_exam,
            'items': [exam_dict(e) for e in exams],
        },
        'academic_tasks': {
            'total': total_task,
            'completed': done_task,
            'pending': pending_task,
            'items': [task_dict(t) for t in tasks],
        },
        'rotations': {
            'total': total_rot,
            'completed': done_rot,
            'items': [rotation_dict(r) for r in rotations],
        },
    })


@app.route('/admin/academic-tasks', methods=['POST'])
@admin_required
def admin_add_task():
    data = request.get_json() or {}
    user_id = data.get('user_id')
    if not user_id:
        return jsonify({'error': 'user_id wajib diisi'}), 400
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User tidak ditemukan'}), 404

    task = AcademicTask(
        user_id=user_id,
        task_type=data.get('task_type', 'Tugas Ilmiah'),
        title=data.get('title', ''),
        description=data.get('description', ''),
        target_semester=data.get('target_semester'),
        deadline=datetime.datetime.fromisoformat(data['deadline']) if data.get('deadline') else None,
        status='not_started',
        is_completed=False,
        link_url=data.get('link_url'),
        notes=data.get('notes'),
    )
    db.session.add(task)
    db.session.commit()
    return jsonify(task_dict(task)), 201


@app.route('/admin/academic-tasks/<int:tid>', methods=['PUT'])
@admin_required
def admin_update_academic_task(tid):
    task = AcademicTask.query.get(tid)
    if not task:
        return jsonify({'error': 'Tugas tidak ditemukan'}), 404

    data = request.get_json() or {}
    for field in ['task_type', 'title', 'description', 'target_semester', 'deadline', 'status', 'is_completed', 'document_proof_url', 'link_url', 'notes']:
        if field not in data:
            continue
        value = data[field]
        if field == 'deadline' and value:
            value = datetime.datetime.fromisoformat(value)
        setattr(task, field, value)

    db.session.commit()
    return jsonify(task_dict(task))


@app.route('/admin/rotations/<int:rid>', methods=['PUT'])
@admin_required
def admin_update_rotation(rid):
    rot = ExternalRotation.query.get(rid)
    if not rot:
        return jsonify({'error': 'Tidak ditemukan'}), 404
    data = request.get_json() or {}
    for field in ['status', 'notes', 'supervisor', 'start_date', 'end_date', 'hospital_name', 'department', 'city']:
        if field in data:
            if field in ('start_date', 'end_date') and data[field]:
                setattr(rot, field, datetime.datetime.fromisoformat(data[field]))
            else:
                setattr(rot, field, data[field])
    db.session.commit()
    return jsonify(rotation_dict(rot))


@app.route('/admin/rotations', methods=['POST'])
@admin_required
def admin_add_rotation():
    data = request.get_json() or {}
    user_id = data.get('user_id')
    if not user_id:
        return jsonify({'error': 'user_id wajib diisi'}), 400

    rot = ExternalRotation(
        user_id=user_id,
        hospital_name=data.get('hospital_name', ''),
        department=data.get('department', ''),
        city=data.get('city', ''),
        supervisor=data.get('supervisor'),
        start_date=datetime.datetime.fromisoformat(data['start_date']) if data.get('start_date') else None,
        end_date=datetime.datetime.fromisoformat(data['end_date']) if data.get('end_date') else None,
        status=data.get('status', 'terjadwal'),
        notes=data.get('notes'),
    )
    db.session.add(rot)
    db.session.commit()
    return jsonify(rotation_dict(rot)), 201


@app.route('/admin/seed-textbooks', methods=['POST'])
def seed_textbooks():
    # One-time endpoint protected by a secret key
    data = request.get_json() or {}
    if data.get('secret') != 'pathoengage-seed-2026':
        return jsonify({'error': 'Unauthorized'}), 403

    books = [
        {'title': 'Classification of Tumor',
         'url': 'https://tumourclassification.iarc.who.int/home'},
        {'title': 'Pathologic Basic of Disease',
         'url': 'https://shop.elsevier.com/books/robbins-cotran-and-kumar-pathologic-basis-of-disease/kumar/978-0-443-26452-'},
        {'title': 'Basic Pathology',
         'url': 'https://shop.elsevier.com/books/robbins-and-kumar-basic-pathology/kumar/978-0-323-79018-5'},
        {'title': "Enzinger and Weiss's Soft Tissue Tumors",
         'url': 'https://shop.elsevier.com/books/enzinger-and-weisss-soft-tissue-tumors/goldblum/978-0-323-61096-4'},
        {'title': "Cibas and Ducatman's Cytology",
         'url': 'https://shop.elsevier.com/books/cibas-and-ducatman-s-cytology/cibas/978-0-323-93434-3'},
        {'title': 'Pathology',
         'url': 'https://innocentbalti.wordpress.com/wp-content/uploads/2015/01/harsh-mohan-textbook-of-pathology-6th-ed.pdf'},
        {'title': "Silva's Diagnostic Renal Pathology",
         'url': 'https://www.amazon.com/Silvas-Diagnostic-Renal-Pathology-Joseph/dp/1316613984'},
        {'title': "Weedon's Skin Pathology",
         'url': 'https://www.sciencedirect.com/book/monograph/9780702034855/weedons-skin-pathology'},
    ]

    users = User.query.filter_by(role='ppds').all()
    count = 0
    skipped = 0
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
            else:
                skipped += 1
    db.session.commit()
    return jsonify({'inserted': count, 'skipped': skipped, 'users': [u.email for u in users]}), 200


@app.route('/admin/seed-admin', methods=['POST'])
def seed_admin():
    data = request.get_json() or {}
    if data.get('secret') != 'pathoengage-seed-2026':
        return jsonify({'error': 'Unauthorized'}), 403
    email = data.get('email', 'admin@pathoengage.com')
    password = data.get('password', 'admin123')
    existing = User.query.filter_by(email=email).first()
    if existing:
        existing.password_hash = generate_password_hash(password)
        existing.role = 'admin'
        db.session.commit()
        return jsonify({'status': 'updated', 'email': email}), 200
    admin = User(
        email=email,
        password_hash=generate_password_hash(password),
        full_name='Admin PathoEngage',
        nim='-',
        role='admin',
    )
    db.session.add(admin)
    db.session.commit()
    return jsonify({'status': 'created', 'email': email}), 201


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)

