import 'package:flutter/material.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/api_service.dart';
import 'package:fp_pemrograman/widgets/responsive_wrapper.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  @override
  _AdminUsersScreenState createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _api.getUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  void _showAddAdminDialog() {
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();
    final TextEditingController _nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Akun Admin', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
            onPressed: () async {
              if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
              Navigator.pop(ctx);
              final success = await _api.createAdminUser(
                _emailController.text.trim(), 
                _passwordController.text, 
                _nameController.text.trim(), 
                '-'
              );
              if (success) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akun Admin berhasil dibuat!')));
                _loadUsers();
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuat akun')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ResponsiveWrapper(
            child: Scaffold(
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: AppColors.accentRed,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Buat Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _showAddAdminDialog,
              ),
              body: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: user['role'] == 'admin' ? AppColors.accentRed : AppColors.primaryPurple,
                        child: Icon(
                          user['role'] == 'admin' ? Icons.security : Icons.person, 
                          color: Colors.white
                        ),
                      ),
                      title: Text(user['full_name'] ?? user['email'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${user['email']} • Role: ${user['role']}'),
                    ),
                  );
                },
              ),
            ),
          );
  }
}
