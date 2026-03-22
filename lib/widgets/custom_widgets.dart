import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'dart:math';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final bool enabled;
  
  final String? label;
  final IconData? icon;
  final bool? isPassword;

  const CustomTextField({
    Key? key,
    required this.controller,
    this.hintText = '',
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.label,
    this.icon,
    this.isPassword,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String effectiveHintText = hintText;
    final IconData? effectivePrefixIcon = icon ?? prefixIcon;
    final bool effectiveObscureText = isPassword ?? obscureText;
    
    return TextFormField(
      controller: controller,
      obscureText: effectiveObscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: effectiveHintText,
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        prefixIcon: effectivePrefixIcon != null
            ? Icon(effectivePrefixIcon, color: Theme.of(context).colorScheme.onSurfaceVariant)
            : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade400),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final bool isLoading;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isOutlined = false,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isOutlined ? Colors.transparent : Colors.green.shade400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side:
                isOutlined
                    ? BorderSide(color: Colors.green.shade400)
                    : BorderSide.none,
          ),
        ),
        child:
            isLoading
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }
}

class AuthScreenWrapper extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthScreenWrapper({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 30),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class CustomLoading extends StatelessWidget {
  final double size;
  final Color color;

  const CustomLoading({
    Key? key,
    this.size = 40.0,
    this.color = Colors.green,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LoadingAnimationWidget.stretchedDots(
        color: color,
        size: size,
      ),
    );
  }
}

// Dashboard Loading Skeleton
class DashboardLoadingSkeleton extends StatelessWidget {
  const DashboardLoadingSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE0E0E0);
    final highlightColor = isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final textColor = scheme.onSurface;
    final subTextColor = scheme.onSurfaceVariant;

    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: baseColor,
        highlightColor: highlightColor,
      ),
      child: Column(
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: baseColor,
                      radius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome back, User!',
                  style: TextStyle(
                    fontSize: 16,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: List.generate(3, (index) => 
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: _buildStatCard(cardColor, textColor, subTextColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Tasks section
                  Text(
                    'Recent Tasks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(3, (index) => _buildTaskItem(cardColor, textColor, subTextColor)),
                  
                  const SizedBox(height: 24),
                  
                  // Calendar section
                  Text(
                    'Upcoming Events',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCalendarWidget(cardColor, textColor, subTextColor),
                  
                  const SizedBox(height: 24),
                  
                  // Activity section
                  Text(
                    'Team Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(2, (index) => _buildActivityItem(cardColor, textColor, subTextColor, baseColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '12',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tasks',
            style: TextStyle(
              fontSize: 12,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaskItem(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.task_alt, color: Colors.green),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Title Goes Here',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Due tomorrow',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'In Progress',
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCalendarWidget(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'July 2023',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.arrow_back_ios, size: 14, color: subTextColor),
                  const SizedBox(width: 16),
                  Icon(Icons.arrow_forward_ios, size: 14, color: subTextColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              return Column(
                children: [
                  Text(
                    'M',
                    style: TextStyle(
                      fontSize: 12,
                      color: subTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.transparent,
                    child: Text(
                      '12',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Team Meeting',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '10:00 AM',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityItem(Color cardColor, Color textColor, Color subTextColor, Color avatarColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: avatarColor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Name',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completed a task: Task Name',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '2h ago',
            style: TextStyle(
              fontSize: 10,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Workspace Loading Skeleton
class WorkspaceLoadingSkeleton extends StatelessWidget {
  const WorkspaceLoadingSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE0E0E0);
    final highlightColor = isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final headerBgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0);
    final textColor = scheme.onSurface;
    final subTextColor = scheme.onSurfaceVariant;

    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: baseColor,
        highlightColor: highlightColor,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Workspace',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'New',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: headerBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: subTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'Search',
                        style: TextStyle(
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTab('All', true, cardColor, subTextColor),
                _buildTab('Tasks', false, cardColor, subTextColor),
                _buildTab('Tickets', false, cardColor, subTextColor),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Content
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (context, index) {
                return _buildWorkspaceItem(cardColor, textColor, subTextColor, baseColor);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTab(String title, bool isSelected, Color cardColor, Color subTextColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withOpacity(0.2) : cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.green : subTextColor,
          ),
        ),
      ),
    );
  }
  
  Widget _buildWorkspaceItem(Color cardColor, Color textColor, Color subTextColor, Color avatarColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Task',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'In Progress',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Task Title Goes Here With a Longer Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: avatarColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Assigned to: User Name',
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                ),
              ),
              const Spacer(),
              Icon(Icons.calendar_today, size: 12, color: subTextColor),
              const SizedBox(width: 4),
              Text(
                'Due: Jul 15',
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Calendar Loading Skeleton
class CalendarLoadingSkeleton extends StatelessWidget {
  const CalendarLoadingSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE0E0E0);
    final highlightColor = isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final navBtnColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE);
    final textColor = scheme.onSurface;
    final subTextColor = scheme.onSurfaceVariant;

    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: baseColor,
        highlightColor: highlightColor,
      ),
      child: Column(
        children: [
          // Calendar header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'July 2023',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: navBtnColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.arrow_back, size: 16, color: textColor),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: navBtnColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.arrow_forward, size: 16, color: textColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Weekday headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('M', style: TextStyle(color: subTextColor)),
                    Text('T', style: TextStyle(color: subTextColor)),
                    Text('W', style: TextStyle(color: subTextColor)),
                    Text('T', style: TextStyle(color: subTextColor)),
                    Text('F', style: TextStyle(color: subTextColor)),
                    Text('S', style: TextStyle(color: subTextColor)),
                    Text('S', style: TextStyle(color: subTextColor)),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Calendar grid (4 weeks)
                for (int week = 0; week < 4; week++)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (day) {
                        // Highlight a random day to simulate selected day
                        final isSelected = week == 1 && day == 3;
                        final hasEvents = (week + day) % 3 == 0;
                        
                        return Column(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.green.withOpacity(0.2) : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${week * 7 + day + 1}',
                                style: TextStyle(
                                  color: isSelected ? Colors.green : textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (hasEvents)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
          
          // Time scale and events
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 8, // Number of time slots
              itemBuilder: (context, index) {
                final hour = 9 + index;
                final hasEvent = index % 2 == 0;
                
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time indicator
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: TextStyle(color: subTextColor),
                      ),
                    ),
                    
                    // Event container
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16, left: 8),
                        child: hasEvent ? _buildEventItem(cardColor, textColor, subTextColor) : const SizedBox(height: 40),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventItem(Color cardColor, Color textColor, Color subTextColor) {
    final eventTypes = ['Meeting', 'Task', 'Ticket'];
    final eventType = eventTypes[Random().nextInt(eventTypes.length)];
    
    Color eventColor;
    IconData eventIcon;
    
    switch (eventType) {
      case 'Meeting':
        eventColor = Colors.blue;
        eventIcon = Icons.people;
        break;
      case 'Task':
        eventColor = Colors.green;
        eventIcon = Icons.task_alt;
        break;
      default: // Ticket
        eventColor = Colors.orange;
        eventIcon = Icons.confirmation_number;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: eventColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: eventColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(eventIcon, color: eventColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$eventType Title',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Description for this $eventType',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
