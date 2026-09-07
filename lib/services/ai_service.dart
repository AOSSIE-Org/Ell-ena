import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:ell_ena/models/rag_result.dart';
import 'package:ell_ena/services/ai_context_builder.dart';
import 'package:ell_ena/services/ai_prompt_builder.dart';
import 'package:ell_ena/services/rag_retriever.dart';
import 'package:ell_ena/services/supabase_service.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  final String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  String? _apiKey;
  bool _isInitialized = false;
  late final SupabaseService _supabaseService;

  factory AIService() {
    return _instance;
  }

  AIService._internal() {
    _supabaseService = SupabaseService();
  }

  bool get isInitialized => _isInitialized;

  /// Invoker-rights Supabase RPC (respects RLS). Used by [RagRetriever].
  Future<dynamic> invokeRpc(
    String functionName, {
    Map<String, dynamic>? params,
  }) {
    return _supabaseService.client.rpc(functionName, params: params);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load API key from .env file
      await dotenv.load().catchError((e) {
        debugPrint('Error loading .env file: $e');
      });

      _apiKey = dotenv.env['GEMINI_API_KEY'];

      if (_apiKey == null || _apiKey!.isEmpty) {
        throw Exception('Missing Gemini API key. Please check your .env file.');
      }

      // Initialize Supabase service if not already initialized
      if (!_supabaseService.isInitialized) {
        await _supabaseService.initialize();
      }

      _isInitialized = true;
      debugPrint('AI Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing AI Service: $e');
      rethrow;
    }
  }

  // Function to generate a chat response
  Future<Map<String, dynamic>> generateChatResponse(
    String userMessage,
    List<Map<String, String>> chatHistory,
    List<Map<String, dynamic>> teamMembers, {
    String? ragContext,
    bool retrieveContext = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    var resolvedRagContext = ragContext ?? '';
    if (retrieveContext) {
      final outcome = await retrieveSemanticContext(userMessage);
      resolvedRagContext = AiContextBuilder.buildWorkspaceContext(outcome);
    }

    try {
      // Define function declarations for the model
      final List<Map<String, dynamic>> functionDeclarations = [
        {
          "name": "create_task",
          "description": "Create a new task in the system",
          "parameters": {
            "type": "object",
            "properties": {
              "title": {
                "type": "string",
                "description": "The title of the task"
              },
              "description": {
                "type": "string",
                "description": "The description of the task"
              },
              "due_date": {
                "type": "string",
                "description":
                    "The due date of the task in ISO format (YYYY-MM-DD)"
              },
              "assigned_to": {
                "type": "string",
                "description": "The user ID to assign the task to"
              }
            },
            "required": ["title"]
          }
        },
        {
          "name": "create_ticket",
          "description": "Create a new support ticket in the system",
          "parameters": {
            "type": "object",
            "properties": {
              "title": {
                "type": "string",
                "description": "The title of the ticket"
              },
              "description": {
                "type": "string",
                "description": "The description of the ticket"
              },
              "priority": {
                "type": "string",
                "enum": ["low", "medium", "high", "critical"],
                "description": "The priority level of the ticket"
              },
              "category": {
                "type": "string",
                "enum": [
                  "Bug",
                  "Feature Request",
                  "UI/UX",
                  "Performance",
                  "Documentation",
                  "Security",
                  "Other"
                ],
                "description": "The category of the ticket"
              },
              "assigned_to": {
                "type": "string",
                "description": "The user ID to assign the ticket to"
              }
            },
            "required": ["title", "priority", "category"]
          }
        },
        {
          "name": "create_meeting",
          "description": "Schedule a new meeting",
          "parameters": {
            "type": "object",
            "properties": {
              "title": {
                "type": "string",
                "description": "The title of the meeting"
              },
              "description": {
                "type": "string",
                "description": "The description of the meeting"
              },
              "meeting_date": {
                "type": "string",
                "description":
                    "The date and time of the meeting in ISO format (YYYY-MM-DDTHH:MM:SS)"
              },
              "meeting_url": {
                "type": "string",
                "description": "The URL for the virtual meeting (optional)"
              }
            },
            "required": ["title", "meeting_date"]
          }
        },
        {
          "name": "query_tasks",
          "description": "Query tasks based on filters",
          "parameters": {
            "type": "object",
            "properties": {
              "status": {
                "type": "string",
                "enum": ["todo", "in_progress", "completed", "all"],
                "description": "Filter tasks by status"
              },
              "due_date": {
                "type": "string",
                "description": "Filter tasks by due date (YYYY-MM-DD)"
              },
              "assigned_to_me": {
                "type": "boolean",
                "description": "Filter tasks assigned to the current user"
              },
              "assigned_to_team_member": {
                "type": "string",
                "description":
                    "Filter tasks assigned to a specific team member (by name or ID)"
              }
            }
          }
        },
        {
          "name": "query_tickets",
          "description": "Query tickets based on filters",
          "parameters": {
            "type": "object",
            "properties": {
              "status": {
                "type": "string",
                "enum": ["open", "in_progress", "resolved", "closed", "all"],
                "description": "Filter tickets by status"
              },
              "priority": {
                "type": "string",
                "enum": ["low", "medium", "high", "critical", "all"],
                "description": "Filter tickets by priority"
              },
              "assigned_to_me": {
                "type": "boolean",
                "description": "Filter tickets assigned to the current user"
              },
              "assigned_to_team_member": {
                "type": "string",
                "description":
                    "Filter tickets assigned to a specific team member (by name or ID)"
              }
            }
          }
        },
        {
          "name": "modify_item",
          "description": "Modify an existing task, ticket, or meeting",
          "parameters": {
            "type": "object",
            "properties": {
              "item_type": {
                "type": "string",
                "enum": ["task", "ticket", "meeting"],
                "description": "The type of item to modify"
              },
              "item_id": {
                "type": "string",
                "description": "The ID of the item to modify"
              },
              "title": {
                "type": "string",
                "description": "The new title for the item (if changing)"
              },
              "description": {
                "type": "string",
                "description": "The new description for the item (if changing)"
              },
              "status": {
                "type": "string",
                "description": "The new status for the item (if changing)"
              },
              "due_date": {
                "type": "string",
                "description":
                    "The new due date for a task (if changing) in ISO format (YYYY-MM-DD)"
              },
              "priority": {
                "type": "string",
                "enum": ["low", "medium", "high", "critical"],
                "description":
                    "The new priority level for a ticket (if changing)"
              },
              "meeting_date": {
                "type": "string",
                "description":
                    "The new date and time for a meeting (if changing) in ISO format (YYYY-MM-DDTHH:MM:SS)"
              },
              "assigned_to": {
                "type": "string",
                "description":
                    "The user ID to reassign the item to (if changing)"
              }
            },
            "required": ["item_type", "item_id"]
          }
        }
      ];

      final contents = AiPromptBuilder.buildContents(
        userMessage: userMessage,
        chatHistory: chatHistory,
        teamMembers: teamMembers,
        ragContext: resolvedRagContext,
      );

      // Create the request body
      final Map<String, dynamic> requestBody = {
        "contents": contents,
        "tools": [
          {"functionDeclarations": functionDeclarations}
        ],
        "toolConfig": {
          "functionCallingConfig": {"mode": "AUTO"}
        },
        "generationConfig": {"temperature": 0.7, "maxOutputTokens": 1024}
      };

      // Log the request for debugging
      debugPrint(
          'Sending chat request to Gemini API: ${jsonEncode(requestBody)}');

      // Make the API request
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Check if the response contains a function call
        final candidates = responseData['candidates'] as List<dynamic>;
        if (candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List<dynamic>;

          for (var part in parts) {
            if (part.containsKey('functionCall')) {
              final functionCall = part['functionCall'];
              final functionName = functionCall['name'];
              final arguments = functionCall['args'];

              return {
                'type': 'function_call',
                'function_name': functionName,
                'arguments': arguments,
                'raw_response': jsonEncode(responseData),
              };
            }
          }

          // If no function call is detected, return as regular message
          return {
            'type': 'message',
            'content': candidates[0]['content']['parts'][0]['text'] ?? '',
          };
        }

        return {
          'type': 'error',
          'content': 'No response generated',
        };
      } else {
        debugPrint(
            'Error from Gemini API: ${response.statusCode} ${response.body}');
        return {
          'type': 'error',
          'content':
              'Sorry, I encountered an error while processing your request.',
        };
      }
    } catch (e) {
      debugPrint('Error generating chat response: $e');
      return {
        'type': 'error',
        'content':
            'Sorry, I encountered an error while processing your request.',
      };
    }
  }

  // Function to handle tool responses
  Future<String> handleToolResponse({
    required String functionName,
    required Map<String, dynamic> arguments,
    required String rawResponse,
    required Map<String, dynamic> result,
    String ragContext = '',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Parse the raw response for debugging purposes
      jsonDecode(rawResponse);

      // Create the contents array for the follow-up request
      final List<Map<String, dynamic>> contents = [];

      // Reuse already-retrieved RAG context + grounding (no second retrieval).
      contents.add({
        "role": "model",
        "parts": [
          {
            "text": AiPromptBuilder.buildToolFollowUpSystemText(
              ragContext: ragContext,
            ),
          }
        ]
      });

      // Add a user message to establish context
      contents.add({
        "role": "user",
        "parts": [
          {"text": "I'd like to ${functionName.replaceAll('_', ' ')}"}
        ]
      });

      // Add the original model response with the function call
      contents.add({
        "role": "model",
        "parts": [
          {
            "functionCall": {"name": functionName, "args": arguments}
          }
        ]
      });

      // Add the function response as a user turn
      contents.add({
        "role": "user",
        "parts": [
          {
            "functionResponse": {
              "name": functionName,
              "response": {"content": result}
            }
          }
        ]
      });

      // Create the request body
      final Map<String, dynamic> requestBody = {
        "contents": contents,
        "generationConfig": {"temperature": 0.7, "maxOutputTokens": 512}
      };

      // Log the request for debugging
      debugPrint('Sending request to Gemini API: ${jsonEncode(requestBody)}');

      // Make the API request
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final candidates = responseData['candidates'] as List<dynamic>;
        if (candidates.isNotEmpty) {
          return candidates[0]['content']['parts'][0]['text'] ??
              'Function executed successfully.';
        }
        return 'Function executed successfully.';
      } else {
        debugPrint(
            'Error from Gemini API: ${response.statusCode} ${response.body}');
        return 'Function executed successfully.';
      }
    } catch (e) {
      debugPrint('Error handling tool response: $e');
      return 'Function executed successfully.';
    }
  }

  // Function to get relevant meeting summaries for a query (vector search only)
  Future<List<Map<String, dynamic>>> getRelevantMeetingSummaries(
      String query) async {
    if (!_isInitialized) {
      await initialize();
    }

    print("👉 getRelevantMeetingSummaries() called with query: $query");

    try {
      // Step 1: Queue the embedding request and get the response ID
      final respIdResponse = await _supabaseService.client.rpc(
        'queue_embedding',
        params: {
          'query_text': query,
        },
      );

      final respId = respIdResponse as int;
      print("👉 Embedding queued with response ID: $respId");

      // Step 2: Fetch meetings using the resp_id
      final response = await _supabaseService.client.rpc(
        'search_meeting_summaries_by_resp_id',
        params: {
          'resp_id': respId,
          'match_count': 2,
        },
      );

      print("👉 Got search results using response ID: $respId");

      if (response is List) {
        final meetings = List<Map<String, dynamic>>.from(response);

        for (var meeting in meetings) {
          print(
              "Meeting: ${meeting['title']} - Date: ${meeting['meeting_date']}");
          if (meeting.containsKey('similarity')) {
            print("Similarity: ${meeting['similarity']}");
          }
          if (meeting.containsKey('debug_info')) {
            print("Debug info: ${meeting['debug_info']}");
          }
        }

        return meetings;
      } else {
        print("👉 No relevant meetings found or invalid response format");
        return [];
      }
    } catch (e, st) {
      debugPrint('Error getting relevant meeting summaries: $e\n$st');
      return [];
    }
  }

  /// Unified semantic retrieval via queue_embedding → search_rag_by_resp_id.
  Future<RagRetrievalOutcome> retrieveSemanticContext(String query) async {
    if (!_isInitialized) {
      await initialize();
    }
    return RagRetriever(rpc: invokeRpc).retrieve(query);
  }

  /// Unified semantic retrieval via queue_embedding → search_rag_by_resp_id.
  Future<List<Map<String, dynamic>>> getRelevantRagResults(String query) async {
    final outcome = await retrieveSemanticContext(query);
    return outcome.results.map((result) => result.toMap()).toList();
  }

  // Helper method to detect if a query is meeting-related
  // Kept for compatibility; chat context now uses getRelevantRagResults.
  // ignore: unused_element
  bool _isMeetingRelatedQuery(String query) {
    final meetingKeywords = [
      'meeting',
      'meetings',
      'call',
      'discussion',
      'talked about',
      'said in',
      'mentioned in',
      'last meeting',
      'previous meeting',
      'summary',
      'minutes',
      'transcript',
      'recording',
      'spoke about',
    ];

    final queryLower = query.toLowerCase();
    return meetingKeywords.any((keyword) => queryLower.contains(keyword));
  }
}
