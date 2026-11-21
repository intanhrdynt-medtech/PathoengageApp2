# PathoEngage API v2.2 - security hardening 2026-11-21
import sys
import os
# Ensure backend folder is in path so models.py can be imported
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import datetime
import hashlib
import hmac
import ipaddress
import logging
import math
import random
import re
import secrets
from functools import wraps
from urllib.parse import urlparse

from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import jwt
from sqlalchemy import case, inspect as sa_inspect
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.exc import IntegrityError
from werkzeug.exceptions import HTTPException
from werkzeug.security import generate_password_hash, check_password_hash

from models import (db, User, Reminder, CompetencyLog, Exam, AcademicTask, ExternalRotation,
                    JournalReadingSubmission, Penelitian, PengabdianMasyarakat, Prestasi,
                    AdminNotification, Survey, OrganExam, AppConfig, LoginThrottle)

load_dotenv()
log = logging.getLogger('pathoengage')

DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///./backend_data.db')
# Pakai driver psycopg2 secara eksplisit: SQLAlchemy 2.1 mengganti driver default
# `postgresql://` ke psycopg (v3) yang tidak terpasang.
for _prefix in ('postgres://', 'postgresql://'):
    if DATABASE_URL.startswith(_prefix):
        DATABASE_URL = 'postgresql+psycopg2://' + DATABASE_URL[len(_prefix):]
        break

# JWT secret: pakai env SECRET_KEY bila diset dengan nilai kuat (>= 32 karakter).
# Bila tidak, secret acak dibuat sekali lalu disimpan di tabel app_config sehingga
# sama untuk semua instance serverless. Nilai default lama yang tertulis di repo
# publik TIDAK pernah dipakai lagi (token yang ditandatangani dengannya ditolak).
_LEGACY_PUBLIC_SECRET = 'dev-secret-ppds-pa-unair'
_ENV_SECRET = os.getenv('SECRET_KEY', '').strip()
if _ENV_SECRET == _LEGACY_PUBLIC_SECRET or len(_ENV_SECRET) < 32:
    _ENV_SECRET = ''

# Endpoint pemeliharaan (/admin/migrate, /admin/seed-*) hanya aktif bila env
# SEED_SECRET diset (>= 16 karakter). Tanpa itu endpoint tersebut mengembalikan 404.
_SEED_SECRET = os.getenv('SEED_SECRET', '').strip()
if len(_SEED_SECRET) < 16:
    _SEED_SECRET = ''

TOKEN_TTL = datetime.timedelta(days=7)
MIN_PASSWORD_LENGTH = 8
MAX_PASSWORD_LENGTH = 128
VALID_ROLES = ('ppds', 'admin', 'penilai')
VALID_PHASES = ('MKDU', 'red', 'yellow', 'green')

# Status yang boleh di-set sendiri oleh PPDS. Status final (completed / lulus /
# approved) hanya bisa diberikan admin / penilai lewat endpoint verifikasi.
USER_SETTABLE_PROGRESS = ('not_started', 'in_progress', 'pending_verification')
USER_SETTABLE_EXAM_RESULT = ('terjadwal', 'pending_verification')
FINAL_PROGRESS = ('completed',)
FINAL_EXAM_RESULT = ('lulus',)
PENELITIAN_STATUSES = ('draft', 'submitted', 'revisi_1', 'revisi_2', 'approved', 'rejected', 'published')

app = Flask(__name__)
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URL
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {'pool_pre_ping': True}
app.config['MAX_CONTENT_LENGTH'] = 1 * 1024 * 1024  # API hanya menerima JSON kecil
app.config['JSON_SORT_KEYS'] = False

db.init_app(app)


# ── Errors ───────────────────────────────────────────────────────────────────

class ApiError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.message = message
        self.status = status


@app.errorhandler(ApiError)
def _handle_api_error(e):
    db.session.rollback()
    return jsonify({'error': e.message}), e.status


@app.errorhandler(Exception)
def _handle_unexpected(e):
    if isinstance(e, HTTPException):
        return jsonify({'error': e.description or e.name}), e.code
    db.session.rollback()
    log.exception('Unhandled error on %s %s', request.method, request.path)
    return jsonify({'error': 'Terjadi kesalahan pada server'}), 500


# ── Input helpers ────────────────────────────────────────────────────────────

def utcnow():
    return datetime.datetime.utcnow()


def get_json():
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


def _check_storable(value, field):
    """Tolak karakter yang tidak bisa disimpan Postgres (NUL) atau di-encode
    UTF-8 (surrogate tunggal) supaya tidak berakhir sebagai error 500."""
    if '\x00' in value:
        raise ApiError(f'{field} mengandung karakter tidak valid')
    try:
        value.encode('utf-8')
    except UnicodeEncodeError:
        raise ApiError(f'{field} mengandung karakter tidak valid')
    return value


def arg(name, max_len=200, default=''):
    """Query-string parameter yang aman dipakai di query database."""
    value = request.args.get(name, default)
    return _check_storable(value.strip()[:max_len], name)


def parse_dt(value, field):
    if value is None or value == '':
        return None
    if not isinstance(value, str):
        raise ApiError(f'{field} harus berupa tanggal ISO 8601')
    try:
        dt = datetime.datetime.fromisoformat(value.strip().replace('Z', '+00:00'))
    except ValueError:
        raise ApiError(f'{field} harus berupa tanggal ISO 8601')
    if dt.tzinfo is not None:
        dt = dt.astimezone(datetime.timezone.utc).replace(tzinfo=None)
    return dt


def parse_int(value, field, minimum=None, maximum=None, allow_none=True):
    if value is None or value == '':
        if allow_none:
            return None
        raise ApiError(f'{field} wajib diisi')
    if isinstance(value, bool):
        raise ApiError(f'{field} harus berupa angka')
    try:
        number = int(value)
    except (TypeError, ValueError):
        raise ApiError(f'{field} harus berupa angka')
    if (minimum is not None and number < minimum) or (maximum is not None and number > maximum):
        raise ApiError(f'{field} di luar rentang yang diizinkan')
    return number


def parse_float(value, field):
    if value is None or value == '':
        return None
    if isinstance(value, bool):
        raise ApiError(f'{field} harus berupa angka')
    try:
        number = float(value)
    except (TypeError, ValueError):
        raise ApiError(f'{field} harus berupa angka')
    if not math.isfinite(number):
        raise ApiError(f'{field} harus berupa angka')
    return number


def parse_bool(value, field):
    if isinstance(value, bool):
        return value
    raise ApiError(f'{field} harus true atau false')


def clean_text(value, field, max_len=None):
    if value is None:
        return None
    if not isinstance(value, (str, int, float)) or isinstance(value, bool):
        raise ApiError(f'{field} harus berupa teks')
    value = _check_storable(str(value), field)
    if max_len is not None and len(value) > max_len:
        raise ApiError(f'{field} maksimal {max_len} karakter')
    return value


