import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utter_app/core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/models.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  List<StaffProfile> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      print('Load users response: $response'); // Debug log

      setState(() {
        _users = (response as List)
            .map((json) => StaffProfile.fromJson(json))
            .toList();
        _isLoading = false;
      });

      print('Loaded ${_users.length} users'); // Debug log
    } catch (e) {
      print('Error loading users: $e'); // Debug log
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddEditDialog({StaffProfile? user}) async {
    final isEdit = user != null;
    final nameController = TextEditingController(text: user?.name ?? '');
    final usernameController = TextEditingController(text: user?.username ?? '');
    final passwordController = TextEditingController();
    final phoneController = TextEditingController(text: user?.phone ?? '');
    UserRole selectedRole = user?.role ?? UserRole.CASHIER;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit User' : 'Tambah User Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    helperText: 'Bisa berupa apapun (tidak harus nomor HP)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'Password Baru (kosongkan jika tidak diubah)' : 'Password',
                    border: const OutlineInputBorder(),
                    helperText: 'Maksimal 6 karakter (angka)',
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Nomor HP (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role == UserRole.ADMIN ? 'Admin' : 'Kasir'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedRole = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final username = usernameController.text.trim();
                final password = passwordController.text.trim();
                final phone = phoneController.text.trim();

                if (name.isEmpty || username.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nama dan Username wajib diisi'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (!isEdit && password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password wajib diisi untuk user baru'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (password.isNotEmpty && password.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password harus tepat 6 karakter'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Show loading indicator
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⏳ Processing...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }

                try {
                  // Convert role to lowercase for database
                  final roleValue = selectedRole.name.toLowerCase();

                  if (isEdit) {
                    // Update existing user
                    final updateData = {
                      'name': name,
                      'username': username,
                      'phone': phone.isEmpty ? null : phone,
                      'role': roleValue,
                    };

                    // Update password if provided
                    if (password.isNotEmpty) {
                      updateData['pin'] = password;
                    }

                    final response = await Supabase.instance.client
                        .from('profiles')
                        .update(updateData)
                        .eq('id', user!.id)
                        .select();

                    print('Update response: $response'); // Debug log
                  } else {
                    // Create new user
                    final response = await Supabase.instance.client.from('profiles').insert({
                      'name': name,
                      'username': username,
                      'pin': password,
                      'phone': phone.isEmpty ? null : phone,
                      'role': roleValue,
                      'is_active': true,
                    }).select();

                    print('Insert response: $response'); // Debug log
                  }

                  await _loadUsers(); // Reload data

                  // Close dialog AFTER success
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? '✅ User berhasil diupdate' : '✅ User baru berhasil ditambahkan'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('Error in user operation: $e'); // Debug log

                  // Show error but DON'T close dialog
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlack,
              ),
              child: Text(isEdit ? 'Update' : 'Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUser(StaffProfile user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Yakin ingin menghapus user "${user.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .delete()
            .eq('id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ User berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola User'),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada user.\nTambah user baru dengan tombol + di bawah.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: user.role == UserRole.ADMIN
                              ? Colors.purple
                              : Colors.blue,
                          child: Icon(
                            user.role == UserRole.ADMIN
                                ? Icons.admin_panel_settings
                                : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          user.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Username: ${user.username}'),
                            if (user.phone != null && user.phone!.isNotEmpty)
                              Text('HP: ${user.phone}'),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: user.role == UserRole.ADMIN
                                    ? Colors.purple.withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                user.role == UserRole.ADMIN ? 'Admin' : 'Kasir',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: user.role == UserRole.ADMIN
                                      ? Colors.purple
                                      : Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showAddEditDialog(user: user),
                              color: Colors.blue,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _deleteUser(user),
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primaryBlack,
        icon: const Icon(Icons.add),
        label: const Text('Tambah User'),
      ),
    );
  }
}
