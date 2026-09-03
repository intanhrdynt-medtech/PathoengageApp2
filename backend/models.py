from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

db = SQLAlchemy()


class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    full_name = db.Column(db.String(120), nullable=True)
    nim = db.Column(db.String(50), nullable=True)
    current_semester = db.Column(db.Integer, default=1)
    phase = db.Column(db.String(16), default='MKDU')  # MKDU, red, yellow, green
    role = db.Column(db.String(16), default='ppds')   # ppds, admin, penilai
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Profil PPDS Lengkap
    angkatan = db.Column(db.String(10), nullable=True)
    dosen_wali = db.Column(db.String(200), nullable=True)
    pembimbing_1 = db.Column(db.String(200), nullable=True)
    pembimbing_2 = db.Column(db.String(200), nullable=True)
    pembimbing_retrospektif = db.Column(db.String(200), nullable=True)
    warning_active = db.Column(db.Boolean, default=False)
    warning_message = db.Column(db.Text, nullable=True)

    reminders = db.relationship('Reminder', backref='user', lazy=True)
    competency_logs = db.relationship('CompetencyLog', backref='user', lazy=True)
    exams = db.relationship('Exam', backref='user', lazy=True)
    academic_tasks = db.relationship('AcademicTask', backref='user', lazy=True)
    external_rotations = db.relationship('ExternalRotation', backref='user', lazy=True)
    journal_readings = db.relationship('JournalReadingSubmission', backref='user', lazy=True, foreign_keys='JournalReadingSubmission.user_id')
    penelitians = db.relationship('Penelitian', backref='user', lazy=True)
    pengabdians = db.relationship('PengabdianMasyarakat', backref='user', lazy=True)
    prestasis = db.relationship('Prestasi', backref='user', lazy=True)
    organ_exams = db.relationship('OrganExam', backref='user', lazy=True)


class CompetencyLog(db.Model):
    __tablename__ = 'competency_log'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    phase_category = db.Column(db.String(16), nullable=False)
    competency_name = db.Column(db.String(200), nullable=False)
    organ_system = db.Column(db.String(100), nullable=True)
    status = db.Column(db.String(32), default='not_started')
    evidence_url = db.Column(db.String(500), nullable=True)
    completed_at = db.Column(db.DateTime, nullable=True)
    notes = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class Exam(db.Model):
    __tablename__ = 'exam'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    phase_category = db.Column(db.String(16), nullable=True)
    exam_name = db.Column(db.String(200), nullable=False)
    exam_type = db.Column(db.String(100), nullable=False)
    scheduled_date = db.Column(db.DateTime, nullable=True)
    result = db.Column(db.String(32), default='terjadwal')
    evidence_url = db.Column(db.String(500), nullable=True)
    score = db.Column(db.Float, nullable=True)
    notes = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class AcademicTask(db.Model):
    __tablename__ = 'academic_task'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    task_type = db.Column(db.String(100), nullable=False)
    title = db.Column(db.String(300), nullable=False)
    description = db.Column(db.Text, nullable=True)
    target_semester = db.Column(db.Integer, nullable=True)
    deadline = db.Column(db.DateTime, nullable=True)
    is_completed = db.Column(db.Boolean, default=False)
    status = db.Column(db.String(32), default='not_started')
    document_proof_url = db.Column(db.String(500), nullable=True)
    link_url = db.Column(db.String(500), nullable=True)
    notes = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ExternalRotation(db.Model):
    __tablename__ = 'external_rotation'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    hospital_name = db.Column(db.String(200), nullable=False)
    department = db.Column(db.String(200), nullable=True)
    city = db.Column(db.String(100), nullable=True)
    supervisor = db.Column(db.String(200), nullable=True)
    start_date = db.Column(db.DateTime, nullable=True)
    end_date = db.Column(db.DateTime, nullable=True)
    status = db.Column(db.String(32), default='terjadwal')
    notes = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class Reminder(db.Model):
    __tablename__ = 'reminder'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text)
    time = db.Column(db.String(64))
    completed = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ── NEW: Journal Reading Submission ──────────────────────────────────────────

