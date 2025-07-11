import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  final String _apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  String? _apiKey;
  bool _isInitialized = false;
  
  factory AIService() {
    return _instance;
  }
  
  AIService._internal();
  
  bool get isInitialized => _isInitialized;
  
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
    List<Map<String, dynamic>> userTasks = const [],
    List<Map<String, dynamic>> userTickets = const [],
  }) async {
    if (!_isInitialized) {
      await initialize();
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
                "description": "The due date of the task in ISO format (YYYY-MM-DD)"
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
                "enum": ["Bug", "Feature Request", "UI/UX", "Performance", "Documentation", "Security", "Other"],
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
                "description": "The date and time of the meeting in ISO format (YYYY-MM-DDTHH:MM:SS)"
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
                "description": "Filter tasks assigned to a specific team member (by name or ID)"
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
                "description": "Filter tickets assigned to a specific team member (by name or ID)"
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
                "description": "The new due date for a task (if changing) in ISO format (YYYY-MM-DD)"
              },
              "priority": {
                "type": "string",
                "enum": ["low", "medium", "high", "critical"],
                "description": "The new priority level for a ticket (if changing)"
              },
              "meeting_date": {
                "type": "string",
                "description": "The new date and time for a meeting (if changing) in ISO format (YYYY-MM-DDTHH:MM:SS)"
              },
              "assigned_to": {
                "type": "string",
                "description": "The user ID to reassign the item to (if changing)"
              }
            },
            "required": ["item_type", "item_id"]
          }
        }
      ];

      // Create the contents array with chat history
      final List<Map<String, dynamic>> contents = [];
      
      // Create team member context for the model
      String teamMemberContext = "Available team members:\n";
      for (var member in teamMembers) {
        teamMemberContext += "- ${member['full_name']} (${member['role']}): ${member['id']}\n";
      }
      
      // Create task context if available
      String taskContext = "";
      if (userTasks.isNotEmpty) {
        taskContext = "\nCurrent user's tasks:\n";
        for (var task in userTasks) {
          String dueDate = task['due_date'] != null 
              ? DateFormat('yyyy-MM-dd').format(DateTime.parse(task['due_date']))
              : "No due date";
          
          String status = task['status'] ?? 'todo';
          taskContext += "- ${task['title']} (Status: $status, Due: $dueDate, ID: ${task['id']})\n";
        }
      }
      
      // Create ticket context if available
      String ticketContext = "";
      if (userTickets.isNotEmpty) {
        ticketContext = "\nCurrent user's tickets:\n";
        for (var ticket in userTickets) {
          String priority = ticket['priority'] ?? 'medium';
          String status = ticket['status'] ?? 'open';
          ticketContext += "- ${ticket['title']} (Status: $status, Priority: $priority, ID: ${ticket['id']})\n";
        }
      }
      
      // Add system message as the first message with role "model"
      contents.add({
        "role": "model",
        "parts": [
          {
            "text": "You are a helpful assistant for a team collaboration app called Ell-ena. You can help users create and manage tasks, tickets, and schedule meetings. When appropriate, call the relevant function to help users.\n\n" +
                    "Current date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}\n\n" +
                    "$teamMemberContext\n" +
                    "$taskContext" +
                    "$ticketContext\n" +
                    "Guidelines for tasks, tickets, and meetings:\n" +
                    "1. Create descriptive, clear titles that summarize the purpose - be specific and professional (e.g., 'Bug Fixes Discussion' instead of just 'Meeting')\n" +
                    "2. Always provide detailed descriptions with all relevant information, even if the user doesn't explicitly provide it\n" +
                    "3. When users mention dates like 'tomorrow', 'next week', etc., convert them to proper ISO format (YYYY-MM-DD for tasks, YYYY-MM-DDTHH:MM:SS for meetings)\n" +
                    "4. For tickets, choose the appropriate priority and category based on the request context\n" +
                    "5. If the user doesn't specify who to assign the task/ticket to, leave it unassigned\n" +
                    "6. If the user mentions a team member by name, assign it to that person - be attentive to names mentioned in the request\n" +
                    "7. When users ask about tasks assigned to specific team members (e.g., 'tasks assigned to Aarav'), use query_tasks with assigned_to_team_member parameter\n" +
                    "8. When users ask about their own tasks, use query_tasks with assigned_to_me=true\n" +
                    "9. When users ask to modify existing items, use the modify_item function\n" +
                    "10. Be proactive in suggesting appropriate actions based on user requests\n" +
                    "11. For meetings, always set appropriate titles and descriptions based on the context, even if minimal information is provided\n" +
                    "12. Be very attentive to team member names in requests to ensure proper assignment and querying"
          }
        ]
      });
      
      // Add chat history
      for (var message in chatHistory) {
        String role = message["role"] ?? "user";
        // Ensure role is either "user" or "model", not "system"
        if (role != "user" && role != "model") {
          role = "user";
        }
        
        contents.add({
          "role": role,
          "parts": [
            {
              "text": message["content"] ?? ""
            }
          ]
        });
      }
      
      // Add the current user message
      contents.add({
        "role": "user",
        "parts": [
          {
            "text": userMessage
          }
        ]
      });
      
      // Create the request body
      final Map<String, dynamic> requestBody = {
        "contents": contents,
        "tools": [
          {
            "functionDeclarations": functionDeclarations
          }
        ],
        "toolConfig": {
          "functionCallingConfig": {
            "mode": "AUTO"
          }
        },
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 1024
        }
      };
      
      // Log the request for debugging
      debugPrint('Sending chat request to Gemini API: ${jsonEncode(requestBody)}');
      
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
        debugPrint('Error from Gemini API: ${response.statusCode} ${response.body}');
        return {
          'type': 'error',
          'content': 'Sorry, I encountered an error while processing your request.',
        };
      }
    } catch (e) {
      debugPrint('Error generating chat response: $e');
      return {
        'type': 'error',
        'content': 'Sorry, I encountered an error while processing your request.',
      };
    }
  }
  
  // Function to handle tool responses
  Future<String> handleToolResponse({
    required String functionName,
    required Map<String, dynamic> arguments,
    required String rawResponse,
    required Map<String, dynamic> result,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // Parse the raw response to extract the model's message
      final parsedRawResponse = jsonDecode(rawResponse);
      final modelContent = parsedRawResponse['candidates'][0]['content'];
      
      // Create the contents array for the follow-up request
      final List<Map<String, dynamic>> contents = [];
      
      // Add a system message first to provide context
      contents.add({
        "role": "model",
        "parts": [
          {
            "text": "You are a helpful assistant for a team collaboration app. You help users manage tasks, tickets, and meetings."
          }
        ]
      });
      
      // Add a user message to establish context
      contents.add({
        "role": "user",
        "parts": [
          {
            "text": "I'd like to ${functionName.replaceAll('_', ' ')}"
          }
        ]
      });
      
      // Add the original model response with the function call
      contents.add({
        "role": "model",
        "parts": [
          {
            "functionCall": {
              "name": functionName,
              "args": arguments
            }
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
              "response": {
                "content": result
              }
            }
          }
        ]
      });
      
      // Create the request body
      final Map<String, dynamic> requestBody = {
        "contents": contents,
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 512
        }
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
          return candidates[0]['content']['parts'][0]['text'] ?? 'Function executed successfully.';
        }
        return 'Function executed successfully.';
      } else {
        debugPrint('Error from Gemini API: ${response.statusCode} ${response.body}');
        return 'Function executed successfully.';
      }
    } catch (e) {
      debugPrint('Error handling tool response: $e');
      return 'Function executed successfully.';
    }
  }
} 