_HAS_SCHEME_RE = re.compile(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://')
_HOSTLIKE_RE = re.compile(r'^[^\s/:?#]+\.[^\s/:?#]+([:/?#]\S*)?$')


def clean_url(value, field):
    """Hanya izinkan link http(s) supaya skema berbahaya (javascript:, file:, data:,
    dll.) tidak tersimpan lalu dibuka oleh aplikasi. Link tanpa skema seperti
    `drive.google.com/...` otomatis diberi `https://`."""
    if value is None or value == '':
        return value
    if not isinstance(value, str):
        raise ApiError(f'{field} harus berupa URL')
    value = _check_storable(value.strip(), field)
    if value == '':
        return value
    if value.startswith('//'):
        value = 'https:' + value
    elif not _HAS_SCHEME_RE.match(value) and _HOSTLIKE_RE.match(value):
        value = 'https://' + value
    if len(value) > 500:
        raise ApiError(f'{field} maksimal 500 karakter')
    parsed = urlparse(value)
    if parsed.scheme.lower() not in ('http', 'https') or not parsed.netloc or any(ch.isspace() for ch in value):
        raise ApiError(f'{field} harus berupa link yang valid (http:// atau https://)')
    return value


_EMAIL_RE = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')


def clean_email(value):
    email = (value or '').strip().lower() if isinstance(value, str) else ''
    if not email or len(email) > 120 or not _EMAIL_RE.match(email):
        raise ApiError('Format email tidak valid')
    return _check_storable(email, 'email')


def check_new_password(password):
    if not isinstance(password, str) or not password:
        raise ApiError('Password wajib diisi')
    _check_storable(password, 'Password')
    if len(password) < MIN_PASSWORD_LENGTH:
        raise ApiError(f'Password minimal {MIN_PASSWORD_LENGTH} karakter')
    if len(password) > MAX_PASSWORD_LENGTH:
        raise ApiError(f'Password maksimal {MAX_PASSWORD_LENGTH} karakter')
    return password


def apply_fields(obj, data, spec):
    """spec: {field: cleaner(value, field)} — hanya field yang dikirim yang diubah."""
    for field, cleaner in spec.items():
        if field in data:
            setattr(obj, field, cleaner(data[field], field))


def txt(max_len=None):
    return lambda v, f: clean_text(v, f, max_len)


def get_or_404(model, ident, message='Tidak ditemukan'):
    obj = db.session.get(model, ident)
    if obj is None:
        raise ApiError(message, 404)
    return obj


# ── Internal tables & JWT secret ─────────────────────────────────────────────

_aux_tables_ready = False
_jwt_secret_cache = None

# Kolom yang ditambahkan setelah tabelnya sudah ada di production. db.create_all()
# tidak menambah kolom ke tabel lama, jadi ditambahkan di sini bila belum ada.
_ADDED_COLUMNS = {
    'prestasi': {'juara_ke': 'VARCHAR(50)', 'waktu_pelaksanaan': 'TIMESTAMP'},
    'pengabdian_masyarakat': {'peran': 'VARCHAR(200)'},
    'penelitian': {'catatan_penilai': 'TEXT'},
}
_AUX_TABLES = (AppConfig.__table__, LoginThrottle.__table__)


def _existing_columns(table_names):
    """{table: {columns}} untuk tabel yang ada; satu query katalog di Postgres."""
    if db.engine.dialect.name == 'postgresql':
        stmt = db.text(
            'SELECT table_name, column_name FROM information_schema.columns '
            'WHERE table_schema = current_schema() AND table_name IN :tables'
        ).bindparams(db.bindparam('tables', expanding=True))
        found = {}
        with db.engine.connect() as conn:
            for table, column in conn.execute(stmt, {'tables': list(table_names)}):
                found.setdefault(table, set()).add(column)
        return found
    inspector = sa_inspect(db.engine)
    return {t: {c['name'] for c in inspector.get_columns(t)} for t in table_names if inspector.has_table(t)}


def _ensure_aux_tables():
    """Pastikan tabel internal & kolom baru ada. Normalnya hanya satu query katalog
    per instance; DDL hanya jalan bila memang ada yang kurang, dengan lock_timeout
    supaya tidak pernah menahan tabel lain lama-lama."""
    global _aux_tables_ready
    if _aux_tables_ready:
        return
    names = [t.name for t in _AUX_TABLES] + list(_ADDED_COLUMNS)
    existing = _existing_columns(names)
    missing_tables = [t for t in _AUX_TABLES if t.name not in existing]
    missing_columns = [
        (table, column, sql_type)
        for table, columns in _ADDED_COLUMNS.items() if table in existing
        for column, sql_type in columns.items() if column not in existing[table]
    ]
    if missing_tables or missing_columns:
        is_pg = db.engine.dialect.name == 'postgresql'
        try:
            with db.engine.begin() as conn:
                if is_pg:
                    conn.execute(db.text("SET LOCAL lock_timeout = '3s'"))
                    conn.execute(db.text("SET LOCAL statement_timeout = '15s'"))
                for table in missing_tables:
                    table.create(bind=conn, checkfirst=True)
                for table, column, sql_type in missing_columns:
                    if_not_exists = 'IF NOT EXISTS ' if is_pg else ''
                    conn.execute(db.text(f'ALTER TABLE {table} ADD COLUMN {if_not_exists}{column} {sql_type}'))
        except Exception:
            # Instance lain mungkin melakukannya bersamaan; cukup pastikan hasilnya ada.
            existing = _existing_columns(names)
            if any(t.name not in existing for t in _AUX_TABLES) or any(
                    table in existing and column not in existing[table] for table, column, _ in missing_columns):
                log.exception('Schema preparation failed')
                raise ApiError('Server sedang menyiapkan database, coba lagi sebentar lagi', 503)
    _aux_tables_ready = True


@app.before_request
def _prepare_schema():
    if request.path in ('/', '/health'):
        return None
    _ensure_aux_tables()
    return None


def get_jwt_secret():
    global _jwt_secret_cache
    if _ENV_SECRET:
        return _ENV_SECRET
    if _jwt_secret_cache:
        return _jwt_secret_cache
    _ensure_aux_tables()
    row = db.session.get(AppConfig, 'jwt_secret')
    if row is None:
        try:
            db.session.add(AppConfig(key='jwt_secret', value=secrets.token_urlsafe(48)))
            db.session.commit()
        except IntegrityError:
            db.session.rollback()
        row = db.session.get(AppConfig, 'jwt_secret')
    _jwt_secret_cache = row.value
    return _jwt_secret_cache


def _password_fingerprint(user):
    # Token otomatis tidak berlaku lagi saat password user diganti.
    return hashlib.sha256(user.password_hash.encode('utf-8')).hexdigest()[:24]


def encode_token(user):
    now = utcnow()
    payload = {
        'user_id': user.id,
        'pv': _password_fingerprint(user),
        'iat': now,
        'exp': now + TOKEN_TTL,
    }
    return jwt.encode(payload, get_jwt_secret(), algorithm='HS256')


def _authenticate():
    auth = request.headers.get('Authorization', '')
    if not auth.startswith('Bearer '):
        raise ApiError('Missing token', 401)
    token = auth[len('Bearer '):].strip()
    try:
        payload = jwt.decode(token, get_jwt_secret(), algorithms=['HS256'],
                             options={'require': ['exp', 'iat', 'user_id', 'pv']})
    except jwt.PyJWTError:
        raise ApiError('Invalid or expired token', 401)
    user_id = payload.get('user_id')
    if not isinstance(user_id, int) or isinstance(user_id, bool):
        raise ApiError('Invalid or expired token', 401)
    user = db.session.get(User, user_id)
    if user is None or not hmac.compare_digest(str(payload.get('pv')), _password_fingerprint(user)):
        raise ApiError('Invalid or expired token', 401)
    return user


def _role_guard(roles):
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            user = _authenticate()
            if roles and user.role not in roles:
                if roles == ('admin',):
                    raise ApiError('Admin access required', 403)
                raise ApiError('Admin or Penilai access required', 403)
            request.user = user
            return f(*args, **kwargs)
        return decorated
    return decorator


auth_required = _role_guard(None)
admin_required = _role_guard(('admin',))
admin_or_evaluator_required = _role_guard(('admin', 'penilai'))


def is_staff(user):
    return user.role in ('admin', 'penilai')


# ── Login / register throttling ──────────────────────────────────────────────
#
# Setiap percobaan "dipesan" lebih dulu dengan increment atomik (INSERT ... ON
# CONFLICT DO UPDATE ... RETURNING) sebelum password dicek, sehingga request
# paralel di banyak instance serverless tetap terhitung semua. Batas:
#   pair     (email + IP) : 10 percobaan / 15 menit  -> brute force dari satu sumber
#   ip       (semua email): 100 percobaan / 15 menit -> password spraying
#   email    (semua IP)   : 50 percobaan / 15 menit  -> brute force terdistribusi
#   register (per IP)     : 50 akun baru / 15 menit
# Key dicek berurutan dan berhenti di key pertama yang melewati batas, sehingga
# request yang sudah diblokir tidak ikut menambah hitungan key yang lebih luas.
# Bila hanya batas per-email yang terlampaui, IP yang pernah login sukses ke akun
# itu (30 hari terakhir) tetap boleh mencoba, jadi penyerang tidak bisa mengunci
# pemilik akun dari perangkat yang biasa dipakainya. Login yang berhasil
# mengembalikan "pesanan"-nya sehingga user normal tidak pernah terkena batas.

THROTTLE_WINDOW = datetime.timedelta(minutes=15)
THROTTLE_LIMITS = {'pair': 10, 'ip': 100, 'email': 50, 'register': 50}
KNOWN_PAIR_TTL = datetime.timedelta(days=30)
# Header X-Real-Ip / X-Forwarded-For hanya dipercaya di belakang proxy yang
# menimpanya (Vercel men-set env VERCEL=1). Di tempat lain pakai remote_addr.
_TRUST_PROXY_HEADERS = (bool(os.getenv('VERCEL')) or bool(os.getenv('AWS_LAMBDA_FUNCTION_NAME'))
                        or os.getenv('TRUST_PROXY_HEADERS') == '1')


def _normalize_ip(raw):
    """IPv6 dikelompokkan per /64 (satu pelanggan biasanya mendapat satu /64),
    supaya penyerang tidak bisa memakai alamat IPv6 tak terbatas."""
    raw = (raw or '').strip()
    try:
        addr = ipaddress.ip_address(raw)
    except ValueError:
        return raw[:100] or 'unknown'
    if isinstance(addr, ipaddress.IPv6Address):
        if addr.ipv4_mapped is not None:
            return str(addr.ipv4_mapped)
        return str(ipaddress.ip_network(f'{addr}/64', strict=False))
    return str(addr)


def _client_ip():
    if _TRUST_PROXY_HEADERS:
        real_ip = request.headers.get('X-Real-Ip', '').strip()
        if real_ip:
            return _normalize_ip(real_ip)
        forwarded = request.headers.get('X-Forwarded-For', '')
        if forwarded:
            return _normalize_ip(forwarded.split(',')[0])
    return _normalize_ip(request.remote_addr)


def _throttle_key(kind, ident):
    return f'{kind}:{ident}'[:320]


def _throttle_hit(kind, ident, now):
    table = LoginThrottle.__table__
    insert = pg_insert if db.engine.dialect.name == 'postgresql' else sqlite_insert
    expired = table.c.window_start < now - THROTTLE_WINDOW
    stmt = insert(table).values(key=_throttle_key(kind, ident), failures=1, window_start=now)
    stmt = stmt.on_conflict_do_update(
        index_elements=[table.c.key],
        set_={
            'failures': case((expired, 1), else_=table.c.failures + 1),
            'window_start': case((expired, now), else_=table.c.window_start),
        },
    ).returning(table.c.failures)
    return db.session.execute(stmt).scalar_one()


def _throttle_take(keys):
    """Pesan satu percobaan per key, berurutan. Mengembalikan jenis key pertama
    yang melewati batas (key setelahnya tidak dihitung), atau None."""
    _ensure_aux_tables()
    now = utcnow()
    blocked = None
    for kind, ident in keys:
        if _throttle_hit(kind, ident, now) > THROTTLE_LIMITS[kind]:
            blocked = kind
            break
    db.session.commit()
    if random.random() < 0.02:
        _throttle_cleanup(now)
    return blocked


def _known_pair_key(email, ip):
    return _throttle_key('known', f'{email}|{ip}')


def _is_known_pair(email, ip):
    row = db.session.get(LoginThrottle, _known_pair_key(email, ip))
    return row is not None and row.window_start > utcnow() - KNOWN_PAIR_TTL


def _remember_pair(email, ip):
    table = LoginThrottle.__table__
    insert = pg_insert if db.engine.dialect.name == 'postgresql' else sqlite_insert
    now = utcnow()
    stmt = insert(table).values(key=_known_pair_key(email, ip), failures=0, window_start=now)
    stmt = stmt.on_conflict_do_update(index_elements=[table.c.key], set_={'window_start': now})
    db.session.execute(stmt)


def _throttle_release(keys):
    """Kembalikan pesanan setelah login berhasil."""
    for kind, ident in keys:
        key = _throttle_key(kind, ident)
        if kind == 'pair':
            LoginThrottle.query.filter_by(key=key).delete(synchronize_session=False)
        else:
            LoginThrottle.query.filter(LoginThrottle.key == key, LoginThrottle.failures > 0).update(
                {'failures': LoginThrottle.failures - 1}, synchronize_session=False)
    db.session.commit()


def _throttle_cleanup(now):
    try:
        expired = db.or_(
            db.and_(~LoginThrottle.key.like('known:%'), LoginThrottle.window_start < now - THROTTLE_WINDOW),
            db.and_(LoginThrottle.key.like('known:%'), LoginThrottle.window_start < now - KNOWN_PAIR_TTL),
        )
        victims = db.select(LoginThrottle.key).where(expired).limit(500)
        if db.engine.dialect.name == 'postgresql':
            # Lewati baris yang sedang dikunci login lain, jadi tidak ada deadlock.
            victims = victims.with_for_update(skip_locked=True)
        LoginThrottle.query.filter(LoginThrottle.key.in_(victims.scalar_subquery())).delete(synchronize_session=False)
        db.session.commit()
    except Exception:
        db.session.rollback()
        log.exception('login_throttle cleanup failed')


_dummy_hash = None


def _dummy_password_check(password):
    """Samakan waktu respons untuk email yang tidak terdaftar."""
    global _dummy_hash
    if _dummy_hash is None:
        _dummy_hash = generate_password_hash(secrets.token_urlsafe(16))
    check_password_hash(_dummy_hash, password)
    return False


def user_dict(user):
    return {
        'id': user.id,
        'email': user.email,
        'full_name': user.full_name,
        'nim': user.nim,
        'phase': user.phase,
        'current_semester': user.current_semester,
        'role': user.role,
        'angkatan': getattr(user, 'angkatan', None),
        'dosen_wali': getattr(user, 'dosen_wali', None),
        'pembimbing_1': getattr(user, 'pembimbing_1', None),
        'pembimbing_2': getattr(user, 'pembimbing_2', None),
        'pembimbing_retrospektif': getattr(user, 'pembimbing_retrospektif', None),
        'warning_active': getattr(user, 'warning_active', False),
        'warning_message': getattr(user, 'warning_message', None),
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

    for title, link in TEXTBOOKS:
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


# Endpoint lama GET /seed (drop_all + akun default) sengaja dihapus: siapa pun
# bisa menghapus seluruh database lewat URL tersebut tanpa login.


def _require_seed_secret(data):
    """Endpoint pemeliharaan hanya aktif bila env SEED_SECRET diset."""
    if not _SEED_SECRET:
        raise ApiError('Not Found', 404)
    provided = data.get('secret')
    if not isinstance(provided, str) or not hmac.compare_digest(
            provided.encode('utf-8', 'surrogatepass'), _SEED_SECRET.encode('utf-8')):
        raise ApiError('Unauthorized', 403)


@app.route('/admin/migrate', methods=['POST'])
def run_migrate():
    _require_seed_secret(get_json())
    db.create_all()
    return jsonify({'status': 'success', 'message': 'Database migrated (new tables created)!'})


@app.route('/register', methods=['POST'])
def register():
    data = get_json()
    email = clean_email(data.get('email'))
    password = check_new_password(data.get('password'))
    full_name = (clean_text(data.get('full_name'), 'full_name', 120) or '').strip()
    nim = (clean_text(data.get('nim'), 'nim', 50) or '').strip()

    if _throttle_take([('register', _client_ip())]) is not None:
        raise ApiError('Terlalu banyak pendaftaran dari jaringan ini. Coba lagi dalam 15 menit.', 429)

    if User.query.filter_by(email=email).first():
        raise ApiError('Email sudah terdaftar')

    user = User(
        email=email,
        password_hash=generate_password_hash(password),
        full_name=full_name or email,
        nim=nim or '-',
        role='ppds',
    )
    db.session.add(user)
    try:
        db.session.flush()
    except IntegrityError:
        raise ApiError('Email sudah terdaftar')

    assign_standard_curriculum(user.id)
    db.session.commit()

    return jsonify({'token': encode_token(user), 'user': user_dict(user)}), 201


@app.route('/login', methods=['POST'])
def login():
    data = get_json()
    email = data.get('email')
    password = data.get('password')
    email = email.strip().lower() if isinstance(email, str) else ''
    if not email or not isinstance(password, str) or not password:
        raise ApiError('Email dan password wajib diisi')
    _check_storable(email, 'email')
    _check_storable(password, 'password')
    if len(email) > 320 or len(password) > MAX_PASSWORD_LENGTH:
        raise ApiError('Email atau password salah', 401)

    ip = _client_ip()
    keys = [('pair', f'{email}|{ip}'), ('ip', ip), ('email', email)]
    blocked = _throttle_take(keys)
    if blocked is not None and not (blocked == 'email' and _is_known_pair(email, ip)):
        raise ApiError('Terlalu banyak percobaan login. Coba lagi dalam 15 menit.', 429)

    user = User.query.filter_by(email=email).first()
    if user is None:
        ok = _dummy_password_check(password)
    else:
        ok = check_password_hash(user.password_hash, password)
        # Kompatibilitas: versi lama memotong spasi di awal/akhir password saat login.
        if not ok and password.strip() != password:
            ok = check_password_hash(user.password_hash, password.strip())

    if not ok:
        raise ApiError('Email atau password salah', 401)

    _throttle_release(keys)
    _remember_pair(email, ip)
    db.session.commit()
    return jsonify({'token': encode_token(user), 'user': user_dict(user)})


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


def _ensure_not_verified(is_final):
    if is_final:
        raise ApiError('Item ini sudah diverifikasi dan tidak bisa diubah lagi', 409)


def _user_progress_status(requested, allowed):
    if not isinstance(requested, str) or requested not in allowed:
        raise ApiError('Status tidak valid. Status final hanya bisa diberikan admin lewat verifikasi.', 403)
    return requested


@app.route('/competencies', methods=['GET'])
@auth_required
def get_competencies():
    return jsonify([comp_dict(c) for c in request.user.competency_logs])


@app.route('/competencies/<int:cid>', methods=['PUT'])
@auth_required
def update_competency(cid):
    comp = CompetencyLog.query.filter_by(id=cid, user_id=request.user.id).first()
    if not comp:
        raise ApiError('Tidak ditemukan', 404)
    data = get_json()
    _ensure_not_verified(comp.status in FINAL_PROGRESS)
    if 'status' in data:
        comp.status = _user_progress_status(data['status'], USER_SETTABLE_PROGRESS)
        comp.completed_at = None
    apply_fields(comp, data, {'evidence_url': clean_url, 'notes': txt(5000)})
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
        raise ApiError('Tidak ditemukan', 404)
    data = get_json()
    _ensure_not_verified(exam.result in FINAL_EXAM_RESULT)
    if 'result' in data:
        exam.result = _user_progress_status(data['result'], USER_SETTABLE_EXAM_RESULT)
    # Nilai (score) hanya boleh diisi admin.
    apply_fields(exam, data, {
        'evidence_url': clean_url,
        'notes': txt(5000),
        'scheduled_date': parse_dt,
    })
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
        raise ApiError('Tidak ditemukan', 404)
    data = get_json()
    _ensure_not_verified(bool(task.is_completed) or task.status in FINAL_PROGRESS)
    if 'status' in data:
        task.status = _user_progress_status(data['status'], USER_SETTABLE_PROGRESS)
    # is_completed, link_url & description hanya bisa diubah admin.
    apply_fields(task, data, {'document_proof_url': clean_url, 'notes': txt(5000)})
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


ROTATION_FIELDS = {
    'notes': txt(5000),
    'supervisor': txt(200),
    'start_date': parse_dt,
    'end_date': parse_dt,
    'department': txt(200),
    'city': txt(100),
}


def _hospital_name(value, field):
    value = clean_text(value, field, 200)
    if not value or not value.strip():
        raise ApiError('hospital_name wajib diisi')
    return value


@app.route('/rotations', methods=['GET'])
@auth_required
def get_rotations():
    return jsonify([rotation_dict(r) for r in request.user.external_rotations])


@app.route('/rotations/<int:rid>', methods=['PUT'])
@auth_required
def update_rotation(rid):
    rot = ExternalRotation.query.filter_by(id=rid, user_id=request.user.id).first()
    if not rot:
        raise ApiError('Tidak ditemukan', 404)
    data = get_json()
    # Status rotasi (mis. "selesai") hanya bisa diubah admin.
    apply_fields(rot, data, dict(ROTATION_FIELDS, hospital_name=_hospital_name))
    db.session.commit()
    return jsonify(rotation_dict(rot))


# ── Reminders ─────────────────────────────────────────────────────────────────

def _reminder_title(value, field):
    value = clean_text(value, field, 200)
    if not value or not value.strip():
        raise ApiError('title required')
    return value


@app.route('/reminders', methods=['GET', 'POST'])
@auth_required
def handle_reminders():
    user = request.user
    if request.method == 'GET':
        return jsonify([{
            'id': r.id, 'title': r.title, 'description': r.description,
            'time': r.time, 'completed': r.completed
        } for r in user.reminders])
    data = get_json()
    reminder = Reminder(
        user_id=user.id,
        title=_reminder_title(data.get('title'), 'title'),
        description=clean_text(data.get('description'), 'description', 5000),
        time=clean_text(data.get('time'), 'time', 64),
    )
    db.session.add(reminder)
    db.session.commit()
    return jsonify({'id': reminder.id, 'title': reminder.title}), 201


@app.route('/reminders/<int:rid>', methods=['PUT', 'DELETE'])
@auth_required
def update_reminder(rid):
    reminder = Reminder.query.filter_by(id=rid, user_id=request.user.id).first()
    if not reminder:
        raise ApiError('not found', 404)
    if request.method == 'DELETE':
        db.session.delete(reminder)
        db.session.commit()
        return jsonify({'deleted': rid})
    data = get_json()
    apply_fields(reminder, data, {
        'title': _reminder_title,
        'description': txt(5000),
        'time': txt(64),
        'completed': parse_bool,
    })
    db.session.commit()
    return jsonify({'id': reminder.id, 'title': reminder.title, 'completed': reminder.completed})


# ── User Phase Update ─────────────────────────────────────────────────────────

def _phase(value, field):
    if value not in VALID_PHASES:
        raise ApiError("phase harus salah satu dari: MKDU, red, yellow, green")
    return value


@app.route('/me/phase', methods=['PUT'])
@admin_required
def update_phase():
    # Tahap (phase) PPDS ditetapkan admin; endpoint ini hanya untuk akun admin sendiri.
    data = get_json()
    request.user.phase = _phase(data.get('phase'), 'phase')
    db.session.commit()
    return jsonify(user_dict(request.user))


# ── Admin ───────────────────────────────────────────────────────────────────────

def _semester(value, field):
    return parse_int(value, field, minimum=1, maximum=20)


ADMIN_PROFILE_FIELDS = {
    'full_name': txt(120),
    'nim': txt(50),
    'angkatan': txt(10),
    'dosen_wali': txt(200),
    'phase': _phase,
    'current_semester': _semester,
    'pembimbing_1': txt(200),
    'pembimbing_2': txt(200),
    'pembimbing_retrospektif': txt(200),
    'warning_active': parse_bool,
    'warning_message': txt(5000),
}


@app.route('/admin/users', methods=['GET'])
@admin_required
def get_users():
    users = User.query.filter(User.role != 'admin').all()
    return jsonify([user_dict(u) for u in users])


@app.route('/admin/users', methods=['POST'])
@admin_required
def create_user_by_admin():
    data = get_json()
    email = clean_email(data.get('email'))
    password = check_new_password(data.get('password'))
    full_name = (clean_text(data.get('full_name'), 'full_name', 120) or '').strip()
    nim = (clean_text(data.get('nim'), 'nim', 50) or '').strip()
    role = data.get('role', 'ppds')
    if role not in VALID_ROLES:
        raise ApiError('role harus salah satu dari: ppds, admin, penilai')

    if User.query.filter_by(email=email).first():
        raise ApiError('Email sudah terdaftar')

    user = User(
        email=email,
        password_hash=generate_password_hash(password),
        full_name=full_name or email,
        nim=nim or '-',
        role=role,
    )
    db.session.add(user)
    try:
        db.session.flush()
    except IntegrityError:
        raise ApiError('Email sudah terdaftar')
    if role == 'ppds':
        assign_standard_curriculum(user.id)
    db.session.commit()
    return jsonify(user_dict(user)), 201


@app.route('/admin/users/<int:uid>', methods=['PUT'])
@admin_required
def update_user_by_admin(uid):
    user = get_or_404(User, uid, 'User tidak ditemukan')
    data = get_json()
    apply_fields(user, data, {k: ADMIN_PROFILE_FIELDS[k] for k in ('full_name', 'nim', 'phase', 'current_semester')})
    if data.get('password'):
        user.password_hash = generate_password_hash(check_new_password(data['password']))
    db.session.commit()
    return jsonify(user_dict(user))


@app.route('/admin/users/<int:uid>', methods=['DELETE'])
@admin_required
def delete_user_by_admin(uid):
    user = get_or_404(User, uid, 'User tidak ditemukan')
    if user.id == request.user.id:
        raise ApiError('Tidak bisa menghapus akun sendiri')
    # Lepaskan referensi "disetujui oleh" agar user penilai/admin bisa dihapus.
    JournalReadingSubmission.query.filter_by(approved_by=user.id).update({'approved_by': None})
    db.session.delete(user)  # data milik user ikut terhapus (cascade)
    db.session.commit()
    return jsonify({'deleted': uid})


@app.route('/admin/pending_verifications', methods=['GET'])
@admin_required
def get_pending_verifications():
    pending_academic = AcademicTask.query.filter_by(status='pending_verification').all()
    pending_exams = Exam.query.filter_by(result='pending_verification').all()
    pending_comps = CompetencyLog.query.filter_by(status='pending_verification').all()

    def enrich(d, item, category):
        d['user_name'] = item.user.full_name
        d['user_id'] = item.user_id
        d['type_category'] = category
        return d

    results = []
    results.extend([enrich(task_dict(t), t, 'academic') for t in pending_academic])
    results.extend([enrich(exam_dict(e), e, 'exam') for e in pending_exams])
    results.extend([enrich(comp_dict(c), c, 'competency') for c in pending_comps])
    return jsonify(results)


@app.route('/admin/verify/<type_category>/<int:item_id>', methods=['PUT'])
@admin_required
def verify_item(type_category, item_id):
    data = get_json()
    action = data.get('action', 'approve')
    if action not in ('approve', 'reject'):
        raise ApiError('action harus approve atau reject')
    approve = action == 'approve'

    if type_category == 'academic':
        item = get_or_404(AcademicTask, item_id, 'Not found')
        item.status = 'completed' if approve else 'not_started'
        item.is_completed = approve
    elif type_category == 'exam':
        item = get_or_404(Exam, item_id, 'Not found')
        item.result = 'lulus' if approve else 'tidak_lulus'
    elif type_category == 'competency':
        item = get_or_404(CompetencyLog, item_id, 'Not found')
        item.status = 'completed' if approve else 'not_started'
        item.completed_at = utcnow() if approve else None
    else:
        raise ApiError('Invalid category')

    db.session.commit()
    return jsonify({'success': True, 'id': item_id, 'type_category': type_category})


@app.route('/admin/progress/<int:uid>', methods=['GET'])
@admin_required
def get_user_progress(uid):
    user = get_or_404(User, uid, 'User tidak ditemukan')

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


def _target_user_id(data):
    user_id = parse_int(data.get('user_id'), 'user_id', minimum=1, allow_none=False)
    get_or_404(User, user_id, 'User tidak ditemukan')
    return user_id


def _required_text(max_len):
    def cleaner(value, field):
        value = clean_text(value, field, max_len)
        if not value or not value.strip():
            raise ApiError(f'{field} wajib diisi')
        return value
    return cleaner


ADMIN_TASK_FIELDS = {
    'task_type': _required_text(100),
    'title': _required_text(300),
    'description': txt(5000),
    'target_semester': _semester,
    'deadline': parse_dt,
    'status': txt(32),
    'is_completed': parse_bool,
    'document_proof_url': clean_url,
    'link_url': clean_url,
    'notes': txt(5000),
}


@app.route('/admin/academic-tasks', methods=['POST'])
@admin_required
def admin_add_task():
    data = get_json()
    user_id = _target_user_id(data)
    task = AcademicTask(
        user_id=user_id,
        task_type=_required_text(100)(data.get('task_type', 'Tugas Ilmiah'), 'task_type'),
        title=_required_text(300)(data.get('title'), 'title'),
        description=clean_text(data.get('description', ''), 'description', 5000),
        target_semester=_semester(data.get('target_semester'), 'target_semester'),
        deadline=parse_dt(data.get('deadline'), 'deadline'),
        status='not_started',
        is_completed=False,
        link_url=clean_url(data.get('link_url'), 'link_url'),
        notes=clean_text(data.get('notes'), 'notes', 5000),
    )
    db.session.add(task)
    db.session.commit()
    return jsonify(task_dict(task)), 201


@app.route('/admin/academic-tasks/<int:tid>', methods=['PUT'])
@admin_required
def admin_update_academic_task(tid):
    task = get_or_404(AcademicTask, tid, 'Tugas tidak ditemukan')
    apply_fields(task, get_json(), ADMIN_TASK_FIELDS)
    db.session.commit()
    return jsonify(task_dict(task))


@app.route('/admin/rotations/<int:rid>', methods=['PUT'])
@admin_required
def admin_update_rotation(rid):
    rot = get_or_404(ExternalRotation, rid)
    apply_fields(rot, get_json(), dict(ROTATION_FIELDS, hospital_name=_hospital_name, status=txt(32)))
    db.session.commit()
    return jsonify(rotation_dict(rot))


@app.route('/admin/rotations', methods=['POST'])
@admin_required
def admin_add_rotation():
    data = get_json()
    rot = ExternalRotation(
        user_id=_target_user_id(data),
        hospital_name=_hospital_name(data.get('hospital_name'), 'hospital_name'),
        department=clean_text(data.get('department', ''), 'department', 200),
        city=clean_text(data.get('city', ''), 'city', 100),
        supervisor=clean_text(data.get('supervisor'), 'supervisor', 200),
        start_date=parse_dt(data.get('start_date'), 'start_date'),
        end_date=parse_dt(data.get('end_date'), 'end_date'),
        status=clean_text(data.get('status', 'terjadwal'), 'status', 32) or 'terjadwal',
        notes=clean_text(data.get('notes'), 'notes', 5000),
    )
    db.session.add(rot)
    db.session.commit()
    return jsonify(rotation_dict(rot)), 201


TEXTBOOKS = [
    ('Classification of Tumor', 'https://tumourclassification.iarc.who.int/home'),
    ('Pathologic Basic of Disease', 'https://shop.elsevier.com/books/robbins-cotran-and-kumar-pathologic-basis-of-disease/kumar/978-0-443-26452-'),
    ('Basic Pathology', 'https://shop.elsevier.com/books/robbins-and-kumar-basic-pathology/kumar/978-0-323-79018-5'),
    ("Enzinger and Weiss's Soft Tissue Tumors", 'https://shop.elsevier.com/books/enzinger-and-weisss-soft-tissue-tumors/goldblum/978-0-323-61096-4'),
    ("Cibas and Ducatman's Cytology", 'https://shop.elsevier.com/books/cibas-and-ducatman-s-cytology/cibas/978-0-323-93434-3'),
    ('Pathology', 'https://innocentbalti.wordpress.com/wp-content/uploads/2015/01/harsh-mohan-textbook-of-pathology-6th-ed.pdf'),
    ("Silva's Diagnostic Renal Pathology", 'https://www.amazon.com/Silvas-Diagnostic-Renal-Pathology-Joseph/dp/1316613984'),
    ("Weedon's Skin Pathology", 'https://www.sciencedirect.com/book/monograph/9780702034855/weedons-skin-pathology'),
]


@app.route('/admin/seed-textbooks', methods=['POST'])
def seed_textbooks():
    _require_seed_secret(get_json())
    users = User.query.filter_by(role='ppds').all()
    count = 0
    skipped = 0
    for u in users:
        for title, url in TEXTBOOKS:
            existing = AcademicTask.query.filter_by(
                user_id=u.id, task_type='Textbook Reading', title=title
            ).first()
            if existing:
                skipped += 1
                continue
            db.session.add(AcademicTask(
                user_id=u.id,
                task_type='Textbook Reading',
                title=title,
                description='Tugas membaca buku teks',
                target_semester=u.current_semester or 1,
                is_completed=False,
                status='not_started',
                link_url=url,
            ))
            count += 1
    db.session.commit()
    return jsonify({'inserted': count, 'skipped': skipped, 'users': len(users)}), 200


@app.route('/admin/seed-admin', methods=['POST'])
def seed_admin():
    data = get_json()
    _require_seed_secret(data)
    email = clean_email(data.get('email'))
    password = check_new_password(data.get('password'))
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


# ── Journal Reading Submission ───────────────────────────────────────────────

def jr_dict(j, include_user=False):
    d = {
        'id': j.id,
        'user_id': j.user_id,
        'judul': j.judul,
        'penulis': j.penulis,
        'nama_jurnal': j.nama_jurnal,
        'pembimbing': j.pembimbing,
        'penguji': j.penguji,
        'tanggal_presentasi': j.tanggal_presentasi.isoformat() if j.tanggal_presentasi else None,
        'jenis': j.jenis,
        'status': j.status,
        'catatan_admin': j.catatan_admin,
        'bukti_url': j.bukti_url,
        'bukti_submitted': j.bukti_submitted,
        'approved_at': j.approved_at.isoformat() if j.approved_at else None,
        'created_at': j.created_at.isoformat() if j.created_at else None,
    }
    if include_user:
        u = j.user
        d['user_name'] = u.full_name if u else '-'
        d['user_nim'] = u.nim if u else '-'
    return d


def jr_public_dict(j):
    """Versi ringkas untuk sesama PPDS (cek duplikasi judul)."""
    u = j.user
    return {
        'id': j.id,
        'judul': j.judul,
        'penulis': j.penulis,
        'nama_jurnal': j.nama_jurnal,
        'jenis': j.jenis,
        'status': j.status,
        'tanggal_presentasi': j.tanggal_presentasi.isoformat() if j.tanggal_presentasi else None,
        'bukti_url': j.bukti_url,
        'created_at': j.created_at.isoformat() if j.created_at else None,
        'user_name': u.full_name if u else '-',
    }


@app.route('/check-topic', methods=['GET'])
@auth_required
def check_topic():
    judul = arg('judul', 500)
    jenis = arg('jenis', 50).lower()

    if not judul:
        return jsonify({'exists': False, 'message': 'Judul kosong'})

    exists = False
    message = ''
    lowered = judul.lower()

    if jenis == 'penelitian':
        if Penelitian.query.filter(db.func.lower(Penelitian.judul) == lowered).first():
            exists = True
            message = 'Judul penelitian sudah pernah diajukan.'
    elif jenis in ('journal_reading', 'journal'):
        if JournalReadingSubmission.query.filter(db.func.lower(JournalReadingSubmission.judul) == lowered).first():
            exists = True
            message = 'Judul journal reading sudah pernah diajukan.'
    else:
        existing_pen = Penelitian.query.filter(db.func.lower(Penelitian.judul) == lowered).first()
        existing_jr = JournalReadingSubmission.query.filter(db.func.lower(JournalReadingSubmission.judul) == lowered).first()
        if existing_pen or existing_jr:
            exists = True
            message = 'Judul sudah pernah digunakan (Penelitian atau Journal Reading).'

    return jsonify({'exists': exists, 'message': message})


@app.route('/journal-readings', methods=['GET'])
@auth_required
def get_my_journal_readings():
    items = JournalReadingSubmission.query.filter_by(user_id=request.user.id).order_by(JournalReadingSubmission.created_at.desc()).all()
    return jsonify([jr_dict(j) for j in items])


@app.route('/journal-readings', methods=['POST'])
@auth_required
def submit_journal_reading():
    data = get_json()
    judul = _required_text(500)(data.get('judul'), 'Judul')
    j = JournalReadingSubmission(
        user_id=request.user.id,
        judul=judul,
        penulis=clean_text(data.get('penulis'), 'penulis', 300),
        nama_jurnal=clean_text(data.get('nama_jurnal'), 'nama_jurnal', 300),
        pembimbing=clean_text(data.get('pembimbing'), 'pembimbing', 200),
        penguji=clean_text(data.get('penguji'), 'penguji', 200),
        tanggal_presentasi=parse_dt(data.get('tanggal_presentasi'), 'tanggal_presentasi'),
        jenis=clean_text(data.get('jenis', 'Journal Reading'), 'jenis', 50) or 'Journal Reading',
        status='pending',
    )
    db.session.add(j)
    db.session.flush()
    db.session.add(AdminNotification(
        title='Pengajuan Journal Reading Baru',
        message=f'{request.user.full_name} mengajukan: {j.judul}',
        type='journal',
        ref_id=j.id,
        ref_type='journal',
    ))
    db.session.commit()
    return jsonify(jr_dict(j)), 201


@app.route('/journal-readings/<int:jid>/bukti', methods=['PATCH'])
@auth_required
def submit_bukti_journal(jid):
    j = JournalReadingSubmission.query.filter_by(id=jid, user_id=request.user.id).first()
    if not j:
        raise ApiError('Tidak ditemukan', 404)
    if j.status != 'approved':
        raise ApiError('Hanya bisa upload bukti jika sudah diapprove')
    data = get_json()
    if 'bukti_url' in data:
        j.bukti_url = clean_url(data['bukti_url'], 'bukti_url')
    j.bukti_submitted = True
    db.session.commit()
    return jsonify(jr_dict(j))


@app.route('/journal-readings/all', methods=['GET'])
@auth_required
def get_all_journal_readings():
    """Semua PPDS bisa lihat daftar ini untuk cek duplikasi"""
    q = arg('q')
    query = JournalReadingSubmission.query.filter(JournalReadingSubmission.status == 'approved')
    if q:
        query = query.filter(JournalReadingSubmission.judul.ilike(f'%{q}%'))
    items = query.order_by(JournalReadingSubmission.created_at.desc()).all()
    if is_staff(request.user):
        return jsonify([jr_dict(j, include_user=True) for j in items])
    return jsonify([jr_public_dict(j) for j in items])


@app.route('/admin/journal-readings', methods=['GET'])
@admin_or_evaluator_required
def admin_list_journal_readings():
    status_filter = arg('status', 32, 'pending')
    items = JournalReadingSubmission.query.filter_by(status=status_filter).order_by(JournalReadingSubmission.created_at.desc()).all()
    return jsonify([jr_dict(j, include_user=True) for j in items])


@app.route('/admin/journal-readings/<int:jid>/review', methods=['PATCH'])
@admin_or_evaluator_required
def admin_review_journal(jid):
    j = get_or_404(JournalReadingSubmission, jid)
    if j.user_id == request.user.id:
        raise ApiError('Tidak bisa mereview pengajuan milik sendiri', 403)
    data = get_json()
    action = data.get('action')
    if action == 'approve':
        j.status = 'approved'
        j.approved_by = request.user.id
        j.approved_at = utcnow()
    elif action == 'reject':
        j.status = 'rejected'
    else:
        raise ApiError('action harus approve atau reject')
    if 'catatan_admin' in data:
        j.catatan_admin = clean_text(data['catatan_admin'], 'catatan_admin', 5000)
    db.session.commit()
    return jsonify(jr_dict(j))


# ── Penelitian ────────────────────────────────────────────────────────────────

def pen_dict(p, include_user=False):
    d = {
        'id': p.id,
        'user_id': p.user_id,
        'judul': p.judul,
        'jenis': p.jenis,
        'pembimbing_1': p.pembimbing_1,
        'pembimbing_2': p.pembimbing_2,
        'pembimbing_retrospektif': p.pembimbing_retrospektif,
        'status': p.status,
        'dokumen_proposal_url': p.dokumen_proposal_url,
        'dokumen_revisi1_url': p.dokumen_revisi1_url,
        'catatan_revisi1': p.catatan_revisi1,
        'dokumen_revisi2_url': p.dokumen_revisi2_url,
        'catatan_revisi2': p.catatan_revisi2,
        'dokumen_final_url': p.dokumen_final_url,
        'link_publikasi': p.link_publikasi,
        'loa_url': p.loa_url,
        'nomor_etik': p.nomor_etik,
        'ethical_clearance_url': p.ethical_clearance_url,
        'target_semester': p.target_semester,
        'notes': p.notes,
        'created_at': p.created_at.isoformat() if p.created_at else None,
        'updated_at': p.updated_at.isoformat() if p.updated_at else None,
        'catatan_penilai': p.catatan_penilai,
        'perlu_review': penelitian_perlu_review(p),
    }
    if include_user:
        u = p.user
        d['user_name'] = u.full_name if u else '-'
        d['user_nim'] = u.nim if u else '-'
    return d


def penelitian_perlu_review(p):
    """Menunggu keputusan penilai: baru diajukan, atau dokumen revisi untuk
    ronde revisi yang sedang berjalan sudah diunggah PPDS."""
    if p.status == 'submitted':
        return True
    if p.status == 'revisi_1':
        return bool(p.dokumen_revisi1_url)
    if p.status == 'revisi_2':
        return bool(p.dokumen_revisi2_url)
    return False


def pen_public_dict(p):
    """Versi ringkas untuk sesama PPDS: tanpa dokumen, catatan, atau nomor etik."""
    u = p.user
    return {
        'id': p.id,
        'judul': p.judul,
        'jenis': p.jenis,
        'status': p.status,
        'created_at': p.created_at.isoformat() if p.created_at else None,
        'user_name': u.full_name if u else '-',
    }


# Identitas penelitian hanya boleh diubah saat masih draft / sedang revisi.
PENELITIAN_IDENTITY_FIELDS = {
    'judul': _required_text(500),
    'jenis': txt(100),
    'pembimbing_1': txt(200),
    'pembimbing_2': txt(200),
    'pembimbing_retrospektif': txt(200),
    'target_semester': _semester,
}
PENELITIAN_EDITABLE_STATUSES = ('draft', 'revisi_1', 'revisi_2')

PENELITIAN_USER_FIELDS = {
    'dokumen_proposal_url': clean_url,
    'dokumen_revisi1_url': clean_url,
    'dokumen_revisi2_url': clean_url,
    'dokumen_final_url': clean_url,
    'link_publikasi': clean_url,
    'loa_url': clean_url,
    'nomor_etik': txt(200),
    'ethical_clearance_url': clean_url,
    'notes': txt(5000),
}


@app.route('/penelitian', methods=['GET'])
@auth_required
def get_penelitian():
    items = Penelitian.query.filter_by(user_id=request.user.id).order_by(Penelitian.created_at.desc()).all()
    return jsonify([pen_dict(p) for p in items])


@app.route('/penelitian', methods=['POST'])
@auth_required
def add_penelitian():
    data = get_json()
    p = Penelitian(
        user_id=request.user.id,
        judul=_required_text(500)(data.get('judul'), 'Judul'),
        jenis=clean_text(data.get('jenis'), 'jenis', 100),
        pembimbing_1=clean_text(data.get('pembimbing_1'), 'pembimbing_1', 200),
        pembimbing_2=clean_text(data.get('pembimbing_2'), 'pembimbing_2', 200),
        pembimbing_retrospektif=clean_text(data.get('pembimbing_retrospektif'), 'pembimbing_retrospektif', 200),
        target_semester=_semester(data.get('target_semester'), 'target_semester'),
        notes=clean_text(data.get('notes'), 'notes', 5000),
        status='draft',
    )
    db.session.add(p)
    db.session.flush()
    db.session.add(AdminNotification(
        title='Penelitian Baru Disubmit',
        message=f'{request.user.full_name} menambahkan penelitian: {p.judul}',
        type='penelitian',
        ref_id=p.id,
        ref_type='penelitian',
    ))
    db.session.commit()
    return jsonify(pen_dict(p)), 201


@app.route('/penelitian/<int:pid>', methods=['PATCH'])
@auth_required
def update_penelitian(pid):
    p = Penelitian.query.filter_by(id=pid, user_id=request.user.id).first()
    if not p:
        raise ApiError('Tidak ditemukan', 404)
    data = get_json()
    original_status = p.status
    if 'status' in data and data['status'] != p.status:
        # PPDS hanya boleh mengajukan draft (draft -> submitted). Status lain
        # (revisi, approved, rejected, published) ditetapkan admin / penilai.
        if not (p.status == 'draft' and data['status'] == 'submitted'):
            raise ApiError('Status penelitian hanya bisa diubah oleh admin / penilai', 403)
        p.status = 'submitted'
    if original_status in PENELITIAN_EDITABLE_STATUSES:
        apply_fields(p, data, PENELITIAN_IDENTITY_FIELDS)
    elif any(field in data for field in PENELITIAN_IDENTITY_FIELDS):
        raise ApiError('Judul, jenis, dan pembimbing tidak bisa diubah setelah penelitian diajukan', 409)
    was_waiting = penelitian_perlu_review(p)
    apply_fields(p, data, PENELITIAN_USER_FIELDS)
    if p.status in ('revisi_1', 'revisi_2') and not was_waiting and penelitian_perlu_review(p):
        ronde = '1' if p.status == 'revisi_1' else '2'
        db.session.add(AdminNotification(
            title=f'Revisi {ronde} Penelitian Diunggah',
            message=f'{request.user.full_name} mengunggah revisi {ronde}: {p.judul}',
            type='penelitian',
            ref_id=p.id,
            ref_type='penelitian',
        ))
    db.session.commit()
    return jsonify(pen_dict(p))


@app.route('/penelitian/all', methods=['GET'])
@auth_required
def get_all_penelitian():
    q = arg('q')
    query = Penelitian.query
    if q:
        query = query.filter(Penelitian.judul.ilike(f'%{q}%'))
    items = query.order_by(Penelitian.created_at.desc()).all()
    if is_staff(request.user):
        return jsonify([pen_dict(p, include_user=True) for p in items])
    return jsonify([pen_public_dict(p) for p in items])


@app.route('/admin/penelitian/<int:pid>/status', methods=['PATCH'])
@admin_or_evaluator_required
def admin_update_penelitian_status(pid):
    p = get_or_404(Penelitian, pid)
    if p.user_id == request.user.id:
        raise ApiError('Tidak bisa mereview penelitian milik sendiri', 403)
    data = get_json()
    if 'status' in data:
        if data['status'] not in PENELITIAN_STATUSES:
            raise ApiError('Status penelitian tidak valid')
        new_status = data['status']
        # Meminta revisi = membuka ronde baru: slot dokumen revisi dikosongkan
        # supaya penelitian keluar dari antrean review sampai PPDS mengunggah
        # dokumen revisinya. Link dokumen lama disimpan di catatan revisi agar
        # riwayatnya tidak hilang.
        doc_field = {'revisi_1': 'dokumen_revisi1_url', 'revisi_2': 'dokumen_revisi2_url'}.get(new_status)
        if doc_field and (new_status != p.status or penelitian_perlu_review(p)):
            old_doc = getattr(p, doc_field)
            if old_doc:
                note_field = 'catatan_revisi1' if new_status == 'revisi_1' else 'catatan_revisi2'
                history = f'[Dokumen revisi sebelumnya: {old_doc}]'
                new_note = clean_text(data.get('catatan'), 'catatan', 5000) or getattr(p, note_field) or ''
                combined = new_note + '\n' + history if new_note else history
                data = dict(data, catatan=combined[-5000:])
            setattr(p, doc_field, None)
        p.status = new_status
    apply_fields(p, data, {
        'catatan_revisi1': txt(5000),
        'catatan_revisi2': txt(5000),
        'catatan_penilai': txt(5000),
    })
    # Aplikasi mengirim catatan penilai sebagai "catatan"; simpan ke kolom yang sesuai.
    catatan = clean_text(data.get('catatan'), 'catatan', 5000)
    if catatan:
        if p.status == 'revisi_1':
            p.catatan_revisi1 = catatan
        elif p.status == 'revisi_2':
            p.catatan_revisi2 = catatan
        else:
            p.catatan_penilai = catatan
    db.session.commit()
    return jsonify(pen_dict(p, include_user=True))


# ── Pengabdian Masyarakat ─────────────────────────────────────────────────────
#
# Aplikasi Flutter memakai nama field `tempat` dan `waktu_pelaksanaan`; kolom
# database bernama `lokasi` dan `tanggal`. Keduanya diterima & dikembalikan.

def _apply_aliases(data, aliases):
    data = dict(data)
    for alias, column in aliases.items():
        if alias in data and column not in data:
            data[column] = data[alias]
    return data


PENGABDIAN_ALIASES = {'tempat': 'lokasi', 'waktu_pelaksanaan': 'tanggal'}


def pgb_dict(p):
    tanggal = p.tanggal.isoformat() if p.tanggal else None
    return {
        'id': p.id,
        'nama_kegiatan': p.nama_kegiatan,
        'tanggal': tanggal,
        'waktu_pelaksanaan': tanggal,
        'lokasi': p.lokasi,
        'tempat': p.lokasi,
        'peran': p.peran,
        'deskripsi': p.deskripsi,
        'bukti_url': p.bukti_url,
        'created_at': p.created_at.isoformat() if p.created_at else None,
    }


PENGABDIAN_FIELDS = {
    'nama_kegiatan': _required_text(300),
    'lokasi': txt(300),
    'peran': txt(200),
    'deskripsi': txt(5000),
    'bukti_url': clean_url,
    'tanggal': parse_dt,
}


@app.route('/pengabdian', methods=['GET'])
@auth_required
def get_pengabdian():
    items = PengabdianMasyarakat.query.filter_by(user_id=request.user.id).order_by(PengabdianMasyarakat.created_at.desc()).all()
    return jsonify([pgb_dict(p) for p in items])


@app.route('/pengabdian', methods=['POST'])
@auth_required
def add_pengabdian():
    data = _apply_aliases(get_json(), PENGABDIAN_ALIASES)
    if not data.get('nama_kegiatan'):
        raise ApiError('Nama kegiatan wajib diisi')
    p = PengabdianMasyarakat(user_id=request.user.id)
    apply_fields(p, data, PENGABDIAN_FIELDS)
    db.session.add(p)
    db.session.commit()
    return jsonify(pgb_dict(p)), 201


@app.route('/pengabdian/<int:pid>', methods=['PATCH', 'DELETE'])
@auth_required
def update_delete_pengabdian(pid):
    p = PengabdianMasyarakat.query.filter_by(id=pid, user_id=request.user.id).first()
    if not p:
        raise ApiError('Tidak ditemukan', 404)
    if request.method == 'DELETE':
        db.session.delete(p)
        db.session.commit()
        return jsonify({'message': 'Deleted'})
    apply_fields(p, _apply_aliases(get_json(), PENGABDIAN_ALIASES), PENGABDIAN_FIELDS)
    db.session.commit()
    return jsonify(pgb_dict(p))


# ── Prestasi ──────────────────────────────────────────────────────────────────
#
# Aplikasi Flutter memakai `nama_lomba`, `waktu_pelaksanaan`, `juara_ke`; kolom
# database bernama `nama_prestasi` (+ `tahun` diisi otomatis dari tanggal).

PRESTASI_ALIASES = {'nama_lomba': 'nama_prestasi'}


def prs_dict(p):
    waktu = p.waktu_pelaksanaan.isoformat() if p.waktu_pelaksanaan else None
    return {
        'id': p.id,
        'nama_prestasi': p.nama_prestasi,
        'nama_lomba': p.nama_prestasi,
        'tingkat': p.tingkat,
        'juara_ke': p.juara_ke,
        'tahun': p.tahun,
        'waktu_pelaksanaan': waktu,
        'deskripsi': p.deskripsi,
        'sertifikat_url': p.sertifikat_url,
        'created_at': p.created_at.isoformat() if p.created_at else None,
    }


def _tahun(value, field):
    return parse_int(value, field, minimum=1900, maximum=2200)


PRESTASI_FIELDS = {
    'nama_prestasi': _required_text(300),
    'tingkat': txt(50),
    'juara_ke': txt(50),
    'tahun': _tahun,
    'waktu_pelaksanaan': parse_dt,
    'deskripsi': txt(5000),
    'sertifikat_url': clean_url,
}


def _apply_prestasi(p, data):
    apply_fields(p, data, PRESTASI_FIELDS)
    if p.waktu_pelaksanaan is not None and 'waktu_pelaksanaan' in data and 'tahun' not in data:
        p.tahun = _tahun(p.waktu_pelaksanaan.year, 'waktu_pelaksanaan')


@app.route('/prestasi', methods=['GET'])
@auth_required
def get_prestasi():
    items = Prestasi.query.filter_by(user_id=request.user.id).order_by(Prestasi.created_at.desc()).all()
    return jsonify([prs_dict(p) for p in items])


@app.route('/prestasi', methods=['POST'])
@auth_required
def add_prestasi():
    data = _apply_aliases(get_json(), PRESTASI_ALIASES)
    if not data.get('nama_prestasi'):
        raise ApiError('Nama prestasi wajib diisi')
    p = Prestasi(user_id=request.user.id)
    _apply_prestasi(p, data)
    db.session.add(p)
    db.session.commit()
    return jsonify(prs_dict(p)), 201


@app.route('/prestasi/<int:pid>', methods=['PATCH', 'DELETE'])
@auth_required
def update_delete_prestasi(pid):
    p = Prestasi.query.filter_by(id=pid, user_id=request.user.id).first()
    if not p:
        raise ApiError('Tidak ditemukan', 404)
    if request.method == 'DELETE':
        db.session.delete(p)
        db.session.commit()
        return jsonify({'message': 'Deleted'})
    _apply_prestasi(p, _apply_aliases(get_json(), PRESTASI_ALIASES))
    db.session.commit()
    return jsonify(prs_dict(p))


# ── Ujian Organ ───────────────────────────────────────────────────────────────

def organ_exam_dict(e):
    return {
        'id': e.id,
        'user_id': e.user_id,
        'nama_ujian': e.nama_ujian,
        'organ': e.organ,
        'penguji': e.penguji,
        'tanggal': e.tanggal.isoformat() if e.tanggal else None,
        'hasil': e.hasil,
        'nilai': e.nilai,
        'catatan': e.catatan,
        'created_at': e.created_at.isoformat() if e.created_at else None,
    }


ORGAN_EXAM_RESULTS = ('terjadwal', 'lulus', 'tidak_lulus')


def _choice(value, field, choices):
    if value not in choices:
        raise ApiError(f"{field} harus salah satu dari: {', '.join(choices)}")
    return value


ORGAN_EXAM_FIELDS = {
    'nama_ujian': _required_text(200),
    'organ': txt(200),
    'penguji': txt(200),
    'hasil': lambda v, f: _choice(v, f, ORGAN_EXAM_RESULTS),
    'nilai': parse_float,
    'catatan': txt(5000),
    'tanggal': parse_dt,
}


@app.route('/organ-exams', methods=['GET'])
@auth_required
def get_organ_exams():
    items = OrganExam.query.filter_by(user_id=request.user.id).order_by(OrganExam.created_at.desc()).all()
    return jsonify([organ_exam_dict(e) for e in items])


@app.route('/admin/organ-exams', methods=['GET'])
@admin_required
def admin_list_organ_exams():
    user_id = parse_int(request.args.get('user_id'), 'user_id', minimum=1, allow_none=False)
    get_or_404(User, user_id, 'User tidak ditemukan')
    items = OrganExam.query.filter_by(user_id=user_id).order_by(OrganExam.created_at.asc()).all()
    return jsonify([organ_exam_dict(e) for e in items])


@app.route('/admin/organ-exams', methods=['POST'])
@admin_required
def admin_add_organ_exam():
    data = get_json()
    e = OrganExam(
        user_id=_target_user_id(data),
        nama_ujian=_required_text(200)(data.get('nama_ujian'), 'nama_ujian'),
        organ=clean_text(data.get('organ'), 'organ', 200),
        penguji=clean_text(data.get('penguji'), 'penguji', 200),
        tanggal=parse_dt(data.get('tanggal'), 'tanggal'),
        hasil=_choice(data.get('hasil') or 'terjadwal', 'hasil', ORGAN_EXAM_RESULTS),
        nilai=parse_float(data.get('nilai'), 'nilai'),
        catatan=clean_text(data.get('catatan'), 'catatan', 5000),
    )
    db.session.add(e)
    db.session.commit()
    return jsonify(organ_exam_dict(e)), 201


@app.route('/admin/organ-exams/<int:eid>', methods=['PATCH'])
@admin_required
def admin_update_organ_exam(eid):
    e = get_or_404(OrganExam, eid)
    apply_fields(e, get_json(), ORGAN_EXAM_FIELDS)
    db.session.commit()
    return jsonify(organ_exam_dict(e))


# ── Survey ────────────────────────────────────────────────────────────────────

def _survey_link(value, field):
    value = clean_url(value, field)
    if not value:
        raise ApiError('link_survey wajib diisi')
    return value


SURVEY_FIELDS = {
    'judul': _required_text(300),
    'link_survey': _survey_link,
    'semester_target': _semester,
    'is_active': parse_bool,
}


@app.route('/surveys/active', methods=['GET'])
@auth_required
def get_active_surveys():
    sem = request.user.current_semester
    surveys = Survey.query.filter(
        Survey.is_active == True,  # noqa: E712
        db.or_(Survey.semester_target == sem, Survey.semester_target == None)  # noqa: E711
    ).all()
    return jsonify([{
        'id': s.id,
        'judul': s.judul,
        'link_survey': s.link_survey,
        'semester_target': s.semester_target,
    } for s in surveys])


@app.route('/admin/surveys', methods=['POST'])
@admin_required
def admin_create_survey():
    data = get_json()
    s = Survey(
        judul=_required_text(300)(data.get('judul'), 'judul'),
        link_survey=_survey_link(data.get('link_survey'), 'link_survey'),
        semester_target=_semester(data.get('semester_target'), 'semester_target'),
        is_active=parse_bool(data.get('is_active', True), 'is_active'),
    )
    db.session.add(s)
    db.session.commit()
    return jsonify({'id': s.id, 'judul': s.judul, 'link_survey': s.link_survey}), 201


@app.route('/admin/surveys', methods=['GET'])
@admin_required
def admin_list_surveys():
    surveys = Survey.query.order_by(Survey.created_at.desc()).all()
    return jsonify([{'id': s.id, 'judul': s.judul, 'link_survey': s.link_survey,
                     'semester_target': s.semester_target, 'is_active': s.is_active} for s in surveys])


@app.route('/admin/surveys/<int:sid>', methods=['PATCH'])
@admin_required
def admin_update_survey(sid):
    s = get_or_404(Survey, sid)
    apply_fields(s, get_json(), SURVEY_FIELDS)
    db.session.commit()
    return jsonify({'id': s.id, 'judul': s.judul, 'is_active': s.is_active})


# ── Admin Notifications ───────────────────────────────────────────────────────

@app.route('/admin/notifications', methods=['GET'])
@admin_required
def get_admin_notifications():
    unread_only = request.args.get('unread', 'false').lower() == 'true'
    query = AdminNotification.query
    if unread_only:
        query = query.filter_by(is_read=False)
    items = query.order_by(AdminNotification.created_at.desc()).limit(50).all()
    return jsonify([{
        'id': n.id,
        'title': n.title,
        'message': n.message,
        'type': n.type,
        'ref_id': n.ref_id,
        'ref_type': n.ref_type,
        'is_read': n.is_read,
        'created_at': n.created_at.isoformat() if n.created_at else None,
    } for n in items])


@app.route('/admin/notifications/<int:nid>/read', methods=['PATCH'])
@admin_required
def mark_notification_read(nid):
    n = get_or_404(AdminNotification, nid)
    n.is_read = True
    db.session.commit()
    return jsonify({'status': 'ok'})


@app.route('/admin/notifications/read-all', methods=['PATCH'])
@admin_required
def mark_all_notifications_read():
    AdminNotification.query.filter_by(is_read=False).update({'is_read': True})
    db.session.commit()
    return jsonify({'status': 'ok'})


# ── Profile Update (PPDS Lengkap) ─────────────────────────────────────────────

@app.route('/profile/update', methods=['PATCH'])
@auth_required
def update_profile():
    user = request.user
    # Dosen wali & pembimbing ditetapkan admin (lihat /admin/users/<id>/profile).
    apply_fields(user, get_json(), {k: ADMIN_PROFILE_FIELDS[k] for k in ('full_name', 'nim', 'angkatan')})
    db.session.commit()
    return jsonify(user_dict(user))


@app.route('/admin/users/<int:uid>/warning', methods=['PATCH'])
@admin_required
def admin_set_warning(uid):
    user = get_or_404(User, uid, 'User tidak ditemukan')
    apply_fields(user, get_json(), {k: ADMIN_PROFILE_FIELDS[k] for k in ('warning_active', 'warning_message')})
    db.session.commit()
    return jsonify(user_dict(user))


@app.route('/admin/users/<int:uid>/profile', methods=['PATCH'])
@admin_required
def admin_update_user_profile(uid):
    user = get_or_404(User, uid, 'User tidak ditemukan')
    apply_fields(user, get_json(), ADMIN_PROFILE_FIELDS)
    db.session.commit()
    return jsonify(user_dict(user))


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