class JournalReadingSubmission(db.Model):
    __tablename__ = 'journal_reading_submission'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    judul = db.Column(db.String(500), nullable=False)
    penulis = db.Column(db.String(300), nullable=True)
    nama_jurnal = db.Column(db.String(300), nullable=True)
    pembimbing = db.Column(db.String(200), nullable=True)
    penguji = db.Column(db.String(200), nullable=True)
    tanggal_presentasi = db.Column(db.DateTime, nullable=True)
    jenis = db.Column(db.String(50), default='Journal Reading')
    status = db.Column(db.String(32), default='pending')  # pending, approved, rejected
    catatan_admin = db.Column(db.Text, nullable=True)
    bukti_url = db.Column(db.String(500), nullable=True)
    bukti_submitted = db.Column(db.Boolean, default=False)
    approved_by = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    approved_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ── NEW: Penelitian ──────────────────────────────────────────────────────────

class Penelitian(db.Model):
    __tablename__ = 'penelitian'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    judul = db.Column(db.String(500), nullable=False)
    jenis = db.Column(db.String(100), nullable=True)  # Case Report, Tinjauan Pustaka, Karya Akhir, Retrospektif
    pembimbing_1 = db.Column(db.String(200), nullable=True)
    pembimbing_2 = db.Column(db.String(200), nullable=True)
    pembimbing_retrospektif = db.Column(db.String(200), nullable=True)
    status = db.Column(db.String(32), default='draft')  # draft, submitted, revisi_1, revisi_2, approved, published
    dokumen_proposal_url = db.Column(db.String(500), nullable=True)
    dokumen_revisi1_url = db.Column(db.String(500), nullable=True)
    catatan_revisi1 = db.Column(db.Text, nullable=True)
    dokumen_revisi2_url = db.Column(db.String(500), nullable=True)
    catatan_revisi2 = db.Column(db.Text, nullable=True)
    dokumen_final_url = db.Column(db.String(500), nullable=True)
    link_publikasi = db.Column(db.String(500), nullable=True)
    loa_url = db.Column(db.String(500), nullable=True)
    nomor_etik = db.Column(db.String(200), nullable=True)
    ethical_clearance_url = db.Column(db.String(500), nullable=True)
    target_semester = db.Column(db.Integer, nullable=True)
    notes = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# ── NEW: Pengabdian Masyarakat ───────────────────────────────────────────────

class PengabdianMasyarakat(db.Model):
    __tablename__ = 'pengabdian_masyarakat'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    nama_kegiatan = db.Column(db.String(300), nullable=False)
    tanggal = db.Column(db.DateTime, nullable=True)
    lokasi = db.Column(db.String(300), nullable=True)
    deskripsi = db.Column(db.Text, nullable=True)
    bukti_url = db.Column(db.String(500), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ── NEW: Prestasi ────────────────────────────────────────────────────────────

class Prestasi(db.Model):
    __tablename__ = 'prestasi'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    nama_prestasi = db.Column(db.String(300), nullable=False)
    tingkat = db.Column(db.String(50), nullable=True)  # kampus, nasional, internasional
    tahun = db.Column(db.Integer, nullable=True)
    deskripsi = db.Column(db.Text, nullable=True)
    sertifikat_url = db.Column(db.String(500), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ── NEW: Admin Notification ──────────────────────────────────────────────────

class AdminNotification(db.Model):
    __tablename__ = 'admin_notification'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    message = db.Column(db.Text, nullable=False)
    type = db.Column(db.String(50), default='info')  # info, journal, penelitian, bukti
    ref_id = db.Column(db.Integer, nullable=True)
    ref_type = db.Column(db.String(50), nullable=True)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ── NEW: Survey ──────────────────────────────────────────────────────────────

class Survey(db.Model):
    __tablename__ = 'survey'
    id = db.Column(db.Integer, primary_key=True)
    judul = db.Column(db.String(300), nullable=False)
    link_survey = db.Column(db.String(500), nullable=False)
    semester_target = db.Column(db.Integer, nullable=True)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ── NEW: Organ Exam (Dinamis) ────────────────────────────────────────────────

class OrganExam(db.Model):
    __tablename__ = 'organ_exam'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    nama_ujian = db.Column(db.String(200), nullable=False)
    organ = db.Column(db.String(200), nullable=True)
    penguji = db.Column(db.String(200), nullable=True)
    tanggal = db.Column(db.DateTime, nullable=True)
    hasil = db.Column(db.String(32), default='terjadwal')  # terjadwal, lulus, tidak_lulus
    nilai = db.Column(db.Float, nullable=True)
    catatan = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

