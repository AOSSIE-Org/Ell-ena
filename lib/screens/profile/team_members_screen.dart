import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/user_avatar.dart'; // Import the UserAvatar widget

class TeamMembersScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamMembersScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _teamMembers = [];

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final members = await _supabaseService.getTeamMembers(widget.teamId);
      
      if (mounted) {
        setState(() {
          _teamMembers = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading team members: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading team members: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text('${widget.teamName} Members'),
        backgroundColor: Colors.green.shade800,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _teamMembers.isEmpty
              ? _buildEmptyState()
              : _buildMembersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off,
            size: 80,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'No team members found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your team doesn\'t have any members yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teamMembers.length,
      itemBuilder: (context, index) {
        final member = _teamMembers[index];
        final name = member['full_name'] ?? 'Unknown';
        final email = member['email'] ?? '';
        final role = member['role'] ?? 'member';
        final avatarUrl = member['avatar_url'];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFF2D2D2D),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: UserAvatar(
              avatarUrl: avatarUrl,
              fullName: name,
              size: 48,
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: role == 'admin' 
                        ? Colors.orange.shade400.withOpacity(0.2) 
                        : Colors.blue.shade400.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role == 'admin' ? 'Admin' : 'Member',
                    style: TextStyle(
                      color: role == 'admin' ? Colors.orange.shade400 : Colors.blue.shade400,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            trailing: role == 'admin'
                ? Icon(
                    Icons.star,
                    color: Colors.orange.shade400,
                  )
                : null,
          ),
        );
      },
    );
  }
}