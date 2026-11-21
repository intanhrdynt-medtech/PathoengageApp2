Backend setup (dev)

1. Create a virtualenv and install dependencies:

```bash
python -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
```

2. (Optional) set environment variables in a `.env` file in this folder:

   | Variable | Keterangan |
   |---|---|
   | `DATABASE_URL` | Default: SQLite lokal `backend_data.db`. |
   | `SECRET_KEY` | Opsional. Bila diset (>= 32 karakter acak) dipakai untuk menandatangani token login. Bila kosong, backend membuat secret acak sekali dan menyimpannya di tabel `app_config`. |
   | `SEED_SECRET` | Opsional. Hanya diperlukan untuk endpoint pemeliharaan `/admin/migrate`, `/admin/seed-admin`, `/admin/seed-textbooks` (>= 16 karakter). Tanpa ini endpoint tersebut nonaktif (404). |

   Catatan keamanan:
   - Status final (kompetensi/tugas `completed`, ujian `lulus`, penelitian `approved`, dst.) hanya bisa diberikan admin/penilai; PPDS hanya bisa mengajukan (`pending_verification` / `submitted`).
   - Login dibatasi per 15 menit: 10 percobaan per (email + IP), 100 per IP, 50 per email (IP yang pernah login sukses ke akun itu dalam 30 hari tetap boleh mencoba). Registrasi: 50 per IP. IPv6 dikelompokkan per /64. Header `X-Real-Ip`/`X-Forwarded-For` hanya dipercaya di Vercel (atau bila `TRUST_PROXY_HEADERS=1`).
   - Token login otomatis tidak berlaku lagi saat password user diganti.
   - Tabel baru yang dibuat lewat SQLAlchemy di Postgres otomatis diaktifkan Row Level Security-nya.

3. Initialize the database and create a sample user:

```bash
python init_db.py
```

4. Run the app:

```bash
python app.py
```

Endpoints:
- `POST /register` {email,password}
- `POST /login` {email,password}
- `GET /me` (Authorization: Bearer <token>)
- `GET/POST /reminders` (Authorization)
- `PUT/DELETE /reminders/<id>` (Authorization)
- `PUT /me/phase` {phase: MKDU|red|yellow|green} (Authorization)
