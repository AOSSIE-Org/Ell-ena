# Ell-ena


**Ell-ena** is your AI-powered teammate that makes managing work effortless. From automatically creating tickets to capturing every detail in meeting transcriptions, Ell-ena keeps the full context of your projects at its fingertips—so nothing ever falls through the cracks.  

It’s like having a smart, proactive teammate who anticipates what you need, organizes your workflow, and helps you stay on top of everything… without you even asking.

![Group 7 (1)](https://github.com/user-attachments/assets/442823c1-5ee6-4112-8dcf-0793ad9a7455)

## 🌟 Project Vision

Imagine a world where staying productive is easy and smart. Instead of juggling different apps for tasks, tickets, and meeting notes, users can simply talk to Ell-ena – and it takes care of the rest.

Ell-ena understands natural language commands and turns them into structured tasks, tickets, or notes with context-aware automation. Whether you're a developer, student, or manager, Ell-ena fits right into your workflow and grows with your needs.

## 🏗️ Technical Architecture

Ell-ena implements a sophisticated architecture that combines Flutter for cross-platform UI with Supabase for backend services, enhanced by AI-powered processing pipelines for natural language understanding and contextual intelligence.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           FRONTEND (Flutter)                            │
├───────────────┬─────────────────┬────────────────────┬─────────────────┤
│  Auth Module  │  Task Manager   │  Meeting Manager   │  Chat Interface │
└───────┬───────┴────────┬────────┴──────────┬─────────┴────────┬────────┘
        │                │                   │                  │
        ▼                ▼                   ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Supabase Service Layer                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐  │
│  │ Auth Client │   │ Data Client │   │Storage Client│  │ RPC Client  │  │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘  │
│         │                 │                 │                 │         │
└─────────┼─────────────────┼─────────────────┼─────────────────┼─────────┘
          │                 │                 │                 │
          ▼                 ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          BACKEND (Supabase)                             │
├───────────────┬─────────────────┬────────────────────┬─────────────────┤
│ Authentication│  PostgreSQL DB  │  Object Storage    │  Edge Functions │
└───────┬───────┴────────┬────────┴──────────┬─────────┴────────┬────────┘
        │                │                   │                  │
        ▼                ▼                   ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       AI Processing Pipeline                            │
├───────────────┬─────────────────┬────────────────────┬─────────────────┤
│ NLU Processor │ Vector Database │ Embedding Generator│  AI Summarizer  │
└───────────────┴─────────────────┴────────────────────┴─────────────────┘
```


## ✨ Current Implementation

https://github.com/user-attachments/assets/6542489e-1f00-4802-a8eb-abdbb86d1392

I’ve made demo videos for Ell-ena and separated them by features. So, we can directly check out the RAG & vector search implementation or the bot transcriber. please see this through the drive link. Loved building Ell-ena—would be super excited to see new ideas fixes and features coming up and getting it merged soon! 🚀

[GOOGLE DRIVE](https://drive.google.com/drive/folders/1e-hs3RkLlPo3zJ8AkaV9rVmmyt7J2mpS?usp=sharing)


## ✨ Architecture of Ell-ena

<img width="2072" height="1592" alt="NoteGPT-Sequence Diagram-1756295185752" src="https://github.com/user-attachments/assets/07ca0a2c-200e-4669-9c8a-1294dd78e789" />



## ✨ Key Features

- Generate to-do items and tickets using natural language commands
- Transcribe meetings and maintain full contextual notes
- Chat-based interface for intuitive and seamless user interactions
- Context-aware automation to enrich task details automatically
- RAG (Retrieval-Augmented Generation) implementation for contextual intelligence
- Multi-account login support with team management capabilities
- Real-time collaboration features across teams


## ✨ System Components

#### 1. Frontend Layer (Flutter)
- **Auth Module**: Handles user authentication, team management, and role-based access control
- **Task Manager**: Processes task creation, updates, and workflow management
- **Meeting Manager**: Manages meeting scheduling, transcription, and contextual analysis
- **Chat Interface**: Provides natural language interaction with the AI assistant

#### 2. Supabase Service Layer
- **Auth Client**: Manages authentication tokens and session state
- **Data Client**: Handles real-time data synchronization with PostgreSQL
- **Storage Client**: Manages file uploads and retrieval
- **RPC Client**: Executes remote procedure calls to Edge Functions

#### 3. Backend Layer (Supabase)
- **Authentication**: Handles user identity, security, and session management
- **PostgreSQL DB**: Stores structured data with Row-Level Security policies
- **Object Storage**: Manages binary assets like audio recordings and documents
- **Edge Functions**: Executes serverless functions for business logic

#### 4. AI Processing Pipeline
- **NLU Processor**: Processes natural language using Gemini API
- **Vector Database**: Stores and retrieves semantic embeddings for context-aware searches
- **Embedding Generator**: Creates vector embeddings from text for semantic similarity
- **AI Summarizer**: Generates concise summaries of meeting transcriptions

### Data Flow

1. **User Input Processing**:
   - User interacts with the Flutter UI
   - Input is processed by the appropriate manager module
   - Requests are routed through the Supabase Service Layer

2. **Backend Processing**:
   - Authentication verifies user identity and permissions
   - PostgreSQL handles data persistence with real-time updates
   - Edge Functions process complex business logic

3. **AI Enhancement**:
   - Natural language is processed through the NLU pipeline
   - Text is vectorized for semantic understanding
   - Context-aware responses are generated based on historical data
   - Meeting transcriptions are summarized and enriched with action items

4. **Response Delivery**:
   - Processed data is returned to the frontend
   - UI updates in real-time through Supabase subscriptions
   - User receives intelligent, context-aware responses


## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.7.0 or later)
- Supabase account
- Gemini API key
- Vexa API key

### Installation

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/Ell-ena.git
   cd Ell-ena
   ```

2. Set up backend (Supabase)
   - Follow instructions in [BACKEND.md](BACKEND.md)

3. Set up frontend (Flutter)
   - Follow instructions in [FRONTEND.md](FRONTEND.md)

   
## 🔧 Environment Configuration

### Frontend Environment Variables
Create a `.env` file in your Flutter project root:

```env
GEMINI_API_KEY=your_gemini_api_key_here
VEXA_API_KEY=your_vexa_api_key_here
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key

## 📁 Project Structure

### Backend Structure

```
supabase/
├── config.toml                # Supabase configuration
├── functions/                 # Edge Functions
│   ├── fetch-transcript/      # Retrieves meeting transcriptions
│   ├── generate-embeddings/   # Creates vector embeddings
│   ├── get-embedding/         # Retrieves embeddings
│   ├── search-meetings/       # Performs semantic search
│   ├── start-bot/             # Initializes AI assistant
│   └── summarize-transcription/ # Generates AI summaries
└── migrations/                # Database migrations
```

### Frontend Structure

```
lib/
├── main.dart                  # Application entry point
├── screens/                   # UI screens
│   ├── auth/                  # Authentication screens
│   ├── calendar/              # Calendar view
│   ├── chat/                  # AI assistant interface
│   ├── home/                  # Dashboard screens
│   ├── meetings/              # Meeting management
│   ├── onboarding/            # User onboarding
│   ├── profile/               # User profile
│   ├── splash_screen.dart     # Initial loading screen
│   ├── tasks/                 # Task management
│   ├── tickets/               # Ticket management
│   └── workspace/             # Team workspace
├── services/                  # Business logic
│   ├── ai_service.dart        # AI processing service
│   ├── meeting_formatter.dart # Meeting data formatter
│   ├── navigation_service.dart # Navigation management
│   └── supabase_service.dart  # Supabase integration
└── widgets/                   # Reusable UI components
    └── custom_widgets.dart    # Shared widgets
```

### SQL Structure

```
sqls/
├── 01_user_auth_schema.sql    # User authentication schema
├── 02_user_auth_policies.sql  # Row-level security policies
├── 03_task_schema.sql         # Task management schema
├── 04_tickets_schema.sql      # Ticket management schema
├── 05_meetings_schema.sql     # Meeting management schema
├── 06_meeting_transcription.sql # Transcription storage
├── 07_meetings_processed_transcriptions.sql # Processed text
├── 08_meetings_ai_summary.sql # AI-generated summaries
├── 09_meeting_vector_search.sql # Vector search capabilities
└── 10_generate_missing_embeddings.sql # Embedding generation
```

### Future Enhancements

1. Multi-language support: Expand NLU capabilities to support multiple languages.
2. Enhanced analytics: Use AI to generate predictive analytics for tasks and meetings.
3. Offline capabilities: Allow limited offline task management with later synchronization.
4. Third-party integrations: Integrate with external productivity tools like Jira, Trello, and Google Calendar.

## 🤝 Contributing

Ell-ena is an open-source project under AOSSIE for GSoC'25. We welcome contributions from the community!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read our [Contributing Guidelines](CONTRIBUTING.md) for more details.

## 📚 Documentation

- [Backend Setup](BACKEND.md): Instructions for setting up the Supabase backend
- [Frontend Setup](FRONTEND.md): Instructions for setting up the Flutter frontend


## 🎨 Figma Designs

Reference designs for the project can be found here:

- [Figma Workspace](https://www.figma.com/design/xhnMPzO8hrqXllGdEOCLZj/Ell-ena?node-id=0-1&t=9M88wLskO0K0tdnT-1)


---


**Note:** This project is part of **GSoC'25 under AOSSIE** and is actively under development.
