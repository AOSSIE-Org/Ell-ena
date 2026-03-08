import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class MeetingInsightsScreen extends StatefulWidget {
  final String meetingId;
  final String initialTab; // 'transcript' or 'summary'

  const MeetingInsightsScreen(
      {super.key, required this.meetingId, this.initialTab = 'transcript'});

  @override
  State<MeetingInsightsScreen> createState() => _MeetingInsightsScreenState();
}

class _MeetingInsightsScreenState extends State<MeetingInsightsScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  Map<String, dynamic>?
      _meeting; // includes final_transcription and meeting_summary_json
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: widget.initialTab == 'summary' ? 1 : 0);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final details = await _supabase.getMeetingDetails(widget.meetingId);
      if (mounted) {
        setState(() {
          _meeting = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load meeting: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Meeting Insights'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Transcription'),
            Tab(text: 'AI Summary'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.download),
            onPressed: _downloadCurrentTabAsPdf,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTranscriptView(),
                _buildSummaryView(),
              ],
            ),
    );
  }

  Future<void> _downloadCurrentTabAsPdf() async {
    try {
      final idx = _tabController.index;
      final isTranscript = idx == 0;
      final doc = pw.Document();

      final title = isTranscript ? 'Meeting Transcription' : 'AI Summary';
      final meetingTitle = (_meeting?['title']?.toString() ?? 'Meeting');
      final meetingDate = _meeting?['meeting_date']?.toString() ?? '';

      if (isTranscript) {
        final segments = _meeting?['final_transcription'] as List?;
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(meetingTitle,
                          style: const pw.TextStyle(fontSize: 14)),
                      if (meetingDate.isNotEmpty)
                        pw.Text(meetingDate,
                            style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                if (segments != null && segments.isNotEmpty)
                  ...segments.map<pw.Widget>((s) {
                    final seg = Map<String, dynamic>.from(s as Map);
                    final speaker = seg['speaker']?.toString() ?? 'Speaker';
                    final text = seg['text']?.toString() ?? '';
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                                text: '$speaker: ',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                            pw.TextSpan(text: text),
                          ],
                        ),
                      ),
                    );
                  }).toList()
                else
                  pw.Text('No transcription available'),
              ];
            },
          ),
        );
      } else {
        final summary = _meeting?['meeting_summary_json'] as Map?;
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) {
              List<pw.Widget> bullets(dynamic list) {
                final l = (list as List?) ?? [];
                return l
                    .map<pw.Widget>((e) => pw.Bullet(text: e.toString()))
                    .toList();
              }

              pw.Widget actionItems(dynamic list) {
                final items = (list as List?) ?? [];
                return pw.Column(
                  children: items.map<pw.Widget>((it) {
                    final map = Map<String, dynamic>.from(it as Map);
                    return pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(map['item']?.toString() ?? '',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text(
                              'Owner: ${map['owner'] ?? '—'}   •   Deadline: ${map['deadline'] ?? 'N/A'}',
                              style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }

              return [
                pw.Header(
                  level: 0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(meetingTitle,
                          style: const pw.TextStyle(fontSize: 14)),
                      if (meetingDate.isNotEmpty)
                        pw.Text(meetingDate,
                            style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                if (summary == null || summary.isEmpty)
                  pw.Text('No AI summary available')
                else ...[
                  pw.Text('Key Discussion Points',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ...bullets(summary['key_discussion_points']),
                  pw.SizedBox(height: 8),
                  pw.Text('Important Decisions',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ...bullets(summary['important_decisions']),
                  pw.SizedBox(height: 8),
                  pw.Text('Action Items',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  actionItems(summary['action_items']),
                  pw.SizedBox(height: 8),
                  pw.Text('Meeting Highlights',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ...bullets(summary['meeting_highlights']),
                  pw.SizedBox(height: 8),
                  pw.Text('Follow-up Tasks',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  actionItems((summary['follow_up_tasks'] as List?)
                      ?.map((e) => {
                            'item': e['task'],
                            'owner': '',
                            'deadline': e['deadline']
                          })
                      .toList()),
                  pw.SizedBox(height: 8),
                  pw.Text('Overall Summary',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(summary['overall_summary']?.toString() ?? ''),
                ],
              ];
            },
          ),
        );
      }

      final bytes = await doc.save();
      String filename =
          '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (Platform.isAndroid) {
        // Try Downloads directory; if it fails, fall back to temp.
        try {
          final dir = Directory('/storage/emulated/0/Download');
          if (await dir.exists()) {
            final file = File('${dir.path}/$filename');
            await file.writeAsBytes(bytes);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Saved to ${file.path}'),
                  backgroundColor: Colors.green),
            );
            return;
          }
        } catch (_) {}
      }

      // Fallback to app temp if permission not granted or other platforms
      final tempDir = await getTemporaryDirectory();
      final fallbackFile = File('${tempDir.path}/$filename');
      await fallbackFile.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Saved to ${fallbackFile.path}'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTranscriptView() {
    final segments = _meeting?['final_transcription'];
    if (segments == null || segments is! List || segments.isEmpty) {
      return Center(
        child: Text(
          'No transcription available',
          style: TextStyle(color: Colors.grey.shade400),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: segments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final Map seg = Map<String, dynamic>.from(segments[index] as Map);
        final speaker = (seg['speaker']?.toString() ?? 'Speaker');
        final text = (seg['text']?.toString() ?? '');
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.green.shade700,
                child: Text(
                  speaker.isNotEmpty ? speaker[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      speaker,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style:
                          const TextStyle(color: Colors.white70, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryView() {
    final summary = _meeting?['meeting_summary_json'];
    if (summary == null || summary is! Map || summary.isEmpty) {
      return Center(
        child: Text(
          'No AI summary generated yet',
          style: TextStyle(color: Colors.grey.shade400),
        ),
      );
    }

    List<Widget> section(String title, List<Widget> children) => [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
          const SizedBox(height: 16),
        ];

    Widget bullets(List list) {
      if (list.isEmpty) return const SizedBox();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(list.length, (i) {
          final text = list[i]?.toString() ?? '';
          final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: textColor)),
                Expanded(child: Text(text, style: TextStyle(color: textColor))),
              ],
            ),
          );
        }),
      );
    }

    Widget actionItems(List items) {
      if (items.isEmpty) return const SizedBox();
      return Column(
        children: items.map<Widget>((it) {
          final map = Map<String, dynamic>.from(it as Map);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(map['item']?.toString() ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        'Owner: ${map['owner'] ?? '—'}   •   Deadline: ${map['deadline'] ?? 'N/A'}',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    final keyPoints = (summary['key_discussion_points'] as List?) ?? [];
    final decisions = (summary['important_decisions'] as List?) ?? [];
    final actions = (summary['action_items'] as List?) ?? [];
    final highlights = (summary['meeting_highlights'] as List?) ?? [];
    final followUps = (summary['follow_up_tasks'] as List?) ?? [];
    final overall = summary['overall_summary']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...section('Key Discussion Points', [bullets(keyPoints)]),
        ...section('Important Decisions', [bullets(decisions)]),
        ...section('Action Items', [actionItems(actions)]),
        ...section('Meeting Highlights', [bullets(highlights)]),
        ...section('Follow-up Tasks', [
          actionItems(followUps
              .map((e) =>
                  {'item': e['task'], 'owner': '', 'deadline': e['deadline']})
              .toList())
        ]),
        Text('Overall Summary',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8)),
          child: Text(overall,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
        ),
      ],
    );
  }
}
