import requests

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
      'title': 'Cibas and Ducatman’s Cytology',
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

BASE_URL = 'https://backend-ten-puce-60.vercel.app'

# Login as admin
resp = requests.post(f"{BASE_URL}/login", json={'email': 'admin@pathoengage.com', 'password': 'admin123'})
if resp.status_code != 200:
    print("Admin login failed", resp.json())
    exit(1)

token = resp.json()['token']
headers = {'Authorization': f'Bearer {token}'}

# Get users
resp = requests.get(f"{BASE_URL}/admin/users", headers=headers)
users = resp.json()

ppds_users = [u for u in users if u['role'] == 'ppds']

count = 0
for u in ppds_users:
    # Get user tasks to avoid duplicates
    print(f"Checking user {u['id']}")
    
    for b in books:
        # Create task
        task_data = {
            'user_id': u['id'],
            'task_type': 'Textbook Reading',
            'title': b['title'],
            'description': 'Tugas membaca buku teks',
            'target_semester': u.get('current_semester', 1),
            'link_url': b['url']
        }
        res = requests.post(f"{BASE_URL}/admin/academic-tasks", headers=headers, json=task_data)
        if res.status_code in (200, 201):
            print(f"Added {b['title']} to {u['email']}")
            count += 1
        else:
            print(f"Failed {b['title']}", res.text)

print(f"Done. Inserted {count} tasks via API.")
