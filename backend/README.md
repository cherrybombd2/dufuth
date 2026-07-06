# DUFUTH SmartCare Backend

Simple FastAPI backend scaffold for the DUFUTH SmartCare system.

## Stack

- FastAPI
- Uvicorn
- Pydantic Settings
- Firebase Admin SDK

## Structure

- `app/api`: HTTP routes
- `app/core`: config and shared utilities
- `app/models`: domain models
- `app/repositories`: data access layer
- `app/schemas`: request and response models
- `app/services`: business logic
- `tests`: API tests

## Quick Start

1. Create a virtual environment
2. Install dependencies
3. Copy `.env.example` to `.env`
4. Start the server

```bash
python -m venv .venv
source .venv/Scripts/activate
pip install -e .[dev]
uvicorn app.main:app --reload
```

## Firebase Setup

1. Copy `.env.example` to `.env`
2. Put your Firebase service account JSON somewhere outside version control
3. Set `FIREBASE_PROJECT_ID`
4. Set `FIREBASE_CREDENTIALS_PATH`
5. Turn on `USE_FIRESTORE=true` when you're ready to persist to Firestore
6. Turn on `FIREBASE_AUTH_REQUIRED=true` to enforce Firebase ID token verification
7. Turn on `FCM_ENABLED=true` to send push notifications from the backend

## Current Status

This scaffold includes:

- health check endpoints
- role-ready user model
- appointment, doctor, admin, and patient route groups
- in-memory repositories for fast local development
- Firebase initialization hook for later integration
